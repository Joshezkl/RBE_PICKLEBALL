import 'dart:async';
import 'dart:html' as html;

import '../models.dart';

class DisplayAnnouncer {
  DisplayAnnouncer._();
  static final DisplayAnnouncer instance = DisplayAnnouncer._();

  bool enabled = true;
  final _queue = <String>[];
  bool _speaking = false;
  final _spokenMatchIds = <int>{};

  final Map<int, String> lastCourtAssignmentScripts = {};

  bool get isSupported => html.window.speechSynthesis != null;

  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty || !isSupported) return;
    _queue.add(text);
    await _processQueue();
  }

  Future<void> _processQueue() async {
    if (_speaking || _queue.isEmpty) return;
    _speaking = true;
    final text = _queue.removeAt(0);

    final completer = Completer<void>();
    final utterance = html.SpeechSynthesisUtterance(text)
      ..rate = 0.92
      ..pitch = 1.0
      ..volume = 1.0;

    final voices = html.window.speechSynthesis?.getVoices() ?? [];
    final english = voices.where((v) => (v.lang ?? '').startsWith('en')).toList();
    if (english.isNotEmpty) {
      utterance.voice = english.first;
    }

    utterance.onEnd.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    utterance.onError.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    html.window.speechSynthesis?.speak(utterance);
    await completer.future.timeout(
      Duration(milliseconds: (text.length * 55).clamp(2000, 30000).round()),
      onTimeout: () {},
    );
    _speaking = false;
    if (_queue.isNotEmpty) await _processQueue();
  }

  void announceCourtAssignment(CourtInfo court) {
    final match = court.match;
    if (match == null) return;
    if (_spokenMatchIds.contains(match.id)) return;
    _spokenMatchIds.add(match.id);

    final script = _assignmentScript(court);
    lastCourtAssignmentScripts[court.courtNumber] = script;
    speak(script);
  }

  Future<void> announceMatchResult(MatchInfo match, int? courtNumber) async {
    if (_spokenMatchIds.contains(-match.id)) return;
    _spokenMatchIds.add(-match.id);

    final courtLabel = courtNumber != null ? 'Court $courtNumber' : 'Court';
    final winner = match.winnerTeam == 'A'
        ? _teamLabel(match.teamA)
        : _teamLabel(match.teamB);
    final scoreA = match.scoreA ?? 0;
    final scoreB = match.scoreB ?? 0;
    await speak('$courtLabel. $winner wins! Final score, $scoreA to $scoreB.');
  }

  String? buildNextGameScript(SessionState state) {
    final upNext = state.primaryUpNext;
    if (upNext == null || upNext.players.isEmpty) return null;

    final slotsPerTeam = state.groupSize ~/ 2;
    final teamA = _queuePairLabel(upNext.players, 0, slotsPerTeam);
    final teamB = _queuePairLabel(upNext.players, slotsPerTeam, slotsPerTeam);
    if (teamA.isEmpty && teamB.isEmpty) return null;

    final parts = <String>['Next game.'];
    if (teamA.isNotEmpty) {
      parts.add('Team A, $teamA.');
    }
    if (teamB.isNotEmpty) {
      parts.add('Team B, $teamB.');
    }
    if (teamA.isNotEmpty && teamB.isNotEmpty) {
      parts.add('Get ready to play.');
    }
    return parts.join(' ');
  }

  Future<void> announceNextGame(SessionState state) async {
    final script = buildNextGameScript(state);
    if (script == null) return;
    await speak(script);
  }

  bool canRepeatCourtAssignment(int courtNumber) =>
      lastCourtAssignmentScripts.containsKey(courtNumber);

  Future<void> repeatCourtAssignment(CourtInfo court) async {
    if (court.match == null) return;
    final script = _assignmentScript(court);
    lastCourtAssignmentScripts[court.courtNumber] = script;
    await speak(script);
  }

  String _assignmentScript(CourtInfo court) {
    final m = court.match!;
    final teamA = _pairLabel(m.teamA);
    final teamB = _pairLabel(m.teamB);
    return 'Next match on Court ${court.courtNumber}: '
        'Team A, $teamA, versus Team B, $teamB.';
  }

  String _pairLabel(Map<String, MatchPlayer?> team) {
    final p1 = team['player1']?.name;
    final p2 = team['player2']?.name;
    if (p1 == null && p2 == null) return 'open slot';
    if (p2 == null || p2.isEmpty) return p1 ?? '';
    return '$p1 and $p2';
  }

  String _queuePairLabel(List<QueuePlayer> players, int start, int count) {
    final names = <String>[];
    for (var i = start; i < start + count && i < players.length; i++) {
      final name = players[i].name.trim();
      if (name.isNotEmpty) names.add(name);
    }
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names[0]} and ${names[1]}';
  }

  String _teamLabel(Map<String, MatchPlayer?> team) {
    final label = _pairLabel(team);
    return label.isEmpty ? 'Team' : label;
  }

  void cancelSpeech() {
    html.window.speechSynthesis?.cancel();
    _queue.clear();
    _speaking = false;
  }

  void dispose() {
    cancelSpeech();
    lastCourtAssignmentScripts.clear();
  }
}
