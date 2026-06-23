class TournamentListItem {
  TournamentListItem({
    required this.id,
    required this.name,
    required this.status,
    required this.groupCount,
    this.startedAt,
    this.endedAt,
  });

  final int id;
  final String name;
  final String status;
  final int groupCount;
  final String? startedAt;
  final String? endedAt;

  factory TournamentListItem.fromJson(Map<String, dynamic> json) {
    return TournamentListItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Tournament',
      status: json['status'] as String? ?? 'draft',
      groupCount: json['groupCount'] as int? ?? 4,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
    );
  }
}

class TournamentSkillLevelInfo {
  TournamentSkillLevelInfo({required this.key, required this.label});

  final String key;
  final String label;

  factory TournamentSkillLevelInfo.fromJson(Map<String, dynamic> json) {
    return TournamentSkillLevelInfo(
      key: json['key'] as String,
      label: json['label'] as String? ?? json['key'] as String,
    );
  }
}

class TournamentCategoryDefinition {
  TournamentCategoryDefinition({
    required this.key,
    required this.label,
    required this.eventKey,
    required this.eventLabel,
    required this.skillLevel,
    required this.skillLabel,
    required this.division,
    required this.divisionLabel,
    required this.playFormat,
    required this.playersPerTeam,
    required this.requiresMixed,
    this.genderRestriction,
    this.minAge,
  });

  final String key;
  final String label;
  final String eventKey;
  final String eventLabel;
  final String skillLevel;
  final String skillLabel;
  final String division;
  final String divisionLabel;
  final String playFormat;
  final int playersPerTeam;
  final bool requiresMixed;
  final String? genderRestriction;
  final int? minAge;

  factory TournamentCategoryDefinition.fromJson(Map<String, dynamic> json) {
    return TournamentCategoryDefinition(
      key: json['key'] as String,
      label: json['label'] as String? ?? json['key'] as String,
      eventKey: json['eventKey'] as String? ?? '',
      eventLabel: json['eventLabel'] as String? ?? '',
      skillLevel: json['skillLevel'] as String? ?? 'beginner',
      skillLabel: json['skillLabel'] as String? ?? 'Beginner',
      division: json['division'] as String? ?? 'open',
      divisionLabel: json['divisionLabel'] as String? ?? 'Open Division',
      playFormat: json['playFormat'] as String? ?? 'doubles',
      playersPerTeam: json['playersPerTeam'] as int? ?? 2,
      requiresMixed: json['requiresMixed'] as bool? ?? false,
      genderRestriction: json['genderRestriction'] as String?,
      minAge: json['minAge'] as int?,
    );
  }
}

class TournamentCategorySkillOption {
  TournamentCategorySkillOption({
    required this.key,
    required this.label,
    required this.skillLevel,
    required this.skillLabel,
  });

  final String key;
  final String label;
  final String skillLevel;
  final String skillLabel;

  factory TournamentCategorySkillOption.fromJson(Map<String, dynamic> json) {
    return TournamentCategorySkillOption(
      key: json['key'] as String,
      label: json['label'] as String? ?? json['key'] as String,
      skillLevel: json['skillLevel'] as String? ?? 'beginner',
      skillLabel: json['skillLabel'] as String? ?? 'Beginner',
    );
  }
}

class TournamentCategoryEventGroup {
  TournamentCategoryEventGroup({
    required this.eventKey,
    required this.eventLabel,
    required this.playFormat,
    required this.playersPerTeam,
    required this.skillLevels,
  });

  final String eventKey;
  final String eventLabel;
  final String playFormat;
  final int playersPerTeam;
  final List<TournamentCategorySkillOption> skillLevels;

