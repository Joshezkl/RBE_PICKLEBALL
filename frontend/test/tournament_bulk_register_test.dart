import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/admin/tournament_admin_register_panel.dart';
import 'package:frontend/core/tournament_models.dart';

TournamentCategoryDefinition _definition({int playersPerTeam = 1}) {
  return TournamentCategoryDefinition(
    key: 'mens_singles_open:intermediate',
    label: 'Mens Singles Open',
    eventKey: 'mens_singles_open',
    eventLabel: 'Mens Singles Open',
    skillLevel: 'intermediate',
    skillLabel: 'Intermediate',
    division: 'open',
    divisionLabel: 'Open',
    playFormat: playersPerTeam == 1 ? 'singles' : 'doubles',
    playersPerTeam: playersPerTeam,
    requiresMixed: false,
    genderRestriction: 'male',
  );
}

void main() {
  test('parses singles one player per line', () {
    final entries = parseTournamentBulkEntries(
      'Josh\n\nRussell\n',
      _definition(),
    );

    expect(entries, [
      ['Josh'],
      ['Russell'],
    ]);
  });

  test('parses doubles with dash-separated partners', () {
    final entries = parseTournamentBulkEntries(
      'Josh-Russell\nMac-Leo',
      _definition(playersPerTeam: 2),
    );

    expect(entries, [
      ['Josh', 'Russell'],
      ['Mac', 'Leo'],
    ]);
  });

  test('rejects doubles line without dash', () {
    expect(
      () => parseTournamentBulkEntries('Josh', _definition(playersPerTeam: 2)),
      throwsFormatException,
    );
  });

  test('rejects doubles line with wrong partner count', () {
    expect(
      () => parseTournamentBulkEntries(
        'Josh-Russell-Mac',
        _definition(playersPerTeam: 2),
      ),
      throwsFormatException,
    );
  });
}
