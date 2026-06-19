import '../models.dart';

class DisplayAnnouncer {
  DisplayAnnouncer._();
  static final DisplayAnnouncer instance = DisplayAnnouncer._();

  bool enabled = true;
  bool get isSupported => false;

  final Map<int, String> lastCourtAssignmentScripts = {};

  Future<void> speak(String text) async {}

  void announceCourtAssignment(CourtInfo court) {}

  Future<void> announceMatchResult(MatchInfo match, int? courtNumber) async {}

  String? buildNextGameScript(SessionState state) => null;

  Future<void> announceNextGame(SessionState state) async {}

  Future<void> repeatCourtAssignment(CourtInfo court) async {}

  void cancelSpeech() {}

  void dispose() {}
}
