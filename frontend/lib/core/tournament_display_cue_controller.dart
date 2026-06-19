import 'dart:async';

import 'package:flutter/foundation.dart';

import 'display/display_audio.dart';
import 'display/tournament_announcer.dart';
import 'tournament_display_controller.dart';
import 'tournament_models.dart';

class TournamentCelebrationState {
  TournamentCelebrationState({
    required this.result,
    this.courtNumber,
  });

  final TournamentRecentResultInfo result;
  final int? courtNumber;
}

class TournamentDisplayCueController extends ChangeNotifier {
  TournamentDisplayCueController({
    required this.announcementsEnabled,
    required this.celebrationsEnabled,
    required this.voiceEnabled,
  }) {
    TournamentAnnouncer.instance.enabled = voiceEnabled;
    DisplayAudio.instance.enabled =
        announcementsEnabled || celebrationsEnabled;
  }

  bool announcementsEnabled;
  bool celebrationsEnabled;
  bool voiceEnabled;

  final TournamentDisplayController _display = TournamentDisplayController();

  TournamentState? _previousState;
  TournamentCelebrationState? celebration;
  bool audioUnlocked = false;
  bool _spokenEnableConfirmation = false;

  TournamentState? get state => _display.state;
  bool get loading => _display.loading;
  String? get error => _display.error;

  Future<void> initialize() async {
    _display.addListener(_onDisplayUpdate);
    await _display.initialize();
    _previousState = _display.state;
    notifyListeners();
  }

  Future<void> refresh() => _display.refresh();

  Future<void> unlockAudio() async {
    await DisplayAudio.instance.unlock();
    if (!_spokenEnableConfirmation &&
        TournamentAnnouncer.instance.isSupported &&
        voiceEnabled) {
      await TournamentAnnouncer.instance.speak('Tournament audio enabled.');
      _spokenEnableConfirmation = true;
    }
    audioUnlocked = true;
    notifyListeners();
  }

  void disableAudio() {
    TournamentAnnouncer.instance.cancelSpeech();
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

  void setAnnouncementsEnabled(bool value) {
    announcementsEnabled = value;
    DisplayAudio.instance.enabled =
        announcementsEnabled || celebrationsEnabled;
    notifyListeners();
  }

  void setCelebrationsEnabled(bool value) {
    celebrationsEnabled = value;
    DisplayAudio.instance.enabled =
        announcementsEnabled || celebrationsEnabled;
    notifyListeners();
  }

  void setVoiceEnabled(bool value) {
    voiceEnabled = value;
    TournamentAnnouncer.instance.enabled = value;
    notifyListeners();
  }

  void _onDisplayUpdate() {
    final current = _display.state;
    if (current != null && _previousState != null) {
      _detectCues(_previousState!, current);
    }
    _previousState = current;
    notifyListeners();
  }

  void _detectCues(TournamentState oldState, TournamentState newState) {
    final oldDisplay = oldState.display;
    final newDisplay = newState.display;
    if (oldDisplay == null || newDisplay == null) return;

    final oldCourts = {
      for (final court in oldDisplay.courts) court.courtNumber: court,
    };

    for (final newCourt in newDisplay.courts) {
      final oldCourt = oldCourts[newCourt.courtNumber];
      if (oldCourt != null &&
          !oldCourt.isActive &&
          newCourt.isActive &&
          newCourt.match != null) {
        if (audioUnlocked) {
          if (announcementsEnabled) {
            unawaited(DisplayAudio.instance.playCourtReady());
          }
          if (voiceEnabled) {
            TournamentAnnouncer.instance.announceCourtAssignment(newCourt);
          }
        }
      }
    }

    final oldResultIds = {
      for (final result in oldDisplay.recentResults) result.id,
    };
    for (final result in newDisplay.recentResults) {
      if (oldResultIds.contains(result.id)) continue;
      final courtNumber = _courtNumberForResult(newDisplay, result);
      celebration = TournamentCelebrationState(
        result: result,
        courtNumber: courtNumber,
      );
      if (audioUnlocked) {
        unawaited(_playResultSequence(result, courtNumber, newDisplay));
      }
      notifyListeners();
      final resultId = result.id;
      Future.delayed(const Duration(seconds: 6), () {
        if (celebration?.result.id == resultId) {
          celebration = null;
          notifyListeners();
        }
      });
      break;
    }

    final oldUpNextId =
        oldDisplay.upNext.isNotEmpty ? oldDisplay.upNext.first.id : null;
    final newUpNext =
        newDisplay.upNext.isNotEmpty ? newDisplay.upNext.first : null;
    if (newUpNext != null &&
        newUpNext.id != oldUpNextId &&
        audioUnlocked &&
        announcementsEnabled) {
      unawaited(DisplayAudio.instance.playNextUp());
    }
    if (newUpNext != null &&
        newUpNext.id != oldUpNextId &&
        audioUnlocked &&
        voiceEnabled) {
      unawaited(
        TournamentAnnouncer.instance.announceUpNext(newUpNext),
      );
    }
  }

  int? _courtNumberForResult(
    TournamentDisplayState display,
    TournamentRecentResultInfo result,
  ) {
    for (final court in display.courts) {
      final match = court.match;
      if (match != null &&
          match.teamA == result.teamA &&
          match.teamB == result.teamB) {
        return court.courtNumber;
      }
    }
    return null;
  }

  Future<void> _playResultSequence(
    TournamentRecentResultInfo result,
    int? courtNumber,
    TournamentDisplayState display,
  ) async {
    if (celebrationsEnabled) {
      await DisplayAudio.instance.playCelebration();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (voiceEnabled) {
      await TournamentAnnouncer.instance.announceMatchResult(
        result,
        courtNumber: courtNumber,
      );
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (display.upNext.isNotEmpty) {
        await TournamentAnnouncer.instance.announceUpNext(
          display.upNext.first,
          prefix: 'Next up',
        );
      }
    }
  }

  void dismissCelebration() {
    celebration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _display.removeListener(_onDisplayUpdate);
    _display.dispose();
    TournamentAnnouncer.instance.dispose();
    super.dispose();
  }
}
