import 'dart:async';

import 'package:flutter/foundation.dart';

import 'admin_pin_controller.dart';
import 'adaptive_poll_timer.dart';
import 'api_client.dart';
import 'config.dart';
import 'models.dart';
import 'websocket_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    ApiClient? apiClient,
    LiveUpdateService? liveUpdateService,
  })  : api = apiClient ?? ApiClient(),
        liveUpdates = liveUpdateService ?? LiveUpdateService();

  final ApiClient api;
  final LiveUpdateService liveUpdates;

  SessionState? state;
  SessionReport? lastReport;
  bool loading = false;
  String? error;
  String? adminPin;

  AdaptivePollTimer? _pollTimer;
  bool _readOnlyPolling = false;
  bool _mutating = false;
  DateTime? _lastFetchAt;
  int _retainCount = 0;
  bool _noActiveSession = false;

  bool get hasActiveSession => state?.session.isActive ?? false;
  bool get mutating => _mutating;

  /// Call from a screen's [initState]; paired with [release] in [dispose].
  void retain() => _retainCount++;

  /// Call from a screen's [dispose]. Stops live polling when no screens hold
  /// a reference (e.g. user is on Calendar, which does not need polling).
  void release() {
    if (_retainCount <= 0) return;
    _retainCount--;
    if (_retainCount == 0) {
      _pollTimer?.stop();
      liveUpdates.disconnect();
    }
  }

  void setAdminPin(String pin) {
    adminPin = pin;
    api.setAdminPin(pin);
  }

  void _syncAdminPinFromGlobal() {
    final pin = rpcAdminPinController.pin;
    if (pin.isNotEmpty) {
      setAdminPin(pin);
    }
  }

  Future<void> initialize({
    bool readOnly = false,
    bool force = false,
  }) async {
    _readOnlyPolling = readOnly;

    final cacheFresh = !force &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < AppConfig.screenCacheTtl &&
        (state != null || _noActiveSession);

    if (cacheFresh) {
      _startLiveUpdates(readOnly: readOnly);
      return;
    }

    loading = state == null && !_noActiveSession;
    error = null;
    notifyListeners();

    try {
      final active = await api.getActiveSession(force: force);
      if (active == null) {
        state = null;
        _noActiveSession = true;
      } else {
        state = active;
        _noActiveSession = false;
      }
      _lastFetchAt = DateTime.now();
      _startLiveUpdates(readOnly: readOnly);
    } on ApiException catch (e) {
      error = e.message;
      state = null;
      _noActiveSession = false;
      _lastFetchAt = null;
    } catch (e) {
      error = e.toString();
      state = null;
      _noActiveSession = false;
      _lastFetchAt = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _startLiveUpdates({required bool readOnly}) {
    if (state == null) return;

    _readOnlyPolling = readOnly;
    final sessionId = state!.session.id;

    if (_pollTimer != null) {
      _pollTimer!.setLiveUpdatesActive(liveUpdates.isConnected);
      return;
    }

    _pollTimer = AdaptivePollTimer(
      foregroundInterval: AppConfig.pollForegroundInterval,
      backgroundInterval: AppConfig.pollBackgroundInterval,
      liveInterval: AppConfig.pollLiveInterval,
      onPoll: () => _pollSessionState(sessionId),
    )..start();

    _pollTimer?.setLiveUpdatesActive(liveUpdates.isConnected);

    liveUpdates.connect(
      sessionId: sessionId,
      onState: (fresh) {
        state = fresh;
        notifyListeners();
      },
      onConnectionChanged: (connected) {
        _pollTimer?.setLiveUpdatesActive(connected);
      },
    );
  }

  Future<void> _pollSessionState(int sessionId) async {
    if (_mutating) return;

    final previous = state;
    if (previous == null) return;

    final live = await api.getSessionStateLive(sessionId);

    if (_mutating) return;

    if (!_readOnlyPolling) {
      final needsFullRefresh =
          live.completedMatchCount != previous.completedMatchCount;
      if (needsFullRefresh) {
        state = await api.getSessionState(sessionId);
        notifyListeners();
        return;
      }
      state = previous.mergeLivePoll(live, retainAdminExtras: true);
    } else {
      state = live;
    }

    notifyListeners();
  }

  Future<void> startSession({
    required String name,
    required String matchMode,
    required String playFormat,
    required int courtCount,
    bool autoAssignEnabled = false,
    bool requirePayment = false,
    int sessionFeeCents = 3000,
  }) async {
    await _run(() => api.startSession(
          name: name,
          matchMode: matchMode,
          playFormat: playFormat,
          courtCount: courtCount,
          autoAssignEnabled: autoAssignEnabled,
          requirePayment: requirePayment,
          sessionFeeCents: sessionFeeCents,
        ));
    if (state != null) _startLiveUpdates(readOnly: false);
  }

  void applyState(SessionState fresh) {
    state = fresh;
    _noActiveSession = false;
    _lastFetchAt = DateTime.now();
    notifyListeners();
  }

  Future<bool> addPlayer(
    String name, {
    String? skillLevel,
    String? gender,
    String? paymentAction,
  }) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.addPlayer(
          sessionId,
          name,
          skillLevel: skillLevel,
          gender: gender,
          paymentAction: paymentAction,
        ));
  }

  Future<bool> markRegistrationPaid(int clubPlayerId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.markRegistrationPaid(sessionId, clubPlayerId),
    );
  }

  Future<bool> markRegistrationWaived(int clubPlayerId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.markRegistrationWaived(sessionId, clubPlayerId),
    );
  }

  Future<bool> removePlayer(int playerId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.removePlayer(sessionId, playerId));
  }

  Future<bool> updatePlayerName(int playerId, String name) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.updatePlayerName(sessionId, playerId, name));
  }

  Future<bool> moveQueuePlayer({
    required int playerId,
    required String queueType,
    required int position,
  }) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.moveQueuePlayer(
        sessionId,
        playerId: playerId,
        queueType: queueType,
        position: position,
      ),
    );
  }

  Future<bool> submitScore(int matchId, int scoreA, int scoreB) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.submitScore(sessionId, matchId, scoreA, scoreB));
  }

  Future<bool> manualAssign(int courtId, List<int> playerIds) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.manualAssign(sessionId, courtId, playerIds));
  }

  Future<bool> assignNextUp(int courtId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    final court = state!.courts.firstWhere((c) => c.id == courtId);
    if (court.isChallengeCourt) {
      return _mutate(() => api.assignChallengeCourtNext(sessionId, courtId));
    }
    return _mutate(() => api.assignNextUp(sessionId, courtId));
  }

  Future<bool> openChallengeCourt() async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.openChallengeCourt(sessionId));
  }

  Future<bool> closeChallengeCourt() async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.closeChallengeCourt(sessionId));
  }

  Future<bool> configureChallengeCourts(List<int> courtNumbers) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.configureChallengeCourts(sessionId, courtNumbers),
    );
  }

  Future<bool> joinChallengeCourtTeam({
    required int playerId,
    required int partnerId,
  }) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.joinChallengeCourtTeam(
        sessionId,
        playerId: playerId,
        partnerId: partnerId,
      ),
    );
  }

  Future<bool> returnChallengeCourtTeam(int teamId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.returnChallengeCourtTeam(sessionId, teamId));
  }

  Future<bool> removeChallengeCourtTeam(int teamId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(() => api.removeChallengeCourtTeam(sessionId, teamId));
  }

  Future<bool> removePlayerFromCourt(int courtId, int playerId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.removePlayerFromCourt(sessionId, courtId, playerId),
    );
  }

  Future<bool> swapCourtPlayers(int courtId, int playerAId, int playerBId) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.swapCourtPlayers(sessionId, courtId, playerAId, playerBId),
    );
  }

  Future<bool> setAutoAssignEnabled(bool enabled) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.updateSessionSettings(sessionId, autoAssignEnabled: enabled),
    );
  }

  Future<bool> updateCourtCount(int courtCount) async {
    final sessionId = state?.session.id;
    if (sessionId == null) return false;
    return _mutate(
      () => api.updateSessionSettings(sessionId, courtCount: courtCount),
    );
  }

  Future<bool> _mutate(Future<SessionState> Function() action) async {
    if (_mutating) return false;

    _mutating = true;
    _pollTimer?.pause();
    _syncAdminPinFromGlobal();
    error = null;
    notifyListeners();

    try {
      state = await action();
      _noActiveSession = false;
      _lastFetchAt = DateTime.now();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _mutating = false;
      _pollTimer?.resume();
    }
  }

  Future<SessionReport?> endSession() async {
    final sessionId = state?.session.id;
    if (sessionId == null) return null;

    _syncAdminPinFromGlobal();
    loading = true;
    error = null;
    notifyListeners();

    try {
      final result = await api.endSession(sessionId);
      state = result.state;
      _noActiveSession = result.state.session.status != 'active';
      _lastFetchAt = DateTime.now();
      lastReport = result.report;
      _pollTimer?.stop();
      liveUpdates.disconnect();
      return result.report;
    } on ApiException catch (e) {
      error = e.message;
      return null;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<SessionState> Function() action) async {
    _syncAdminPinFromGlobal();
    loading = true;
    error = null;
    notifyListeners();

    try {
      state = await action();
      _noActiveSession = false;
      _lastFetchAt = DateTime.now();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.stop();
    liveUpdates.disconnect();
    super.dispose();
  }
}
