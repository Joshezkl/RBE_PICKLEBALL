import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../session_controller.dart';
import 'display_announcer.dart';
import 'display_audio.dart';

class CelebrationState {
  CelebrationState({required this.match, this.courtNumber});

  final MatchInfo match;
  final int? courtNumber;
}

class DisplayCueController extends ChangeNotifier {
  DisplayCueController({
    required this.announceEnabled,
    required this.soundsEnabled,
  }) {
    DisplayAnnouncer.instance.enabled = announceEnabled;
    DisplayAudio.instance.enabled = soundsEnabled;
  }

  final bool announceEnabled;
  final bool soundsEnabled;

  final session = SessionController();
  SessionState? _previousState;
  final flashingCourts = <int>{};
  CelebrationState? celebration;
  bool audioUnlocked = false;
  bool _spokenEnableConfirmation = false;
  Timer? _flashTimer;
  List<LeaderboardEntry> _leaderboard = [];
  int? _leaderboardSessionId;
  int _leaderboardMatchCount = -1;

  bool get loading => session.loading;
  String? get error => session.error;
  SessionState? get state => session.state;
  List<LeaderboardEntry> get leaderboard => _leaderboard;

  bool canRepeatCourtAssignment(int courtNumber) {
    if (!audioUnlocked) return false;
    final courts = session.state?.courts;
    if (courts == null) return false;
    for (final court in courts) {
      if (court.courtNumber == courtNumber &&
          court.status == 'in_match' &&
          court.match != null) {
        return true;
      }
    }
    return false;
  }

  Future<void> repeatCourtAssignment(int courtNumber) async {
    final courts = session.state?.courts;
    if (courts == null) return;
    CourtInfo? court;
    for (final c in courts) {
      if (c.courtNumber == courtNumber) {
        court = c;
        break;
      }
    }
    if (court == null || court.match == null) return;
    await DisplayAnnouncer.instance.repeatCourtAssignment(court);
  }

  Future<void> initialize() async {
    session.addListener(_onSessionUpdate);
    await session.initialize(readOnly: true);
    _previousState = session.state;
    _maybeRefreshLeaderboard(session.state);
    notifyListeners();
  }

  Future<void> unlockAudio() async {
    await DisplayAudio.instance.unlock();
    if (!_spokenEnableConfirmation && DisplayAnnouncer.instance.isSupported) {
      await DisplayAnnouncer.instance.speak('Announcements enabled.');
      _spokenEnableConfirmation = true;
    }
    audioUnlocked = true;
    notifyListeners();
  }

  void disableAudio() {
    DisplayAnnouncer.instance.cancelSpeech();
    audioUnlocked = false;
    notifyListeners();
  }

  Future<void> setAudioEnabled(bool enabled) async {
    if (enabled) {
      await unlockAudio();
    } else {
      disableAudio();
    }
  }

  void _onSessionUpdate() {
    final current = session.state;
    if (current != null && _previousState != null) {
      _detectCues(_previousState!, current);
    }
    _previousState = current;
    _maybeRefreshLeaderboard(current);
    notifyListeners();
  }

  void _maybeRefreshLeaderboard(SessionState? current) {
    if (current == null) {
      _leaderboard = [];
      _leaderboardSessionId = null;
      _leaderboardMatchCount = -1;
      return;
    }
    final sessionId = current.session.id;
    final matchCount = current.matchHistory.length;
    if (_leaderboardSessionId == sessionId &&
        _leaderboardMatchCount == matchCount &&
        _leaderboard.isNotEmpty) {
      return;
    }
    _leaderboardMatchCount = matchCount;
    _loadLeaderboard(sessionId);
  }

  Future<void> _loadLeaderboard(int sessionId) async {
    try {
      final result = await session.api.getSessionLeaderboard(sessionId);
      if (session.state?.session.id != sessionId) return;
      _leaderboard = result.entries.take(5).toList();
      _leaderboardSessionId = sessionId;
      notifyListeners();
    } catch (_) {
      _leaderboard = [];
    }
  }

  void _detectCues(SessionState oldState, SessionState newState) {
    final oldCourts = {for (final c in oldState.courts) c.courtNumber: c};
    final newCourts = {for (final c in newState.courts) c.courtNumber: c};

    for (final entry in newCourts.entries) {
      final courtNum = entry.key;
      final newCourt = entry.value;
      final oldCourt = oldCourts[courtNum];

      if (oldCourt?.status != 'in_match' && newCourt.status == 'in_match') {
        _flashCourt(courtNum);
        if (audioUnlocked) {
          DisplayAudio.instance.playCourtReady();
          DisplayAnnouncer.instance.announceCourtAssignment(newCourt);
        }
      } else if (oldCourt?.status == 'in_match' &&
          newCourt.status == 'available' &&
          audioUnlocked) {
        DisplayAudio.instance.playNextUp();
      }
    }

    final oldReady = oldState.primaryUpNext?.ready ?? false;
    final newReady = newState.primaryUpNext?.ready ?? false;
    if (!oldReady && newReady && audioUnlocked) {
      DisplayAudio.instance.playNextUp();
    }

    final oldTopId = oldState.matchHistory.isNotEmpty
        ? oldState.matchHistory.first.id
        : null;
    final newTop = newState.matchHistory.isNotEmpty
        ? newState.matchHistory.first
        : null;
    if (newTop != null && newTop.id != oldTopId) {
      celebration = CelebrationState(
        match: newTop,
        courtNumber: newTop.courtNumber,
      );
      _leaderboardSessionId = null;
      _loadLeaderboard(newState.session.id);
      if (audioUnlocked) {
        unawaited(_playWinnerSequence(newTop, newState));
      }
      notifyListeners();
      Future.delayed(const Duration(seconds: 6), () {
        if (celebration?.match.id == newTop.id) {
          celebration = null;
          notifyListeners();
        }
      });
    }
  }

  void _flashCourt(int courtNumber) {
    flashingCourts.add(courtNumber);
    notifyListeners();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 3), () {
      flashingCourts.remove(courtNumber);
      notifyListeners();
    });
  }

  Future<void> _playWinnerSequence(MatchInfo match, SessionState state) async {
    await DisplayAudio.instance.playCelebration();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await DisplayAnnouncer.instance.announceMatchResult(
      match,
      match.courtNumber,
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await DisplayAnnouncer.instance.announceNextGame(state);
  }

  void dismissCelebration() {
    celebration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    session.removeListener(_onSessionUpdate);
    session.dispose();
    DisplayAnnouncer.instance.dispose();
    super.dispose();
  }
}
