import '../../core/tournament_models.dart';

class DrawLotsPlayer {
  const DrawLotsPlayer({
    required this.name,
    this.gender,
  });

  final String name;
  final String? gender;
}

bool isSkillGenderlessCategory(TournamentCategoryDefinition definition) {
  return definition.eventKey.startsWith('skill_doubles');
}

bool supportsDrawLots(TournamentCategoryDefinition definition) {
  return definition.playersPerTeam == 2;
}

/// One player per line. Mixed doubles may use `Name (M)` or `Name (F)`.
List<DrawLotsPlayer> parseDrawLotsLines(String text) {
  final players = <DrawLotsPlayer>[];

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = RegExp(r'^(.+?)\s*\(([MFmf])\)\s*$').firstMatch(line);
    if (match != null) {
      final genderChar = match.group(2)!.toUpperCase();
      players.add(
        DrawLotsPlayer(
          name: match.group(1)!.trim(),
          gender: genderChar == 'M' ? 'male' : 'female',
        ),
      );
      continue;
    }

    players.add(DrawLotsPlayer(name: line));
  }

  return players;
}

class DrawLotsPair {
  const DrawLotsPair({
    required this.names,
    required this.genders,
  });

  final List<String> names;
  final List<String> genders;
}

List<DrawLotsPair> buildDrawLotsPairs(
  List<DrawLotsPlayer> players,
  TournamentCategoryDefinition definition,
) {
  if (players.length < 2) {
    throw FormatException('At least 2 players are required for draw lots');
  }

  if (definition.requiresMixed) {
    return _pairMixed(players);
  }

  if (players.length % 2 != 0) {
    throw FormatException(
      'Draw lots requires an even number of players. Found ${players.length}.',
    );
  }

  final shuffled = List<DrawLotsPlayer>.from(players)..shuffle();
  final defaultGender =
      definition.genderRestriction ?? (isSkillGenderlessCategory(definition) ? 'male' : 'male');

  final pairs = <DrawLotsPair>[];
  for (var i = 0; i < shuffled.length; i += 2) {
    pairs.add(
      DrawLotsPair(
        names: [shuffled[i].name, shuffled[i + 1].name],
        genders: [
          shuffled[i].gender ?? defaultGender,
          shuffled[i + 1].gender ?? defaultGender,
        ],
      ),
    );
  }

  return pairs;
}

List<DrawLotsPair> _pairMixed(List<DrawLotsPlayer> players) {
  final males = <DrawLotsPlayer>[];
  final females = <DrawLotsPlayer>[];

  for (final player in players) {
    if (player.gender == 'male') {
      males.add(player);
    } else if (player.gender == 'female') {
      females.add(player);
    } else {
      throw FormatException(
        'Mixed doubles draw lots needs gender on each line. Use "Name (M)" or "Name (F)". '
        'Missing gender for "${player.name}".',
      );
    }
  }

  if (males.isEmpty || females.isEmpty) {
    throw FormatException(
      'Mixed doubles draw lots needs at least one male and one female player.',
    );
  }

  if (males.length != females.length) {
    throw FormatException(
      'Mixed doubles draw lots needs equal male and female counts. '
      'Found ${males.length} male and ${females.length} female.',
    );
  }

  males.shuffle();
  females.shuffle();

  return List.generate(
    males.length,
    (index) => DrawLotsPair(
      names: [males[index].name, females[index].name],
      genders: const ['male', 'female'],
    ),
  );
}

String drawLotsFormatHint(TournamentCategoryDefinition definition) {
  if (definition.requiresMixed) {
    return 'One per line with gender: Player 1 (M), Player 2 (F)';
  }
  if (isSkillGenderlessCategory(definition)) {
    return 'One per line — paired by skill';
  }
  return 'One per line — random pairs';
}

String directTeamsFormatHint(TournamentCategoryDefinition definition) {
  if (definition.playersPerTeam == 1) {
    return 'Singles — one player per line';
  }
  return 'Doubles — one team per line: Player 1 - Player 2';
}
