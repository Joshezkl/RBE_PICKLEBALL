class SessionInfo {
  SessionInfo({
    required this.id,
    required this.name,
    required this.status,
    required this.matchMode,
    required this.matchModeLabel,
    required this.playFormat,
    required this.courtCount,
    required this.nextCourtQueue,
    required this.nextNewPlayerQueue,
    required this.queueTypes,
    this.startedAt,
    this.endedAt,
    this.checkInToken,
    this.autoAssignEnabled = false,
    this.requirePayment = false,
    this.sessionFeeCents = 0,
  });

  final int id;
  final String name;
  final String status;
  final String matchMode;
  final String matchModeLabel;
  final String playFormat;
  final int courtCount;
  final String nextCourtQueue;
  final String nextNewPlayerQueue;
  final List<String> queueTypes;
  final String? startedAt;
  final String? endedAt;
  final String? checkInToken;
  final bool autoAssignEnabled;
  final bool requirePayment;
  final int sessionFeeCents;

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
      matchMode: json['matchMode'] as String? ?? 'auto_balanced',
      matchModeLabel: json['matchModeLabel'] as String? ?? 'Auto-Balanced',
      playFormat: json['playFormat'] as String,
      courtCount: json['courtCount'] as int,
      nextCourtQueue: json['nextCourtQueue'] as String,
      nextNewPlayerQueue: json['nextNewPlayerQueue'] as String,
      queueTypes: (json['queueTypes'] as List<dynamic>? ?? ['winner', 'loser'])
          .map((e) => e as String)
          .toList(),
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      checkInToken: json['checkInToken'] as String?,
      autoAssignEnabled: json['autoAssignEnabled'] as bool? ?? false,
      requirePayment: json['requirePayment'] as bool? ?? false,
      sessionFeeCents: json['sessionFeeCents'] as int? ?? 0,
    );
  }

  bool get isActive => status == 'active';
}

class QueuePlayer {
  QueuePlayer({
    required this.id,
    required this.name,
    required this.wins,
    required this.losses,
    required this.position,
  });

  final int id;
  final String name;
  final int wins;
  final int losses;
  final int position;

  factory QueuePlayer.fromJson(Map<String, dynamic> json) {
    return QueuePlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      position: json['position'] as int,
    );
  }
}

class MatchPlayer {
  MatchPlayer({required this.id, required this.name});

  final int id;
  final String name;