  factory TournamentCategoryEventGroup.fromJson(Map<String, dynamic> json) {
    return TournamentCategoryEventGroup(
      eventKey: json['eventKey'] as String,
      eventLabel: json['eventLabel'] as String? ?? '',
      playFormat: json['playFormat'] as String? ?? 'doubles',
      playersPerTeam: json['playersPerTeam'] as int? ?? 2,
      skillLevels: (json['skillLevels'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentCategorySkillOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TournamentCategoryDivisionGroup {
  TournamentCategoryDivisionGroup({
    required this.division,
    required this.divisionLabel,
    required this.events,
  });

  final String division;
  final String divisionLabel;
  final List<TournamentCategoryEventGroup> events;

  factory TournamentCategoryDivisionGroup.fromJson(Map<String, dynamic> json) {
    return TournamentCategoryDivisionGroup(
      division: json['division'] as String,
      divisionLabel: json['divisionLabel'] as String? ?? '',
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentCategoryEventGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TournamentTeamInfo {
  TournamentTeamInfo({
    required this.id,
    required this.displayName,
    this.groupKey,
    this.seed,
    required this.status,
    required this.wins,
    required this.losses,
    required this.pointsScored,
    required this.pointsAllowed,
    required this.pointDifferential,
    required this.players,
  });

  final int id;
  final String displayName;
  final String? groupKey;
  final int? seed;
  final String status;
  final int wins;
  final int losses;
  final int pointsScored;
  final int pointsAllowed;
  final int pointDifferential;
  final List<TournamentPlayerRef> players;

  factory TournamentTeamInfo.fromJson(Map<String, dynamic> json) {
    return TournamentTeamInfo(
      id: json['id'] as int,
      displayName: json['displayName'] as String? ?? 'Team',
      groupKey: json['groupKey'] as String?,
      seed: json['seed'] as int?,
      status: json['status'] as String? ?? 'active',
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      pointsScored: json['pointsScored'] as int? ?? 0,
      pointsAllowed: json['pointsAllowed'] as int? ?? 0,
      pointDifferential: json['pointDifferential'] as int? ?? 0,
      players: (json['players'] as List<dynamic>? ?? [])
          .map((e) => TournamentPlayerRef.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TournamentPlayerRef {
  TournamentPlayerRef({required this.id, required this.name});

  final int id;
  final String name;

  factory TournamentPlayerRef.fromJson(Map<String, dynamic> json) {
    return TournamentPlayerRef(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Player',
    );
  }
}

class TournamentStandingRow {
  TournamentStandingRow({
    required this.teamId,
    required this.displayName,
    required this.wins,
    required this.losses,
    required this.pointsScored,
    required this.pointsAllowed,
    required this.pointDifferential,
    required this.rank,
    required this.status,
    this.groupKey,
  });

  final int teamId;
  final String displayName;
  final int wins;
  final int losses;
  final int pointsScored;
  final int pointsAllowed;
  final int pointDifferential;
  final int rank;
  final String status;
  final String? groupKey;

  factory TournamentStandingRow.fromJson(Map<String, dynamic> json) {
    return TournamentStandingRow(
      teamId: json['teamId'] as int,
      displayName: json['displayName'] as String? ?? 'Team',
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      pointsScored: json['pointsScored'] as int? ?? 0,
      pointsAllowed: json['pointsAllowed'] as int? ?? 0,
      pointDifferential: json['pointDifferential'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      groupKey: json['groupKey'] as String?,
    );
  }
}

class TournamentGroupState {
  TournamentGroupState({
    required this.key,
    required this.label,
    required this.standings,
    required this.matches,
  });

  final String key;
  final String label;
  final List<TournamentStandingRow> standings;
  final List<TournamentMatchInfo> matches;

  factory TournamentGroupState.fromJson(Map<String, dynamic> json) {
    return TournamentGroupState(
      key: json['key'] as String,
      label: json['label'] as String? ?? 'Group',
      standings: (json['standings'] as List<dynamic>? ?? [])
          .map((e) => TournamentStandingRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      matches: (json['matches'] as List<dynamic>? ?? [])
          .map((e) => TournamentMatchInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TournamentBracketRound {
  TournamentBracketRound({
    required this.roundIndex,
    required this.label,
    required this.matches,
  });

  final int roundIndex;
  final String label;
  final List<TournamentMatchInfo> matches;

  factory TournamentBracketRound.fromJson(Map<String, dynamic> json) {
    return TournamentBracketRound(
      roundIndex: json['roundIndex'] as int? ?? 0,
      label: json['label'] as String? ?? 'Round',
      matches: (json['matches'] as List<dynamic>? ?? [])
          .map((e) => TournamentMatchInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TournamentBracket {
  TournamentBracket({required this.rounds});

  final List<TournamentBracketRound> rounds;

  factory TournamentBracket.fromJson(Map<String, dynamic> json) {
    return TournamentBracket(
      rounds: (json['rounds'] as List<dynamic>? ?? [])
          .map((e) => TournamentBracketRound.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TournamentMatchInfo {
  TournamentMatchInfo({
    required this.id,
    required this.phase,
    this.groupKey,
    required this.roundIndex,
    required this.matchIndex,
    required this.status,
    this.courtNumber,
    this.scoreA,
    this.scoreB,
    this.teamA,
    this.teamB,
    this.winnerTeamId,
  });

  final int id;
  final String phase;
  final String? groupKey;
  final int roundIndex;
  final int matchIndex;
  final String status;
  final int? courtNumber;
  final int? scoreA;
  final int? scoreB;
  final TournamentTeamInfo? teamA;
  final TournamentTeamInfo? teamB;
  final int? winnerTeamId;

  bool get isFinished => status == 'finished';
  bool get isOnCourt => status == 'on_court';
  bool get isAssignedToCourt =>
      status == 'scheduled' && courtNumber != null;
  bool get canScore =>
      status == 'on_court' && teamA != null && teamB != null;

  String get label {
    if (phase == 'third_place') return '3rd place match';
    if (phase == 'tiebreaker') return 'Tiebreaker';
    if (phase == 'final_round_robin') return 'Final RR #${matchIndex + 1}';
    if (phase == 'single_elimination') return 'Final';
    if (groupKey != null) return 'Group $groupKey';
    return 'Round Robin #${matchIndex + 1}';
  }

  factory TournamentMatchInfo.fromJson(Map<String, dynamic> json) {
    return TournamentMatchInfo(
      id: json['id'] as int,
      phase: json['phase'] as String? ?? 'round_robin',
      groupKey: json['groupKey'] as String?,
      roundIndex: json['roundIndex'] as int? ?? 0,
      matchIndex: json['matchIndex'] as int? ?? 0,
      status: json['status'] as String? ?? 'scheduled',
      courtNumber: json['courtNumber'] as int?,
      scoreA: json['scoreA'] as int?,
      scoreB: json['scoreB'] as int?,
      teamA: json['teamA'] != null
          ? TournamentTeamInfo.fromJson(json['teamA'] as Map<String, dynamic>)
          : null,
      teamB: json['teamB'] != null
          ? TournamentTeamInfo.fromJson(json['teamB'] as Map<String, dynamic>)
          : null,
      winnerTeamId: json['winnerTeamId'] as int?,
    );
  }
}

class TournamentPlacement {
  TournamentPlacement({
    required this.place,
    required this.teamId,
    required this.displayName,
  });

  final int place;
  final int teamId;
  final String displayName;

  factory TournamentPlacement.fromJson(Map<String, dynamic> json) {
    return TournamentPlacement(
      place: json['place'] as int,
      teamId: json['teamId'] as int,
      displayName: json['displayName'] as String? ?? 'Team',
    );
  }
}

class TournamentCategoryState {
  TournamentCategoryState({
    required this.key,
    required this.label,
    required this.eventKey,
    required this.eventLabel,
    required this.skillLevel,
    required this.skillLabel,
    required this.division,
    required this.isEnabled,
    required this.phase,
    this.categoryId,
    required this.teams,
    required this.standings,
    required this.groups,
    required this.matches,
    this.bracket,
    this.placements = const [],
    this.thirdPlaceMatch,
  });

  final String key;
  final String label;
  final String eventKey;
  final String eventLabel;
  final String skillLevel;
  final String skillLabel;
  final String division;
  final bool isEnabled;
  final String phase;
  final int? categoryId;
  final List<TournamentTeamInfo> teams;
  final List<TournamentStandingRow> standings;
  final List<TournamentGroupState> groups;
  final List<TournamentMatchInfo> matches;
  final TournamentBracket? bracket;
  final List<TournamentPlacement> placements;
  final TournamentMatchInfo? thirdPlaceMatch;

  factory TournamentCategoryState.fromJson(Map<String, dynamic> json) {
    return TournamentCategoryState(
      key: json['key'] as String,
      label: json['label'] as String? ?? json['key'] as String,
      eventKey: json['eventKey'] as String? ?? '',
      eventLabel: json['eventLabel'] as String? ?? '',
      skillLevel: json['skillLevel'] as String? ?? 'beginner',
      skillLabel: json['skillLabel'] as String? ?? 'Beginner',
      division: json['division'] as String? ?? 'open',
      isEnabled: json['isEnabled'] as bool? ?? false,
      phase: json['phase'] as String? ?? 'setup',
      categoryId: json['categoryId'] as int?,
      teams: (json['teams'] as List<dynamic>? ?? [])
          .map((e) => TournamentTeamInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      standings: (json['standings'] as List<dynamic>? ?? [])
          .map((e) => TournamentStandingRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      groups: (json['groups'] as List<dynamic>? ?? [])
          .map((e) => TournamentGroupState.fromJson(e as Map<String, dynamic>))
          .toList(),
      matches: (json['matches'] as List<dynamic>? ?? [])
          .map((e) => TournamentMatchInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      bracket: json['bracket'] != null
          ? TournamentBracket.fromJson(json['bracket'] as Map<String, dynamic>)
          : null,
      placements: (json['placements'] as List<dynamic>? ?? [])
          .map((e) => TournamentPlacement.fromJson(e as Map<String, dynamic>))
          .toList(),
      thirdPlaceMatch: json['thirdPlaceMatch'] != null
          ? TournamentMatchInfo.fromJson(
              json['thirdPlaceMatch'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TournamentMeta {
  TournamentMeta({
    required this.id,
    required this.name,
    required this.status,
    required this.groupCount,
    required this.groupLabels,
    required this.courtCount,
    required this.format,
    this.registrationToken,
    this.registrationOpen = false,
    this.startedAt,
    this.endedAt,
  });

  final int id;
  final String name;
  final String status;
  final int groupCount;
  final List<String> groupLabels;
  final int courtCount;
  final String format;
  final String? registrationToken;
  final bool registrationOpen;
  final String? startedAt;
  final String? endedAt;

  bool get canEdit => status == 'draft' || status == 'setup';
  bool get canManageParticipants =>
      canEdit || status == 'round_robin';
  bool get isLive =>
      status == 'round_robin' ||
      status == 'single_elimination' ||
      status == 'final_round_robin';

  factory TournamentMeta.fromJson(Map<String, dynamic> json) {
    return TournamentMeta(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Tournament',
      status: json['status'] as String? ?? 'draft',
      groupCount: json['groupCount'] as int? ?? 4,
      groupLabels: (json['groupLabels'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      courtCount: json['courtCount'] as int? ?? 4,
      format: json['format'] as String? ??
          'group_round_robin_then_single_elimination',
      registrationToken: json['registrationToken'] as String?,
      registrationOpen: json['registrationOpen'] as bool? ?? false,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
    );
  }
}

class TournamentActiveCategoryInfo {
  TournamentActiveCategoryInfo({
    required this.key,
    required this.label,
    required this.phase,
  });

  final String key;
  final String label;
  final String phase;

  factory TournamentActiveCategoryInfo.fromJson(Map<String, dynamic> json) {
    return TournamentActiveCategoryInfo(
      key: json['key'] as String,
      label: json['label'] as String? ?? json['key'] as String,
      phase: json['phase'] as String? ?? 'round_robin',
    );
  }
}

class TournamentCourtMatchInfo {
  TournamentCourtMatchInfo({
    required this.id,
    required this.categoryLabel,
    required this.phase,
    this.isActive = false,
    this.groupKey,
    this.groupLabel,
    this.teamA,
    this.teamB,
    this.scoreA,
    this.scoreB,
  });

  final int id;
  final String categoryLabel;
  final String phase;
  final bool isActive;
  final String? groupKey;
  final String? groupLabel;
  final String? teamA;
  final String? teamB;
  final int? scoreA;
  final int? scoreB;

  factory TournamentCourtMatchInfo.fromJson(Map<String, dynamic> json) {
    return TournamentCourtMatchInfo(
      id: json['id'] as int,
      categoryLabel: json['categoryLabel'] as String? ?? 'Category',
      phase: json['phase'] as String? ?? 'round_robin',
      isActive: json['isActive'] as bool? ?? false,
      groupKey: json['groupKey'] as String?,
      groupLabel: json['groupLabel'] as String?,
      teamA: json['teamA'] as String?,
      teamB: json['teamB'] as String?,
      scoreA: json['scoreA'] as int?,
      scoreB: json['scoreB'] as int?,
    );
  }
}

class TournamentCourtInfo {
  TournamentCourtInfo({
    required this.courtNumber,
    required this.status,
    this.preferredGroupKey,
    this.preferredGroupLabel,
    this.match,
  });

  final int courtNumber;
  final String status;
  final String? preferredGroupKey;
  final String? preferredGroupLabel;
  final TournamentCourtMatchInfo? match;

  bool get isActive => status == 'in_match' && match != null;
  bool get isAssigned => status == 'assigned' && match != null;
  bool get hasMatch => match != null;

  factory TournamentCourtInfo.fromJson(Map<String, dynamic> json) {
    return TournamentCourtInfo(
      courtNumber: json['courtNumber'] as int,
      status: json['status'] as String? ?? 'available',
      preferredGroupKey: json['preferredGroupKey'] as String?,
      preferredGroupLabel: json['preferredGroupLabel'] as String?,
      match: json['match'] != null
          ? TournamentCourtMatchInfo.fromJson(
              json['match'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TournamentUpNextMatchInfo {
  TournamentUpNextMatchInfo({
    required this.id,
    required this.categoryLabel,
    required this.phase,
    this.groupKey,
    this.groupLabel,
    this.recommendedCourtNumber,
    this.teamA,
    this.teamB,
    this.isReady = true,
  });

  final int id;
  final String categoryLabel;
  final String phase;
  final String? groupKey;
  final String? groupLabel;
  final int? recommendedCourtNumber;
  final String? teamA;
  final String? teamB;
  final bool isReady;

  factory TournamentUpNextMatchInfo.fromJson(Map<String, dynamic> json) {
    return TournamentUpNextMatchInfo(
      id: json['id'] as int,
      categoryLabel: json['categoryLabel'] as String? ?? 'Category',
      phase: json['phase'] as String? ?? 'round_robin',
      groupKey: json['groupKey'] as String?,
      groupLabel: json['groupLabel'] as String?,
      recommendedCourtNumber: json['recommendedCourtNumber'] as int?,
      teamA: json['teamA'] as String?,
      teamB: json['teamB'] as String?,
      isReady: json['isReady'] as bool? ?? true,
    );
  }
}

class TournamentRecentResultInfo {
  TournamentRecentResultInfo({
    required this.id,
    required this.categoryLabel,
    this.groupLabel,
    this.teamA,
    this.teamB,
    this.scoreA,
    this.scoreB,
    this.winnerTeamId,
  });

  final int id;
  final String categoryLabel;
  final String? groupLabel;
  final String? teamA;
  final String? teamB;
  final int? scoreA;
  final int? scoreB;
  final int? winnerTeamId;

  factory TournamentRecentResultInfo.fromJson(Map<String, dynamic> json) {
    return TournamentRecentResultInfo(
      id: json['id'] as int,
      categoryLabel: json['categoryLabel'] as String? ?? 'Category',
      groupLabel: json['groupLabel'] as String?,
      teamA: json['teamA'] as String?,
      teamB: json['teamB'] as String?,
      scoreA: json['scoreA'] as int?,
      scoreB: json['scoreB'] as int?,
      winnerTeamId: json['winnerTeamId'] as int?,
    );
  }
}

class TournamentDisplayState {
  TournamentDisplayState({
    required this.courts,
    required this.upNext,
    required this.recentResults,
    this.activeCategory,
  });

  final List<TournamentCourtInfo> courts;
  final List<TournamentUpNextMatchInfo> upNext;
  final List<TournamentRecentResultInfo> recentResults;
  final TournamentActiveCategoryInfo? activeCategory;

  factory TournamentDisplayState.fromJson(Map<String, dynamic> json) {
    return TournamentDisplayState(
      courts: (json['courts'] as List<dynamic>? ?? [])
          .map((e) => TournamentCourtInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      upNext: (json['upNext'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentUpNextMatchInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentResults: (json['recentResults'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentRecentResultInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeCategory: json['activeCategory'] != null
          ? TournamentActiveCategoryInfo.fromJson(
              json['activeCategory'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TournamentState {
  TournamentState({
    required this.tournament,
    required this.skillLevels,
    required this.availableCategories,
    required this.categoryGroups,
    required this.categories,
    this.display,
  });

  final TournamentMeta tournament;
  final List<TournamentSkillLevelInfo> skillLevels;
  final List<TournamentCategoryDefinition> availableCategories;
  final List<TournamentCategoryDivisionGroup> categoryGroups;
  final List<TournamentCategoryState> categories;
  final TournamentDisplayState? display;

  List<TournamentCategoryState> get activeCategories =>
      categories.where((c) => c.isEnabled).toList();

  factory TournamentState.fromJson(Map<String, dynamic> json) {
    return TournamentState(
      tournament: TournamentMeta.fromJson(
        json['tournament'] as Map<String, dynamic>,
      ),
      skillLevels: (json['skillLevels'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentSkillLevelInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      availableCategories: (json['availableCategories'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentCategoryDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      categoryGroups: (json['categoryGroups'] as List<dynamic>? ?? [])
          .map((e) => TournamentCategoryDivisionGroup.fromJson(
              e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => TournamentCategoryState.fromJson(e as Map<String, dynamic>))
          .toList(),
      display: json['display'] != null
          ? TournamentDisplayState.fromJson(
              json['display'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class TournamentListResponse {
  TournamentListResponse({
    required this.tournaments,
    required this.skillLevels,
    required this.availableCategories,
    required this.categoryGroups,
  });

  final List<TournamentListItem> tournaments;
  final List<TournamentSkillLevelInfo> skillLevels;
  final List<TournamentCategoryDefinition> availableCategories;
  final List<TournamentCategoryDivisionGroup> categoryGroups;

  factory TournamentListResponse.fromJson(Map<String, dynamic> json) {
    return TournamentListResponse(
      tournaments: (json['tournaments'] as List<dynamic>? ?? [])
          .map((e) => TournamentListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      skillLevels: (json['skillLevels'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentSkillLevelInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      availableCategories: (json['availableCategories'] as List<dynamic>? ?? [])
          .map((e) =>
              TournamentCategoryDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      categoryGroups: (json['categoryGroups'] as List<dynamic>? ?? [])
          .map((e) => TournamentCategoryDivisionGroup.fromJson(
              e as Map<String, dynamic>))
          .toList(),
    );
  }
}
