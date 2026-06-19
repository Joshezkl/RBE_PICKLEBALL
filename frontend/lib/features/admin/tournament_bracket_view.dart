import 'package:flutter/material.dart';

import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_responsive.dart';
import '../../core/tournament_models.dart';

enum TournamentPillVariant { leader, standing, matchTeam, advance }

/// Soft, readable palette for the tournament flow (groups + bracket).
class TournamentFlowStyle {
  TournamentFlowStyle(BuildContext context)
      : _c = context.rpc,
        isDark = Theme.of(context).brightness == Brightness.dark {
    panelBackground = isDark
        ? Color.alphaBlend(
            _c.primary.withValues(alpha: 0.06),
            _c.elevatedSurface,
          )
        : Color.alphaBlend(
            _c.primary.withValues(alpha: 0.04),
            _c.surface,
          );
    panelBorder = _c.border.withValues(alpha: isDark ? 0.9 : 1);

    connectorColor = _c.primary.withValues(alpha: isDark ? 0.28 : 0.32);
    sectionLabel = _c.textMuted;
    columnTitle = _c.text.withValues(alpha: 0.85);
    recordText = _c.textMuted;
    scoreText = _c.primary.withValues(alpha: isDark ? 0.9 : 0.85);
  }

  final RpcPalette _c;
  final bool isDark;

  late final Color panelBackground;
  late final Color panelBorder;
  late final Color connectorColor;
  late final Color sectionLabel;
  late final Color columnTitle;
  late final Color recordText;
  late final Color scoreText;

  Color pillBackground(TournamentPillVariant variant, {bool isWinner = false}) {
    return switch (variant) {
      TournamentPillVariant.leader => isDark
          ? _c.primary.withValues(alpha: 0.16)
          : _c.primaryLight.withValues(alpha: 0.55),
      TournamentPillVariant.standing => isDark
          ? _c.surfaceHover.withValues(alpha: 0.85)
          : _c.surface,
      TournamentPillVariant.matchTeam => isWinner
          ? (isDark
              ? _c.primary.withValues(alpha: 0.14)
              : _c.primaryLight.withValues(alpha: 0.45))
          : (isDark ? _c.surface : _c.surface),
      TournamentPillVariant.advance => isWinner
          ? (isDark
              ? _c.primary.withValues(alpha: 0.18)
              : _c.primaryLight.withValues(alpha: 0.5))
          : (isDark ? _c.surfaceHover : _c.surface),
    };
  }

  Color pillBorder(TournamentPillVariant variant, {bool isWinner = false}) {
    return switch (variant) {
      TournamentPillVariant.leader =>
        _c.primary.withValues(alpha: 0.38),
      TournamentPillVariant.standing => _c.border.withValues(alpha: 0.85),
      TournamentPillVariant.matchTeam => isWinner
          ? _c.primary.withValues(alpha: 0.42)
          : _c.border.withValues(alpha: 0.8),
      TournamentPillVariant.advance => isWinner
          ? _c.primary.withValues(alpha: 0.45)
          : _c.border.withValues(alpha: 0.85),
    };
  }

  Color pillText(TournamentPillVariant variant) => _c.text;
}

/// Unified tournament flow: round-robin group columns + playoff bracket.
class TournamentFlowView extends StatelessWidget {
  const TournamentFlowView({
    super.key,
    required this.groups,
    required this.categoryPhase,
    this.bracket,
    this.thirdPlaceMatch,
    required this.onScoreMatch,
  });

  final List<TournamentGroupState> groups;
  final String categoryPhase;
  final TournamentBracket? bracket;
  final TournamentMatchInfo? thirdPlaceMatch;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;

