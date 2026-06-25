import 'dart:async';

import 'package:flutter/foundation.dart';

import 'admin_pin_controller.dart';
import 'adaptive_poll_timer.dart';
import 'api_client.dart';
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
  int _adminFullRefreshPolls = 0;

  bool get hasActiveSession => state?.session.isActive ?? false;

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

  Future<void> initialize({bool readOnly = false}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      state = await api.getActiveSession();
      _startLiveUpdates(readOnly: readOnly);
    } on ApiException catch (e) {
      if (e.statusCode != 404) {
        error = e.message;
      }
      state = null;
    } catch (e) {
      error = e.toString();
      state = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _startLiveUpdates({required bool readOnly}) {
    _pollTimer?.stop();
    if (state == null) return;

    _readOnlyPolling = readOnly;
    _adminFullRefreshPolls = 0;
    final sessionId = state!.session.id;

    _pollTimer = AdaptivePollTimer(
      foregroundInterval: const Duration(seconds: 8),
      backgroundInterval: const Duration(seconds: 20),
      liveInterval: const Duration(seconds: 30),
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
    final previous = state;
    if (previous == null) return;

    if (!_readOnlyPolling) {
      _adminFullRefreshPolls++;
    }

    final live = await api.getSessionStateLive(sessionId);

    if (!_readOnlyPolling) {
      final needsFullRefresh =
          live.completedMatchCount != previous.completedMatchCount ||
              _adminFullRefreshPolls % 6 == 0;
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
    _syncAdminPinFromGlobal();
    error = null;
    try {
      state = await action();
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
