import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'tournament_models.dart';

class TournamentDisplayController extends ChangeNotifier {
  TournamentDisplayController({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  Timer? _pollTimer;

  TournamentState? _state;
  bool _loading = true;
  String? _error;

  TournamentState? get state => _state;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> initialize() async {
    await refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
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
    _pollTimer?.cancel();
    super.dispose();
  }
}