  @override
  Widget build(BuildContext context) {
    final hasGroups = groups.isNotEmpty;
    final regularGroups =
        groups.where((group) => group.key != 'final').toList();
    final finalGroups =
        groups.where((group) => group.key == 'final').toList();
    final hasFinalGroup = finalGroups.isNotEmpty;
    final isFinalRoundRobin = categoryPhase == 'final_round_robin';
    final hasBracket = !isFinalRoundRobin &&
        bracket != null &&
        bracket!.rounds.isNotEmpty;
    final hasThirdPlace =
        !isFinalRoundRobin && thirdPlaceMatch != null;
    if (!hasGroups && !hasBracket && !hasThirdPlace) {
      return const SizedBox.shrink();
    }

    return TournamentBracketPanel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (regularGroups.isNotEmpty) ...[
              TournamentGroupColumnsView(
                groups: regularGroups,
                onScoreMatch: onScoreMatch,
              ),
              if (hasFinalGroup)
                const _FlowStageDivider(label: 'Final Round Robin'),
              if (!hasFinalGroup && (hasBracket || hasThirdPlace))
                const _FlowStageDivider(label: 'Playoffs'),
            ],
            if (hasFinalGroup) ...[
              TournamentGroupColumnsView(
                groups: finalGroups,
                onScoreMatch: onScoreMatch,
              ),
            ],
            if (hasBracket) ...[
              if (regularGroups.isNotEmpty || hasFinalGroup)
                const _FlowStageDivider(label: 'Playoffs'),
              TournamentBracketView(
                bracket: bracket!,
                thirdPlaceMatch: thirdPlaceMatch,
                onScoreMatch: onScoreMatch,
                embedded: true,
              ),
            ] else if (hasThirdPlace)
              _ThirdPlaceOnlyBracketView(
                match: thirdPlaceMatch!,
                onScoreMatch: onScoreMatch,
              ),
          ],
        ),
      ),
    );
  }
}

class TournamentGroupColumnsView extends StatelessWidget {
  const TournamentGroupColumnsView({
    super.key,
    required this.groups,
    required this.onScoreMatch,
  });

  final List<TournamentGroupState> groups;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;

  static const _columnWidth = 168.0;
  static const _columnGap = 20.0;

