import '../models.dart';
import '../tournament_models.dart';

double tournamentCourtCardHeightFor(int slotsPerTeam) =>
    slotsPerTeam > 1 ? 176.0 : 148.0;

int tournamentSlotsFromTeamNames(String? teamA, String? teamB) {
  if ((teamA?.contains(' / ') ?? false) || (teamB?.contains(' / ') ?? false)) {
    return 2;
  }
  if (teamA != null || teamB != null) return 1;
  return 0;
}

List<String> tournamentSplitTeamNames(String? team) {
  if (team == null || team.trim().isEmpty) return [];
  return team
      .split(' / ')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

MatchInfo? tournamentCourtMatchForLayout(
  TournamentCourtMatchInfo? match,
  int slotsPerTeam,
) {
  if (match == null) return null;

  MatchPlayer? playerAt(List<String> names, int index, int id) {
    if (index >= names.length) return null;
    return MatchPlayer(id: id, name: names[index]);
  }

  final teamANames = tournamentSplitTeamNames(match.teamA);
  final teamBNames = tournamentSplitTeamNames(match.teamB);

  return MatchInfo(
    id: match.id,
    courtId: 0,
    status: match.isActive ? 'in_match' : 'scheduled',
    scoreA: match.scoreA,
    scoreB: match.scoreB,
    teamA: {
      'player1': playerAt(teamANames, 0, 1),
      'player2': slotsPerTeam > 1 ? playerAt(teamANames, 1, 2) : null,
    },
    teamB: {
      'player1': playerAt(teamBNames, 0, 3),
      'player2': slotsPerTeam > 1 ? playerAt(teamBNames, 1, 4) : null,
    },
  );
}

int tournamentSlotsPerTeamForCategoryKey(String? categoryKey) {
  if (categoryKey == null) return 2;
  return categoryKey.contains('singles') ? 1 : 2;
}
