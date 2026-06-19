import '../tournament_models.dart';
import 'display_announcer.dart';

class TournamentAnnouncer {
  TournamentAnnouncer._();
  static final TournamentAnnouncer instance = TournamentAnnouncer._();

  bool enabled = true;
  final _spokenActivationMatchIds = <int>{};
  final _spokenResultIds = <int>{};

  bool get isSupported => DisplayAnnouncer.instance.isSupported;

  Future<void> speak(String text) async {
    if (!enabled || text.trim().isEmpty) return;
    await DisplayAnnouncer.instance.speak(text);
  }

  void announceCourtAssignment(TournamentCourtInfo court) {
    final match = court.match;
    if (match == null) return;
    if (_spokenActivationMatchIds.contains(match.id)) return;
    _spokenActivationMatchIds.add(match.id);

    final group = match.groupLabel != null ? '${match.groupLabel}. ' : '';
    final teamA = match.teamA ?? 'open slot';
    final teamB = match.teamB ?? 'open slot';
    speak(
      'Now playing on Court ${court.courtNumber}. '
      '$group$teamA versus $teamB.',
    );
  }

  Future<void> announceMatchResult(
    TournamentRecentResultInfo result, {
    int? courtNumber,
  }) async {
    if (_spokenResultIds.contains(result.id)) return;
    _spokenResultIds.add(result.id);

    final scoreA = result.scoreA ?? 0;
    final scoreB = result.scoreB ?? 0;
    final winner = scoreA == scoreB
        ? null
        : (scoreA > scoreB ? result.teamA : result.teamB);
    final courtLabel = courtNumber != null ? 'Court $courtNumber. ' : '';
    final winnerLabel = winner ?? 'Match complete';

    await speak(
      '$courtLabel$winnerLabel wins! '
      'Final score, $scoreA to $scoreB.',
    );
  }

  Future<void> announceUpNext(
    TournamentUpNextMatchInfo match, {
    String prefix = 'Up next',
  }) async {
    final group = match.groupLabel != null ? '${match.groupLabel}. ' : '';
    await speak(
      '$prefix. $group${match.teamA ?? 'TBD'} '
      'versus ${match.teamB ?? 'TBD'}.',
    );
  }

  void cancelSpeech() {
    DisplayAnnouncer.instance.cancelSpeech();
  }

  void dispose() {
    cancelSpeech();
    _spokenActivationMatchIds.clear();
    _spokenResultIds.clear();
  }
}