  factory MatchPlayer.fromJson(Map<String, dynamic> json) {
    return MatchPlayer(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class MatchInfo {
  MatchInfo({
    required this.id,
    required this.courtId,
    required this.status,
    this.scoreA,
    this.scoreB,
    this.winnerTeam,
    required this.teamA,
    required this.teamB,
    this.startedAt,
    this.finishedAt,
    this.courtNumber,
    this.elapsedSeconds,
    this.durationMinutes,
    this.isChallengeCourt = false,
  });

  final int id;
  final int courtId;
  final String status;
  final int? scoreA;
  final int? scoreB;
  final String? winnerTeam;
  final Map<String, MatchPlayer?> teamA;
  final Map<String, MatchPlayer?> teamB;
  final String? startedAt;
  final String? finishedAt;
  final int? courtNumber;
  final int? elapsedSeconds;
  final int? durationMinutes;
  final bool isChallengeCourt;

  factory MatchInfo.fromJson(Map<String, dynamic> json) {
    MatchPlayer? parsePlayer(dynamic value) {
      if (value == null) return null;
      return MatchPlayer.fromJson(value as Map<String, dynamic>);
    }

    return MatchInfo(
      id: json['id'] as int,
      courtId: json['courtId'] as int,
      status: json['status'] as String,
      scoreA: json['scoreA'] as int?,
      scoreB: json['scoreB'] as int?,
      winnerTeam: json['winnerTeam'] as String?,
      teamA: {
        'player1': parsePlayer(json['teamA']?['player1']),
        'player2': parsePlayer(json['teamA']?['player2']),
      },
      teamB: {
        'player1': parsePlayer(json['teamB']?['player1']),
        'player2': parsePlayer(json['teamB']?['player2']),
      },
      startedAt: json['startedAt'] as String?,
      finishedAt: json['finishedAt'] as String?,
      courtNumber: json['courtNumber'] as int?,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.round(),
      durationMinutes: (json['durationMinutes'] as num?)?.round(),
      isChallengeCourt: json['isChallengeCourt'] as bool? ?? false,
    );
  }

  String get durationLabel {
    if (durationMinutes != null && durationMinutes! > 0) {
      return '${durationMinutes}m';
    }
    if (startedAt != null && finishedAt != null) {
      final start = DateTime.tryParse(startedAt!);
      final end = DateTime.tryParse(finishedAt!);
      if (start != null && end != null) {
        final mins = end.difference(start).inMinutes;
        if (mins > 0) return '${mins}m';
      }
    }
    return '';
  }

  String get teamALabel {
    final names = [
      teamA['player1']?.name,
      teamA['player2']?.name,
    ].whereType<String>();
    return names.join(' & ');
  }

  String get teamBLabel {
    final names = [
      teamB['player1']?.name,
      teamB['player2']?.name,
    ].whereType<String>();
    return names.join(' & ');
  }
}

class CourtInfo {
  CourtInfo({
    required this.id,
    required this.courtNumber,
    required this.status,
    this.skillBracket,
    this.isChallengeCourt = false,
    this.currentMatchId,
    this.match,
    this.defendingTeam,
    this.canAssignInitial = false,
    this.canNextChallenger = false,
  });

  final int id;
  final int courtNumber;
  final String status;
  final String? skillBracket;
  final bool isChallengeCourt;
  final int? currentMatchId;
  final MatchInfo? match;
  final ChallengeCourtTeam? defendingTeam;
  final bool canAssignInitial;
  final bool canNextChallenger;

  factory CourtInfo.fromJson(Map<String, dynamic> json) {
    return CourtInfo(
      id: json['id'] as int,
      courtNumber: json['courtNumber'] as int,
      status: json['status'] as String,
      skillBracket: json['skillBracket'] as String?,
      isChallengeCourt: json['isChallengeCourt'] as bool? ?? false,
      currentMatchId: json['currentMatchId'] as int?,
      match: json['match'] != null
          ? MatchInfo.fromJson(json['match'] as Map<String, dynamic>)
          : null,
      defendingTeam: json['defendingTeam'] != null
          ? ChallengeCourtTeam.fromJson(
              json['defendingTeam'] as Map<String, dynamic>,
            )
          : null,
      canAssignInitial: json['canAssignInitial'] as bool? ?? false,
      canNextChallenger: json['canNextChallenger'] as bool? ?? false,
    );
  }
}

class ChallengeCourtPlayer {
  const ChallengeCourtPlayer({
    required this.id,
    required this.name,
    this.wins = 0,
    this.losses = 0,
  });

  final int id;
  final String name;
  final int wins;
  final int losses;

  factory ChallengeCourtPlayer.fromJson(Map<String, dynamic> json) {
    return ChallengeCourtPlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
    );
  }
}

class ChallengeCourtTeam {
  const ChallengeCourtTeam({
    required this.id,
    required this.displayName,
    required this.position,
    required this.status,
    this.player1,
    this.player2,
    this.currentMatchId,
    this.ccWins = 0,
    this.courtId,
  });

  final int id;
  final String displayName;
  final int position;
  final String status;
  final ChallengeCourtPlayer? player1;
  final ChallengeCourtPlayer? player2;
  final int? currentMatchId;
  final int ccWins;
  final int? courtId;

  bool get canReturn => status == 'queued' || status == 'idle';

  String get recordLabel => '$ccWins-${1 - ccWins}';

  factory ChallengeCourtTeam.fromJson(Map<String, dynamic> json) {
    ChallengeCourtPlayer? parsePlayer(dynamic value) {
      if (value == null) return null;
      return ChallengeCourtPlayer.fromJson(value as Map<String, dynamic>);
    }

    return ChallengeCourtTeam(
      id: json['id'] as int,
      displayName: json['displayName'] as String,
      position: json['position'] as int,
      status: json['status'] as String,
      player1: parsePlayer(json['player1']),
      player2: parsePlayer(json['player2']),
      currentMatchId: json['currentMatchId'] as int?,
      ccWins: json['ccWins'] as int? ?? 0,
      courtId: json['courtId'] as int?,
    );
  }
}

class ChallengeCourtState {
  const ChallengeCourtState({
    required this.isOpen,
    required this.courtNumbers,
    required this.teams,
    required this.eligiblePlayers,
    required this.canAssignNext,
  });

  static const empty = ChallengeCourtState(
    isOpen: false,
    courtNumbers: [1],
    teams: [],
    eligiblePlayers: [],
    canAssignNext: false,
  );

  final bool isOpen;
  final List<int> courtNumbers;
  final List<ChallengeCourtTeam> teams;
  final List<ChallengeCourtPlayer> eligiblePlayers;
  final bool canAssignNext;

  factory ChallengeCourtState.fromJson(Map<String, dynamic> json) {
    return ChallengeCourtState(
      isOpen: json['isOpen'] as bool? ?? false,
      courtNumbers: (json['courtNumbers'] as List<dynamic>? ?? [1])
          .map((e) => (e as num).toInt())
          .toList(),
      teams: (json['teams'] as List<dynamic>? ?? [])
          .map((e) => ChallengeCourtTeam.fromJson(e as Map<String, dynamic>))
          .toList(),
      eligiblePlayers: (json['eligiblePlayers'] as List<dynamic>? ?? [])
          .map(
            (e) => ChallengeCourtPlayer.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      canAssignNext: json['canAssignNext'] as bool? ?? false,
    );
  }
}

class UpNextGroup {
  UpNextGroup({
    required this.queueType,
    required this.players,
    required this.ready,
  });

  final String queueType;
  final List<QueuePlayer> players;
  final bool ready;

  factory UpNextGroup.fromJson(Map<String, dynamic> json) {
    return UpNextGroup(
      queueType: json['queueType'] as String,
      players: (json['players'] as List<dynamic>)
          .map((e) => QueuePlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      ready: json['ready'] as bool? ?? false,
    );
  }
}

class PendingPayment {
  PendingPayment({
    required this.sessionPlayerId,
    required this.clubPlayerId,
    required this.name,
    this.isGuest = false,
    this.registeredAt,
  });

  final int sessionPlayerId;
  final int clubPlayerId;
  final String name;
  final bool isGuest;
  final String? registeredAt;

  factory PendingPayment.fromJson(Map<String, dynamic> json) {
    return PendingPayment(
      sessionPlayerId: json['sessionPlayerId'] as int,
      clubPlayerId: json['clubPlayerId'] as int,
      name: json['name'] as String,
      isGuest: json['isGuest'] as bool? ?? false,
      registeredAt: json['registeredAt'] as String?,
    );
  }
}

class SessionState {
  SessionState({
    required this.session,
    required this.queues,
    required this.courts,
    required this.upNext,
    required this.matchHistory,
    this.finishedMatchCount,
    this.pendingPayments = const [],
    this.challengeCourt = ChallengeCourtState.empty,
  });

  final SessionInfo session;
  final Map<String, List<QueuePlayer>> queues;
  final List<CourtInfo> courts;
  final List<UpNextGroup> upNext;
  final List<MatchInfo> matchHistory;
  final int? finishedMatchCount;
  final List<PendingPayment> pendingPayments;
  final ChallengeCourtState challengeCourt;

  int get completedMatchCount =>
      finishedMatchCount ?? matchHistory.length;

  factory SessionState.fromJson(Map<String, dynamic> json) {
    final queuesJson = json['queues'] as Map<String, dynamic>? ?? {};
    final queues = <String, List<QueuePlayer>>{};
    for (final entry in queuesJson.entries) {
      queues[entry.key] = (entry.value as List<dynamic>? ?? [])
          .map((e) => QueuePlayer.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return SessionState(
      session: SessionInfo.fromJson(json['session'] as Map<String, dynamic>),
      queues: queues,
      courts: (json['courts'] as List<dynamic>? ?? [])
          .map((e) => CourtInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      upNext: (json['upNext'] as List<dynamic>? ?? [])
          .map((e) => UpNextGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      matchHistory: (json['matchHistory'] as List<dynamic>? ?? [])
          .map((e) => MatchInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      finishedMatchCount: (json['finishedMatchCount'] as num?)?.toInt(),
      pendingPayments: (json['pendingPayments'] as List<dynamic>? ?? [])
          .map((e) => PendingPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
      challengeCourt: json['challengeCourt'] != null
          ? ChallengeCourtState.fromJson(
              json['challengeCourt'] as Map<String, dynamic>,
            )
          : ChallengeCourtState.empty,
    );
  }

  /// Merges a lightweight poll response into existing state.
  SessionState mergeLivePoll(SessionState live, {required bool retainAdminExtras}) {
    if (!retainAdminExtras) {
      return live;
    }

    final historyUnchanged =
        live.completedMatchCount == completedMatchCount;

    return SessionState(
      session: live.session,
      queues: live.queues,
      courts: live.courts,
      upNext: live.upNext,
      matchHistory: historyUnchanged ? matchHistory : live.matchHistory,
      finishedMatchCount: live.finishedMatchCount,
      pendingPayments: pendingPayments,
      challengeCourt: live.challengeCourt,
    );
  }

  List<QueuePlayer> get allQueuedPlayers => queues.values
      .expand((players) => players)
      .toList();

  UpNextGroup? get primaryUpNext =>
      upNext.isNotEmpty ? upNext.first : null;

  UpNextGroup? get secondaryUpNext =>
      upNext.length > 1 ? upNext[1] : null;

  Set<int> get nextUpPlayerIds => primaryUpNext == null
      ? {}
      : primaryUpNext!.players.map((p) => p.id).toSet();

  Set<int> get onDeckPlayerIds => secondaryUpNext == null
      ? {}
      : secondaryUpNext!.players.map((p) => p.id).toSet();

  bool canAssignNextForCourt(CourtInfo court) {
    if (court.status != 'available') return false;

    if (court.isChallengeCourt) {
      if (!challengeCourt.isOpen) return false;
      return court.canAssignInitial || court.canNextChallenger;
    }

    if (session.matchMode == 'skill_courts' && court.skillBracket != null) {
      for (final group in upNext) {
        if (group.queueType == court.skillBracket) return group.ready;
      }
      return false;
    }

    return primaryUpNext?.ready ?? false;
  }

  int get groupSize => session.playFormat == 'singles' ? 2 : 4;

  Set<String> get rosterPlayerNames {
    final names = <String>{};
    for (final player in allQueuedPlayers) {
      names.add(player.name);
    }
    for (final court in courts) {
      final match = court.match;
      if (match == null) continue;
      for (final player in [
        match.teamA['player1'],
        match.teamA['player2'],
        match.teamB['player1'],
        match.teamB['player2'],
      ]) {
        if (player != null) names.add(player.name);
      }
    }
    return names;
  }
}

class SessionReport {
  SessionReport({
    required this.sessionId,
    required this.sessionName,
    required this.totalMatches,
    required this.durationMinutes,
    required this.courtUtilizationPercent,
    required this.winnersQueueSize,
    required this.losersQueueSize,
    required this.playerSummaries,
    this.startedAt,
    this.endedAt,
    this.avgMatchDurationMinutes = 0,
    this.matchSummaries = const [],
  });

  final int sessionId;
  final String sessionName;
  final int totalMatches;
  final int durationMinutes;
  final double courtUtilizationPercent;
  final int winnersQueueSize;
  final int losersQueueSize;
  final List<Map<String, dynamic>> playerSummaries;
  final String? startedAt;
  final String? endedAt;
  final int avgMatchDurationMinutes;
  final List<Map<String, dynamic>> matchSummaries;

  factory SessionReport.fromJson(Map<String, dynamic> json) {
    final distribution = json['queueDistribution'];
    final distributionMap = distribution is Map
        ? Map<String, dynamic>.from(distribution)
        : <String, dynamic>{};
    return SessionReport(
      sessionId: json['sessionId'] as int,
      sessionName: json['sessionName'] as String,
      totalMatches: json['totalMatches'] as int? ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.round() ?? 0,
      courtUtilizationPercent:
          (json['courtUtilizationPercent'] as num?)?.toDouble() ?? 0,
      winnersQueueSize: distributionMap['winnersQueueSize'] as int? ?? 0,
      losersQueueSize: distributionMap['losersQueueSize'] as int? ?? 0,
      playerSummaries: (json['playerSummaries'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      avgMatchDurationMinutes:
          (json['avgMatchDurationMinutes'] as num?)?.round() ?? 0,
      matchSummaries: (json['matchSummaries'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

class SessionPreset {
  SessionPreset({
    required this.id,
    required this.name,
    required this.matchMode,
    required this.matchModeLabel,
    required this.playFormat,
    required this.courtCount,
    required this.autoAssignEnabled,
  });

  final int id;
  final String name;
  final String matchMode;
  final String matchModeLabel;
  final String playFormat;
  final int courtCount;
  final bool autoAssignEnabled;

  factory SessionPreset.fromJson(Map<String, dynamic> json) {
    return SessionPreset(
      id: json['id'] as int,
      name: json['name'] as String,
      matchMode: json['matchMode'] as String,
      matchModeLabel: json['matchModeLabel'] as String? ?? '',
      playFormat: json['playFormat'] as String? ?? 'doubles',
      courtCount: json['courtCount'] as int? ?? 4,
      autoAssignEnabled: json['autoAssignEnabled'] as bool? ?? false,
    );
  }
}

class SessionHistorySummary {
  SessionHistorySummary({
    required this.id,
    required this.name,
    required this.status,
    required this.matchMode,
    required this.matchModeLabel,
    required this.playFormat,
    required this.courtCount,
    required this.totalMatches,
    required this.playerCount,
    this.startedAt,
    this.endedAt,
    this.calendarDate,
  });

  final int id;
  final String name;
  final String status;
  final String matchMode;
  final String matchModeLabel;
  final String playFormat;
  final int courtCount;
  final int totalMatches;
  final int playerCount;
  final String? startedAt;
  final String? endedAt;
  final String? calendarDate;

  factory SessionHistorySummary.fromJson(Map<String, dynamic> json) {
    return SessionHistorySummary(
      id: json['id'] as int,
      name: json['name'] as String,
      status: json['status'] as String,
      matchMode: json['matchMode'] as String? ?? 'auto_balanced',
      matchModeLabel: json['matchModeLabel'] as String? ?? 'Auto-Balanced',
      playFormat: json['playFormat'] as String,
      courtCount: json['courtCount'] as int,
      totalMatches: json['totalMatches'] as int? ?? 0,
      playerCount: json['playerCount'] as int? ?? 0,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      calendarDate: json['calendarDate'] as String?,
    );
  }
}

class SessionHistoryPlayer {
  SessionHistoryPlayer({
    required this.id,
    required this.name,
    required this.wins,
    required this.losses,
    this.skillLevel,
    this.gender,
  });

  final int id;
  final String name;
  final int wins;
  final int losses;
  final String? skillLevel;
  final String? gender;

  factory SessionHistoryPlayer.fromJson(Map<String, dynamic> json) {
    return SessionHistoryPlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      skillLevel: json['skillLevel'] as String?,
      gender: json['gender'] as String?,
    );
  }
}

class SessionHistoryDetail {
  SessionHistoryDetail({
    required this.session,
    required this.report,
    required this.matches,
    required this.players,
  });

  final SessionHistorySummary session;
  final SessionReport report;
  final List<MatchInfo> matches;
  final List<SessionHistoryPlayer> players;

  factory SessionHistoryDetail.fromJson(Map<String, dynamic> json) {
    return SessionHistoryDetail(
      session: SessionHistorySummary.fromJson(
        json['session'] as Map<String, dynamic>,
      ),
      report: SessionReport.fromJson(json['report'] as Map<String, dynamic>),
      matches: (json['matches'] as List<dynamic>? ?? [])
          .map((e) => MatchInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      players: (json['players'] as List<dynamic>? ?? [])
          .map((e) => SessionHistoryPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ClubPlayerInfo {
  ClubPlayerInfo({
    required this.id,
    required this.name,
    required this.skillLevel,
    required this.gender,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.winRate,
    required this.sessionMatches,
    required this.sessionWins,
    required this.sessionLosses,
    required this.sessionWinRate,
    required this.inCurrentSession,
    this.isGuest = false,
  });

  final int id;
  final String name;
  final bool isGuest;
  final String skillLevel;
  final String gender;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final double winRate;
  final int sessionMatches;
  final int sessionWins;
  final int sessionLosses;
  final double sessionWinRate;
  final bool inCurrentSession;

  factory ClubPlayerInfo.fromJson(Map<String, dynamic> json) {
    return ClubPlayerInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      skillLevel: json['skillLevel'] as String? ?? 'beginner',
      gender: json['gender'] as String? ?? 'male',
      totalMatches: json['totalMatches'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      totalLosses: json['totalLosses'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      sessionMatches: json['sessionMatches'] as int? ?? 0,
      sessionWins: json['sessionWins'] as int? ?? 0,
      sessionLosses: json['sessionLosses'] as int? ?? 0,
      sessionWinRate: (json['sessionWinRate'] as num?)?.toDouble() ?? 0,
      inCurrentSession: json['inCurrentSession'] as bool? ?? false,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  ClubPlayerInfo copyWith({
    String? skillLevel,
    String? gender,
    int? totalMatches,
    int? totalWins,
    int? totalLosses,
    double? winRate,
    int? sessionMatches,
    int? sessionWins,
    int? sessionLosses,
    double? sessionWinRate,
    bool? inCurrentSession,
  }) {
    return ClubPlayerInfo(
      id: id,
      name: name,
      skillLevel: skillLevel ?? this.skillLevel,
      gender: gender ?? this.gender,
      totalMatches: totalMatches ?? this.totalMatches,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      winRate: winRate ?? this.winRate,
      sessionMatches: sessionMatches ?? this.sessionMatches,
      sessionWins: sessionWins ?? this.sessionWins,
      sessionLosses: sessionLosses ?? this.sessionLosses,
      sessionWinRate: sessionWinRate ?? this.sessionWinRate,
      inCurrentSession: inCurrentSession ?? this.inCurrentSession,
    );
  }
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.wins,
    required this.losses,
    required this.matches,
    required this.winRate,
    this.gender,
    this.skillLevel,
    this.pointDifferential = 0,
    this.avgMargin = 0,
  });

  final int rank;
  final String name;
  final int wins;
  final int losses;
  final int matches;
  final double winRate;
  final String? gender;
  final String? skillLevel;
  final int pointDifferential;
  final double avgMargin;

  LeaderboardEntry copyWith({int? rank}) {
    return LeaderboardEntry(
      rank: rank ?? this.rank,
      name: name,
      wins: wins,
      losses: losses,
      matches: matches,
      winRate: winRate,
      gender: gender,
      skillLevel: skillLevel,
      pointDifferential: pointDifferential,
      avgMargin: avgMargin,
    );
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      name: json['name'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      matches: json['matches'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      gender: json['gender'] as String?,
      skillLevel: json['skillLevel'] as String?,
      pointDifferential: json['pointDifferential'] as int? ?? 0,
      avgMargin: (json['avgMargin'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PlayerProfileSession {
  PlayerProfileSession({
    required this.sessionId,
    required this.sessionName,
    required this.matchModeLabel,
    required this.wins,
    required this.losses,
    required this.matches,
    required this.winRate,
    required this.pointDifferential,
    required this.avgMargin,
    this.startedAt,
  });

  final int sessionId;
  final String sessionName;
  final String matchModeLabel;
  final int wins;
  final int losses;
  final int matches;
  final double winRate;
  final int pointDifferential;
  final double avgMargin;
  final String? startedAt;

  factory PlayerProfileSession.fromJson(Map<String, dynamic> json) {
    return PlayerProfileSession(
      sessionId: json['sessionId'] as int,
      sessionName: json['sessionName'] as String? ?? 'Session',
      matchModeLabel: json['matchModeLabel'] as String? ?? '',
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      matches: json['matches'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      pointDifferential: json['pointDifferential'] as int? ?? 0,
      avgMargin: (json['avgMargin'] as num?)?.toDouble() ?? 0,
      startedAt: json['startedAt'] as String?,
    );
  }
}

class PlayerProfilePartner {
  PlayerProfilePartner({
    required this.name,
    required this.matchesTogether,
    required this.winsTogether,
  });

  final String name;
  final int matchesTogether;
  final int winsTogether;

  factory PlayerProfilePartner.fromJson(Map<String, dynamic> json) {
    return PlayerProfilePartner(
      name: json['name'] as String,
      matchesTogether: json['matchesTogether'] as int? ?? 0,
      winsTogether: json['winsTogether'] as int? ?? 0,
    );
  }
}

class PlayerProfileTrendPoint {
  PlayerProfileTrendPoint({
    required this.label,
    required this.winRate,
    required this.matches,
    this.date,
  });

  final String label;
  final double winRate;
  final int matches;
  final String? date;

  factory PlayerProfileTrendPoint.fromJson(Map<String, dynamic> json) {
    return PlayerProfileTrendPoint(
      label: json['label'] as String? ?? 'Session',
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      matches: json['matches'] as int? ?? 0,
      date: json['date'] as String?,
    );
  }
}

class PlayerProfileDetail {
  PlayerProfileDetail({
    required this.id,
    required this.name,
    required this.skillLevel,
    required this.gender,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.winRate,
    required this.pointDifferential,
    required this.avgMargin,
    required this.sessionMatches,
    required this.sessionWins,
    required this.sessionLosses,
    required this.sessionWinRate,
    required this.inCurrentSession,
    required this.sessionHistory,
    required this.bestPartners,
    required this.winRateTrend,
    this.preferredModeLabel,
  });

  final int id;
  final String name;
  final String skillLevel;
  final String gender;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final double winRate;
  final int pointDifferential;
  final double avgMargin;
  final int sessionMatches;
  final int sessionWins;
  final int sessionLosses;
  final double sessionWinRate;
  final bool inCurrentSession;
  final String? preferredModeLabel;
  final List<PlayerProfileSession> sessionHistory;
  final List<PlayerProfilePartner> bestPartners;
  final List<PlayerProfileTrendPoint> winRateTrend;

  factory PlayerProfileDetail.fromJson(Map<String, dynamic> json) {
    return PlayerProfileDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      skillLevel: json['skillLevel'] as String? ?? 'beginner',
      gender: json['gender'] as String? ?? 'male',
      totalMatches: json['totalMatches'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      totalLosses: json['totalLosses'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      pointDifferential: json['pointDifferential'] as int? ?? 0,
      avgMargin: (json['avgMargin'] as num?)?.toDouble() ?? 0,
      sessionMatches: json['sessionMatches'] as int? ?? 0,
      sessionWins: json['sessionWins'] as int? ?? 0,
      sessionLosses: json['sessionLosses'] as int? ?? 0,
      sessionWinRate: (json['sessionWinRate'] as num?)?.toDouble() ?? 0,
      inCurrentSession: json['inCurrentSession'] as bool? ?? false,
      preferredModeLabel: json['preferredModeLabel'] as String?,
      sessionHistory: (json['sessionHistory'] as List<dynamic>? ?? [])
          .map((e) => PlayerProfileSession.fromJson(e as Map<String, dynamic>))
          .toList(),
      bestPartners: (json['bestPartners'] as List<dynamic>? ?? [])
          .map((e) => PlayerProfilePartner.fromJson(e as Map<String, dynamic>))
          .toList(),
      winRateTrend: (json['winRateTrend'] as List<dynamic>? ?? [])
          .map((e) => PlayerProfileTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CheckInSessionInfo {
  CheckInSessionInfo({
    required this.sessionId,
    required this.sessionName,
    required this.matchMode,
    required this.matchModeLabel,
    required this.playFormat,
    required this.requiresSkillLevel,
    required this.requiresGender,
    this.requirePayment = false,
    this.sessionFeeCents = 0,
  });

  final int sessionId;
  final String sessionName;
  final String matchMode;
  final String matchModeLabel;
  final String playFormat;
  final bool requiresSkillLevel;
  final bool requiresGender;
  final bool requirePayment;
  final int sessionFeeCents;

  factory CheckInSessionInfo.fromJson(Map<String, dynamic> json) {
    return CheckInSessionInfo(
      sessionId: json['sessionId'] as int,
      sessionName: json['sessionName'] as String,
      matchMode: json['matchMode'] as String? ?? 'auto_balanced',
      matchModeLabel: json['matchModeLabel'] as String? ?? 'Open Play',
      playFormat: json['playFormat'] as String? ?? 'doubles',
      requiresSkillLevel: json['requiresSkillLevel'] as bool? ?? false,
      requiresGender: json['requiresGender'] as bool? ?? false,
      requirePayment: json['requirePayment'] as bool? ?? false,
      sessionFeeCents: json['sessionFeeCents'] as int? ?? 0,
    );
  }
}

class SessionRosterPlayer {
  SessionRosterPlayer({
    required this.playerId,
    required this.name,
    this.clubPlayerId,
    this.isGuest = false,
    this.availability = 'active',
  });

  final int playerId;
  final int? clubPlayerId;
  final String name;
  final bool isGuest;
  final String availability;

  factory SessionRosterPlayer.fromJson(Map<String, dynamic> json) {
    return SessionRosterPlayer(
      playerId: json['playerId'] as int,
      clubPlayerId: json['clubPlayerId'] as int?,
      name: json['name'] as String,
      isGuest: json['isGuest'] as bool? ?? false,
      availability: json['availability'] as String? ?? 'active',
    );
  }
}

class CheckInPlayerStatus {
  CheckInPlayerStatus({
    required this.inSession,
    required this.status,
    required this.message,
    this.courtNumber,
    this.queueLabel,
    this.position,
    this.playerId,
    this.clubPlayerId,
    this.playerName,
    this.isGuest = false,
    this.playersAhead,
    this.groupsAhead,
    this.elapsedSeconds,
    this.sessionWins,
    this.sessionLosses,
    this.sessionFeeCents,
    this.paymentStatus,
  });

  final bool inSession;
  final String status;
  final String message;
  final int? courtNumber;
  final String? queueLabel;
  final int? position;
  final int? playerId;
  final int? clubPlayerId;
  final String? playerName;
  final bool isGuest;
  final int? playersAhead;
  final int? groupsAhead;
  final int? elapsedSeconds;
  final int? sessionWins;
  final int? sessionLosses;
  final int? sessionFeeCents;
  final String? paymentStatus;

  factory CheckInPlayerStatus.fromJson(Map<String, dynamic> json) {
    return CheckInPlayerStatus(
      inSession: json['inSession'] as bool? ?? false,
      status: json['status'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      courtNumber: json['courtNumber'] as int?,
      queueLabel: json['queueLabel'] as String?,
      position: json['position'] as int?,
      playerId: json['playerId'] as int?,
      clubPlayerId: json['clubPlayerId'] as int?,
      playerName: json['playerName'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
      playersAhead: (json['playersAhead'] as num?)?.round(),
      groupsAhead: (json['groupsAhead'] as num?)?.round(),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.round(),
      sessionWins: (json['sessionWins'] as num?)?.round(),
      sessionLosses: (json['sessionLosses'] as num?)?.round(),
      sessionFeeCents: json['sessionFeeCents'] as int?,
      paymentStatus: json['paymentStatus'] as String?,
    );
  }
}

class RevenueSummary {
  RevenueSummary({
    required this.totalRevenueCents,
    required this.completedCount,
    required this.waivedCount,
    required this.paymentCount,
    required this.byMethod,
    required this.bySession,
    required this.recent,
    this.from,
    this.to,
    this.sessionId,
  });

  final int totalRevenueCents;
  final int completedCount;
  final int waivedCount;
  final int paymentCount;
  final List<RevenueMethodBreakdown> byMethod;
  final List<RevenueSessionBreakdown> bySession;
  final List<RevenuePaymentRow> recent;
  final String? from;
  final String? to;
  final int? sessionId;

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    return RevenueSummary(
      totalRevenueCents: json['totalRevenueCents'] as int? ?? 0,
      completedCount: json['completedCount'] as int? ?? 0,
      waivedCount: json['waivedCount'] as int? ?? 0,
      paymentCount: json['paymentCount'] as int? ?? 0,
      byMethod: (json['byMethod'] as List<dynamic>? ?? [])
          .map((e) => RevenueMethodBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      bySession: (json['bySession'] as List<dynamic>? ?? [])
          .map((e) => RevenueSessionBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent: (json['recent'] as List<dynamic>? ?? [])
          .map((e) => RevenuePaymentRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      from: json['from'] as String?,
      to: json['to'] as String?,
      sessionId: json['sessionId'] as int?,
    );
  }
}

class RevenueMethodBreakdown {
  RevenueMethodBreakdown({
    required this.method,
    required this.count,
    required this.totalCents,
  });

  final String method;
  final int count;
  final int totalCents;

  factory RevenueMethodBreakdown.fromJson(Map<String, dynamic> json) {
    return RevenueMethodBreakdown(
      method: json['method'] as String? ?? 'cash',
      count: json['count'] as int? ?? 0,
      totalCents: json['totalCents'] as int? ?? 0,
    );
  }
}

class RevenueSessionBreakdown {
  RevenueSessionBreakdown({
    required this.sessionId,
    this.sessionName,
    required this.count,
    required this.totalCents,
  });

  final int sessionId;
  final String? sessionName;
  final int count;
  final int totalCents;

  factory RevenueSessionBreakdown.fromJson(Map<String, dynamic> json) {
    return RevenueSessionBreakdown(
      sessionId: json['sessionId'] as int,
      sessionName: json['sessionName'] as String?,
      count: json['count'] as int? ?? 0,
      totalCents: json['totalCents'] as int? ?? 0,
    );
  }
}

class RevenuePaymentRow {
  RevenuePaymentRow({
    required this.id,
    required this.sessionId,
    this.sessionName,
    required this.clubPlayerId,
    this.playerName,
    required this.amountCents,
    required this.method,
    required this.status,
    this.recordedAt,
    this.notes,
  });

  final int id;
  final int sessionId;
  final String? sessionName;
  final int clubPlayerId;
  final String? playerName;
  final int amountCents;
  final String method;
  final String status;
  final String? recordedAt;
  final String? notes;

  factory RevenuePaymentRow.fromJson(Map<String, dynamic> json) {
    return RevenuePaymentRow(
      id: json['id'] as int,
      sessionId: json['sessionId'] as int,
      sessionName: json['sessionName'] as String?,
      clubPlayerId: json['clubPlayerId'] as int,
      playerName: json['playerName'] as String?,
      amountCents: json['amountCents'] as int? ?? 0,
      method: json['method'] as String? ?? 'cash',
      status: json['status'] as String? ?? 'completed',
      recordedAt: json['recordedAt'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
