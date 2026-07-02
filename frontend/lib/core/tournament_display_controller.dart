import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adaptive_poll_timer.dart';
import 'api_client.dart';
import 'config.dart';
import 'tournament_models.dart';

class TournamentDisplayController extends ChangeNotifier {
  TournamentDisplayController({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  AdaptivePollTimer? _pollTimer;

  TournamentState? _state;
  bool _loading = true;
  String? _error;

  TournamentState? get state => _state;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    await refresh();
    _pollTimer = AdaptivePollTimer(
      foregroundInterval: AppConfig.pollForegroundInterval,
      backgroundInterval: AppConfig.pollBackgroundInterval,
      onPoll: refresh,
    )..start();
  }

  Future<void> refresh() async {
    try {
      final next = await _api.getActiveTournament();
      _state = next;
      _error = next == null ? 'No live tournament' : null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.stop();
    super.dispose();
  }
}