  @override
  Widget build(BuildContext context) {
    final style = TournamentFlowStyle(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(width: _columnGap),
          SizedBox(
            width: _columnWidth,
            child: _GroupColumn(
              group: groups[i],
              onScoreMatch: onScoreMatch,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupColumn extends StatelessWidget {
  const _GroupColumn({
    required this.group,
    required this.onScoreMatch,
    required this.style,
  });

  final TournamentGroupState group;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;
  final TournamentFlowStyle style;

  @override
  Widget build(BuildContext context) {
    final pending = group.matches.where((m) => m.canScore).toList()
      ..sort((a, b) {
        if (a.isOnCourt != b.isOnCourt) {
          return a.isOnCourt ? -1 : 1;
        }
        if (a.courtNumber != null && b.courtNumber != null) {
          return a.courtNumber!.compareTo(b.courtNumber!);
        }
        return a.matchIndex.compareTo(b.matchIndex);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          group.label,
          textAlign: TextAlign.center,
          style: RpcTypography.caption(context).copyWith(
            fontWeight: FontWeight.w600,
            color: style.columnTitle,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        if (group.standings.isNotEmpty) ...[
          ...group.standings.map(
            (row) {
              final playerMatches = _matchesForTeam(group.matches, row.teamId);
              final hasHistory = playerMatches.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: TournamentBracketPill(
                  style: style,
                  label: '#${row.rank} ${row.displayName}',
                  trailingText: _standingTrailingText(row),
                  variant: row.rank == 1
                      ? TournamentPillVariant.leader
                      : TournamentPillVariant.standing,
                  compact: true,
                  isActionable: hasHistory,
                  onTap: hasHistory
                      ? () => _showPlayerMatchHistoryDialog(
                            context,
                            player: row,
                            groupLabel: group.label,
                            matches: playerMatches,
                            style: style,
                          )
                      : null,
                ),
              );
            },
          ),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'To score',
            style: RpcTypography.caption(context)
                .copyWith(color: style.sectionLabel),
          ),
          const SizedBox(height: 6),
          ...pending.map(
            (match) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MatchPairStack(
                match: match,
                style: style,
                onScore: () => onScoreMatch(match),
              ),
            ),
          ),
        ],
        if (group.standings.isEmpty && group.matches.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Assigned at start',
            textAlign: TextAlign.center,
            style: RpcTypography.caption(context)
                .copyWith(color: context.rpc.textMuted),
          ),
        ],
      ],
    );
  }
}

String _standingTrailingText(TournamentStandingRow row) {
  final record = '${row.wins}-${row.losses}';
  final diff = row.pointDifferential;
  final diffLabel = '${diff >= 0 ? '+' : ''}$diff';
  return '$record · $diffLabel';
}

List<TournamentMatchInfo> _matchesForTeam(
  List<TournamentMatchInfo> matches,
  int teamId,
) {
  return matches
      .where(
        (match) => match.teamA?.id == teamId || match.teamB?.id == teamId,
      )
      .toList()
    ..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
}

Future<void> _showPlayerMatchHistoryDialog(
  BuildContext context, {
  required TournamentStandingRow player,
  required String groupLabel,
  required List<TournamentMatchInfo> matches,
  required TournamentFlowStyle style,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PlayerMatchHistoryDialog(
      player: player,
      groupLabel: groupLabel,
      matches: matches,
      style: style,
    ),
  );
}

class _PlayerMatchHistoryDialog extends StatelessWidget {
  const _PlayerMatchHistoryDialog({
    required this.player,
    required this.groupLabel,
    required this.matches,
    required this.style,
  });

  final TournamentStandingRow player;
  final String groupLabel;
  final List<TournamentMatchInfo> matches;
  final TournamentFlowStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final finished = matches.where((match) => match.isFinished).toList();
    final upcoming = matches.where((match) => !match.isFinished).toList();

    return Dialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      backgroundColor: c.elevatedSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(
          context,
          maxWidth: 360,
          maxHeightFraction: 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                groupLabel,
                style: RpcTypography.caption(context).copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                player.displayName,
                style: RpcTypography.headline(context).copyWith(
                  fontSize: RpcTypeScale.title,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '#${player.rank} · ${_standingTrailingText(player)}',
                style: RpcTypography.body(context).copyWith(
                  color: c.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: finished.isEmpty && upcoming.isEmpty
                    ? Center(
                        child: Text(
                          'No matches yet',
                          style: RpcTypography.body(context).copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (finished.isNotEmpty) ...[
                              Text(
                                'Match history (${finished.length})',
                                style: RpcTypography.caption(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: style.sectionLabel,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...finished.map(
                                (match) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MatchPairStack(
                                    match: match,
                                    style: style,
                                    onScore: null,
                                  ),
                                ),
                              ),
                            ],
                            if (upcoming.isNotEmpty) ...[
                              if (finished.isNotEmpty)
                                const SizedBox(height: 4),
                              Text(
                                'Upcoming (${upcoming.length})',
                                style: RpcTypography.caption(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: style.sectionLabel,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...upcoming.map(
                                (match) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _MatchPairStack(
                                    match: match,
                                    style: style,
                                    onScore: null,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchPairStack extends StatelessWidget {
  const _MatchPairStack({
    required this.match,
    required this.style,
    this.onScore,
  });

  final TournamentMatchInfo match;
  final TournamentFlowStyle style;
  final VoidCallback? onScore;

  @override
  Widget build(BuildContext context) {
    final canScore = onScore != null && match.canScore;
    final teamAWins =
        match.isFinished && match.winnerTeamId == match.teamA?.id;
    final teamBWins =
        match.isFinished && match.winnerTeamId == match.teamB?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (match.isAssignedToCourt && match.courtNumber != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: style.columnTitle.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: style.columnTitle.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'Court ${match.courtNumber} · ready to start',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RpcTypography.caption(context).copyWith(
                color: style.columnTitle,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          )
        else if (match.isOnCourt && match.courtNumber != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: style.columnTitle.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: style.columnTitle.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'Court ${match.courtNumber} · '
              '${match.teamA?.displayName ?? 'TBD'} vs '
              '${match.teamB?.displayName ?? 'TBD'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RpcTypography.caption(context).copyWith(
                color: style.columnTitle,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        TournamentBracketPill(
          style: style,
          label: match.teamA?.displayName ?? 'TBD',
          score: match.scoreA,
          variant: TournamentPillVariant.matchTeam,
          isWinner: teamAWins,
          isActionable: canScore,
          onTap: canScore ? onScore : null,
        ),
        const SizedBox(height: TournamentBracketMetrics.slotGap),
        TournamentBracketPill(
          style: style,
          label: match.teamB?.displayName ?? 'TBD',
          score: match.scoreB,
          variant: TournamentPillVariant.matchTeam,
          isWinner: teamBWins,
          isActionable: canScore,
          onTap: canScore ? onScore : null,
        ),
      ],
    );
  }
}

class TournamentBracketView extends StatelessWidget {
  const TournamentBracketView({
    super.key,
    required this.bracket,
    this.thirdPlaceMatch,
    required this.onScoreMatch,
    this.embedded = false,
  });

  final TournamentBracket bracket;
  final TournamentMatchInfo? thirdPlaceMatch;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final style = TournamentFlowStyle(context);
    final rounds = bracket.rounds;
    if (rounds.isEmpty) return const SizedBox.shrink();

    final firstRound = rounds.first;
    final matchCount = firstRound.matches.length;
    final columnCount = rounds.length + 1;
    final bracketHeight = TournamentBracketMetrics.bracketHeight(matchCount);
    final totalWidth = TournamentBracketMetrics.totalWidth(columnCount);
    final showThirdPlace =
        thirdPlaceMatch != null && matchCount >= 2;
    final thirdLaneHeight = showThirdPlace ? 100.0 : 0.0;
    final thirdGap = showThirdPlace ? RpcSpacing.md : 0.0;
    final combinedHeight = bracketHeight + thirdGap + thirdLaneHeight;

    final mainBracket = SizedBox(
      width: totalWidth,
      height: combinedHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showThirdPlace)
            Positioned.fill(
              child: CustomPaint(
                painter: _ThirdPlaceConnectorPainter(
                  semiMatchCount: matchCount,
                  bracketHeight: bracketHeight,
                  gapHeight: thirdGap,
                  laneHeight: thirdLaneHeight,
                  color: style.connectorColor,
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bracketHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(totalWidth, bracketHeight),
                  painter: _BracketTreePainter(
                    rounds: rounds,
                    bracketHeight: bracketHeight,
                    color: style.connectorColor,
                  ),
                ),
                for (var column = 0; column < columnCount; column++)
                  ..._buildColumnPills(
                    context,
                    style: style,
                    column: column,
                    rounds: rounds,
                    matchCount: matchCount,
                    bracketHeight: bracketHeight,
                  ),
              ],
            ),
          ),
          if (showThirdPlace)
            Positioned(
              top: bracketHeight + thirdGap,
              left: 0,
              right: 0,
              height: thirdLaneHeight,
              child: _ThirdPlaceBracketLane(
                match: thirdPlaceMatch!,
                style: style,
                onScoreMatch: onScoreMatch,
              ),
            ),
        ],
      ),
    );

    final content = mainBracket;

    if (embedded) return content;

    return TournamentBracketPanel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: content,
      ),
    );
  }

  List<Widget> _buildColumnPills(
    BuildContext context, {
    required TournamentFlowStyle style,
    required int column,
    required List<TournamentBracketRound> rounds,
    required int matchCount,
    required double bracketHeight,
  }) {
    final left = 16.0 + column * (TournamentBracketMetrics.pillWidth +
        TournamentBracketMetrics.columnGap);

    if (column == 0) {
      return List.generate(matchCount, (matchIndex) {
        final match = rounds.first.matches[matchIndex];
        final groupTop = _matchGroupTop(matchIndex, matchCount, bracketHeight);
        final pairHeight = (TournamentBracketMetrics.pillHeight * 2) +
            TournamentBracketMetrics.slotGap;

        return Positioned(
          left: left,
          top: groupTop,
          width: TournamentBracketMetrics.pillWidth,
          height: pairHeight,
          child: _MatchPairStack(
            match: match,
            style: style,
            onScore: match.canScore ? () => onScoreMatch(match) : null,
          ),
        );
      });
    }

    final round = rounds[column - 1];
    final slotCount = round.matches.length;
    final isFinalColumn = column == rounds.length;

    return List.generate(slotCount, (index) {
      final match = round.matches[index];
      final label = _winnerColumnLabel(match);
      final score = match.isFinished
          ? (match.winnerTeamId == match.teamA?.id ? match.scoreA : match.scoreB)
          : null;
      final pillTop = _slotTop(index, slotCount, bracketHeight) -
          (TournamentBracketMetrics.pillHeight / 2);
      final widgets = <Widget>[
        Positioned(
          left: left,
          top: pillTop,
          child: TournamentBracketPill(
            style: style,
            label: label,
            score: score,
            variant: TournamentPillVariant.advance,
            isWinner: match.isFinished,
            isActionable: match.canScore,
            onTap: match.canScore ? () => onScoreMatch(match) : null,
          ),
        ),
      ];

      if (isFinalColumn && slotCount == 1) {
        widgets.insert(
          0,
          Positioned(
            left: left,
            top: pillTop - 22,
            child: _PlacementBracketLabel(
              tier: match.isFinished
                  ? _PlacementLabelTier.champion
                  : _PlacementLabelTier.finalRound,
              style: style,
            ),
          ),
        );

        final runnerUp = _runnerUpName(match);
        if (runnerUp != null) {
          widgets.add(
            Positioned(
              left: left,
              top: pillTop + TournamentBracketMetrics.pillHeight + 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlacementBracketLabel(
                    tier: _PlacementLabelTier.second,
                    style: style,
                  ),
                  const SizedBox(height: 6),
                  TournamentBracketPill(
                    style: style,
                    label: runnerUp,
                    variant: TournamentPillVariant.standing,
                  ),
                ],
              ),
            ),
          );
        }
      }

      return widgets;
    }).expand((widgets) => widgets).toList();
  }

  String? _runnerUpName(TournamentMatchInfo match) {
    if (!match.isFinished || match.winnerTeamId == null) return null;
    final loser = match.winnerTeamId == match.teamA?.id
        ? match.teamB
        : match.teamA;
    return loser?.displayName;
  }

  String _winnerColumnLabel(TournamentMatchInfo match) {
    if (match.isFinished) {
      final winner = match.winnerTeamId == match.teamA?.id
          ? match.teamA
          : match.teamB;
      return winner?.displayName ?? 'TBD';
    }

    if (match.teamA != null && match.teamB != null) {
      return '${match.teamA!.displayName} vs ${match.teamB!.displayName}';
    }

    return match.teamA?.displayName ?? match.teamB?.displayName ?? 'TBD';
  }

  static double _slotTop(int index, int slotCount, double height) {
    return height * (2 * index + 1) / (2 * slotCount);
  }

  static double _matchGroupTop(
    int matchIndex,
    int matchCount,
    double height,
  ) {
    final groupHeight = (TournamentBracketMetrics.pillHeight * 2) +
        TournamentBracketMetrics.slotGap;
    final totalGroupsHeight =
        (groupHeight * matchCount) +
        (TournamentBracketMetrics.slotGap * (matchCount - 1));
    final topOffset = (height - totalGroupsHeight) / 2;
    return topOffset + (matchIndex * (groupHeight + TournamentBracketMetrics.slotGap));
  }
}

class _ThirdPlaceOnlyBracketView extends StatelessWidget {
  const _ThirdPlaceOnlyBracketView({
    required this.match,
    required this.onScoreMatch,
  });

  final TournamentMatchInfo match;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;

  @override
  Widget build(BuildContext context) {
    final style = TournamentFlowStyle(context);
    final width = TournamentBracketMetrics.pillWidth + 32;

    return SizedBox(
      width: width,
      child: _ThirdPlaceBracketLane(
        match: match,
        style: style,
        onScoreMatch: onScoreMatch,
      ),
    );
  }
}

enum _PlacementLabelTier { champion, second, third, finalRound }

class _PlacementBracketLabel extends StatelessWidget {
  const _PlacementBracketLabel({
    required this.tier,
    required this.style,
  });

  final _PlacementLabelTier tier;
  final TournamentFlowStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final (icon, color, text) = switch (tier) {
      _PlacementLabelTier.champion => (
          Icons.emoji_events_rounded,
          c.warning,
          'Champion',
        ),
      _PlacementLabelTier.second => (
          Icons.workspace_premium_rounded,
          c.textMuted,
          '2nd place',
        ),
      _PlacementLabelTier.third => (
          Icons.military_tech_rounded,
          c.accentOrange.withValues(alpha: 0.9),
          '3rd place',
        ),
      _PlacementLabelTier.finalRound => (
          Icons.emoji_events_outlined,
          c.primary.withValues(alpha: 0.85),
          'Final',
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: RpcTypography.caption(context).copyWith(
            color: style.sectionLabel,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _ThirdPlaceBracketLane extends StatelessWidget {
  const _ThirdPlaceBracketLane({
    required this.match,
    required this.style,
    required this.onScoreMatch,
  });

  final TournamentMatchInfo match;
  final TournamentFlowStyle style;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;

  @override
  Widget build(BuildContext context) {
    final pairHeight = (TournamentBracketMetrics.pillHeight * 2) +
        TournamentBracketMetrics.slotGap;
    const left = 16.0;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: _PlacementBracketLabel(
            tier: _PlacementLabelTier.third,
            style: style,
          ),
        ),
        Positioned(
          left: left,
          top: 24,
          width: TournamentBracketMetrics.pillWidth,
          height: pairHeight,
          child: _MatchPairStack(
            match: match,
            style: style,
            onScore: match.canScore ? () => onScoreMatch(match) : null,
          ),
        ),
      ],
    );
  }
}

class _ThirdPlaceConnectorPainter extends CustomPainter {
  _ThirdPlaceConnectorPainter({
    required this.semiMatchCount,
    required this.bracketHeight,
    required this.gapHeight,
    required this.laneHeight,
    required this.color,
  });

  final int semiMatchCount;
  final double bracketHeight;
  final double gapHeight;
  final double laneHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (semiMatchCount < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pillWidth = TournamentBracketMetrics.pillWidth;
    final pillHeight = TournamentBracketMetrics.pillHeight;
    final slotGap = TournamentBracketMetrics.slotGap;
    final sourceLeft = 16.0 + pillWidth;
    final pairCenterX = 16.0 + (pillWidth / 2);
    final pairTop = bracketHeight + gapHeight + 24;
    final mergeY = bracketHeight + (gapHeight / 2);

    for (var index = 0; index < semiMatchCount; index++) {
      final groupTop = TournamentBracketView._matchGroupTop(
        index,
        semiMatchCount,
        bracketHeight,
      );
      final groupHeight = (pillHeight * 2) + slotGap;
      final pairCenterY = groupTop + (groupHeight / 2);

      canvas.drawLine(
        Offset(sourceLeft, pairCenterY),
        Offset(sourceLeft, mergeY),
        paint,
      );
    }

    canvas.drawLine(
      Offset(sourceLeft, mergeY),
      Offset(pairCenterX, mergeY),
      paint,
    );
    canvas.drawLine(
      Offset(pairCenterX, mergeY),
      Offset(pairCenterX, pairTop),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThirdPlaceConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.semiMatchCount != semiMatchCount ||
        oldDelegate.bracketHeight != bracketHeight;
  }
}

class TournamentBracketMetrics {
  static const pillWidth = 148.0;
  static const pillHeight = 34.0;
  static const slotGap = 8.0;
  static const columnGap = 48.0;

  static double bracketHeight(int firstRoundMatchCount) {
    final groupHeight = (pillHeight * 2) + slotGap;
    return (groupHeight * firstRoundMatchCount) +
        (slotGap * (firstRoundMatchCount - 1)) +
        24;
  }

  static double totalWidth(int columnCount) {
    return (pillWidth * columnCount) + (columnGap * (columnCount - 1)) + 32;
  }
}

class TournamentBracketPanel extends StatelessWidget {
  const TournamentBracketPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = TournamentFlowStyle(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RpcSpacing.md,
        vertical: RpcSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: style.panelBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.panelBorder),
      ),
      child: child,
    );
  }
}

class TournamentBracketPill extends StatelessWidget {
  const TournamentBracketPill({
    super.key,
    required this.style,
    required this.label,
    this.score,
    this.trailingText,
    this.variant = TournamentPillVariant.standing,
    this.isWinner = false,
    this.isActionable = false,
    this.onTap,
    this.compact = false,
  });

  final TournamentFlowStyle style;
  final String label;
  final int? score;
  final String? trailingText;
  final TournamentPillVariant variant;
  final bool isWinner;
  final bool isActionable;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height =
        compact ? 30.0 : TournamentBracketMetrics.pillHeight;
    final fontSize = compact ? 11.0 : 12.0;
    final background = style.pillBackground(variant, isWinner: isWinner);
    final border = style.pillBorder(variant, isWinner: isWinner);
    final textColor = style.pillText(variant);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: TournamentBracketMetrics.pillWidth,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RpcTypography.body(context).copyWith(
                    color: textColor,
                    fontWeight:
                        isWinner ? FontWeight.w600 : FontWeight.w500,
                    fontSize: fontSize,
                  ),
                ),
              ),
              if (score != null)
                Text(
                  '$score',
                  style: RpcTypography.bodySemibold(context).copyWith(
                    color: style.scoreText,
                    fontSize: fontSize,
                  ),
                )
              else if (trailingText != null)
                Text(
                  trailingText!,
                  style: RpcTypography.bodySemibold(context).copyWith(
                    color: style.recordText,
                    fontSize: fontSize,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowStageDivider extends StatelessWidget {
  const _FlowStageDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = TournamentFlowStyle(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: 24,
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(
              Icons.arrow_forward_rounded,
              color: style.connectorColor,
              size: 18,
            ),
            const SizedBox(height: 6),
            RotatedBox(
              quarterTurns: 1,
              child: Text(
                label,
                style: RpcTypography.caption(context).copyWith(
                  color: style.sectionLabel,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketTreePainter extends CustomPainter {
  _BracketTreePainter({
    required this.rounds,
    required this.bracketHeight,
    required this.color,
  });

  final List<TournamentBracketRound> rounds;
  final double bracketHeight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final firstRound = rounds.first;
    final matchCount = firstRound.matches.length;
    final columnCount = rounds.length + 1;
    final pillWidth = TournamentBracketMetrics.pillWidth;
    final columnGap = TournamentBracketMetrics.columnGap;
    final pillHeight = TournamentBracketMetrics.pillHeight;
    final slotGap = TournamentBracketMetrics.slotGap;
    final groupHeight = (pillHeight * 2) + slotGap;

    for (var column = 0; column < columnCount - 1; column++) {
      final destCount = rounds[column].matches.length;
      final sourceLeft = 16.0 + column * (pillWidth + columnGap) + pillWidth;
      final destLeft = 16.0 + (column + 1) * (pillWidth + columnGap);
      final midX = sourceLeft + ((destLeft - sourceLeft) / 2);

      for (var dest = 0; dest < destCount; dest++) {
        double yA;
        double yB;
        final yDest = _centerY(dest, destCount);

        if (column == 0) {
          final totalGroupsHeight =
              (groupHeight * matchCount) + (slotGap * (matchCount - 1));
          final topOffset = (bracketHeight - totalGroupsHeight) / 2;
          final groupTop = topOffset + (dest * (groupHeight + slotGap));
          yA = groupTop + (pillHeight / 2);
          yB = groupTop + pillHeight + slotGap + (pillHeight / 2);
        } else {
          final sourceCount = rounds[column - 1].matches.length;
          final sourceA = dest * 2;
          final sourceB = dest * 2 + 1;
          yA = _centerY(sourceA, sourceCount);
          yB = _centerY(sourceB, sourceCount);
        }

        canvas.drawLine(Offset(sourceLeft, yA), Offset(midX, yA), paint);
        canvas.drawLine(Offset(sourceLeft, yB), Offset(midX, yB), paint);
        canvas.drawLine(Offset(midX, yA), Offset(midX, yB), paint);
        canvas.drawLine(Offset(midX, yDest), Offset(destLeft, yDest), paint);
      }
    }
  }

  double _centerY(int index, int count) {
    return bracketHeight * (2 * index + 1) / (2 * count);
  }

  @override
  bool shouldRepaint(covariant _BracketTreePainter oldDelegate) {
    return oldDelegate.rounds != rounds || oldDelegate.color != color;
  }
}
