import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/tournament_models.dart';
import 'package:frontend/features/admin/tournament_draw_lots.dart';

TournamentCategoryDefinition _definition({
  int playersPerTeam = 2,
  bool requiresMixed = false,
  String eventKey = 'mens_doubles_open',
  String? genderRestriction = 'male',
}) {
  return TournamentCategoryDefinition(
    key: '$eventKey:intermediate',
    label: 'Test Doubles',
    eventKey: eventKey,
    eventLabel: 'Test Doubles',
    skillLevel: 'intermediate',
    skillLabel: 'Intermediate',
    division: 'open',
    divisionLabel: 'Open',
    playFormat: playersPerTeam == 1 ? 'singles' : 'doubles',
    playersPerTeam: playersPerTeam,
    requiresMixed: requiresMixed,
    genderRestriction: genderRestriction,
  );
}

void main() {
  test('parses mixed draw lots lines with gender markers', () {
    final players = parseDrawLotsLines('Alex (M)\nBlair (F)\nCasey (M)\nDana (F)');

    expect(players.length, 4);
    expect(players[0].name, 'Alex');
    expect(players[0].gender, 'male');
    expect(players[1].gender, 'female');
  });

  test('builds genderless skill doubles pairs from even player count', () {
    final pairs = buildDrawLotsPairs(
      parseDrawLotsLines('Player 1\nPlayer 2\nPlayer 3\nPlayer 4'),
      _definition(eventKey: 'skill_doubles_open', genderRestriction: null),
    );

    expect(pairs.length, 2);
    expect(pairs.every((pair) => pair.names.length == 2), isTrue);
  });

  test('mixed draw lots requires equal male and female counts', () {
    expect(
      () => buildDrawLotsPairs(
        parseDrawLotsLines('Alex (M)\nBlair (F)\nCasey (M)'),
        _definition(requiresMixed: true, genderRestriction: null),
      ),
      throwsFormatException,
    );
  });
}
