import '../tournament_models.dart';

class TournamentAnnouncer {
  TournamentAnnouncer._();
  static final TournamentAnnouncer instance = TournamentAnnouncer._();

  bool enabled = true;
  bool get isSupported => false;

  Future<void> speak(String text) async {}

  void announceCourtAssignment(TournamentCourtInfo court) {}

  Future<void> announceMatchResult(
    TournamentRecentResultInfo result, {
    int? courtNumber,
  }) async {}

  Future<void> announceUpNext(
    TournamentUpNextMatchInfo match, {
    String prefix = 'Up next',
  }) async {}

  void cancelSpeech() {}

  void dispose() {}
}
