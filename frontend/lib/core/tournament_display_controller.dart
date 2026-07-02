import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adaptive_poll_timer.dart';
import 'api_client.dart';
import 'config.dart';
import 'rpc_session_controller.dart';
import 'tournament_models.dart';

class TournamentDisplayController extends ChangeNotifier {
  TournamentDisplayController({ApiClient? api})
      : _api = api ?? rpcApiClient;

  final ApiClient _api;
  AdaptivePollTimer? _pollTimer;

  TournamentState? _state;
  bool _loading = true;
  String? _error;
  DateTime? _lastFetchAt;
  int _retainCount = 0;

  TournamentState? get state => _state;
  bool get loading => _loading;
  String? get error => _error;

  void retain() => _retainCount++;

  void release() {
    if (_retainCount <= 0) return;
    _retainCount--;
    if (_retainCount == 0) {
      _pollTimer?.stop();
    }
  }

  Future<void> initialize({bool force = false}) async {
    final cacheFresh = !force &&
        _state != null &&
        _lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < AppConfig.screenCacheTtl;

    if (!cacheFresh) {
      _loading = _state == null;
      notifyListeners();
    }

    await refresh(force: force, silent: cacheFresh);

    if (_pollTimer != null) return;

    _pollTimer = AdaptivePollTimer(
      foregroundInterval: AppConfig.pollForegroundInterval,
      backgroundInterval: AppConfig.pollBackgroundInterval,
      onPoll: () => refresh(silent: true),
    )..start();
  }

  Future<void> refresh({bool force = false, bool silent = false}) async {
    if (!silent && _state == null) {
      _loading = true;
      notifyListeners();
    }

    try {
      final next = await _api.getActiveTournament(force: force);
      _state = next;
      _lastFetchAt = DateTime.now();
      _error = next == null ? 'No live tournament' : null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyState(TournamentState? next) {
    _state = next;
    _lastFetchAt = DateTime.now();
    _error = next == null ? 'No live tournament' : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.stop();
    super.dispose();
  }
}
