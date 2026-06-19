import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

class MatchHistoryGrid extends StatelessWidget {
  const MatchHistoryGrid({
    super.key,
    required this.matches,
    this.emptyMessage = 'No finished matches yet',
    this.compact = false,
  });

  final List<MatchInfo> matches;
  final String emptyMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    if (matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: RpcSpacing.xl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(Icons.sports_tennis_outlined, size: 32, color: c.textMuted),
            const SizedBox(height: RpcSpacing.sm),
            Text(emptyMessage, style: RpcTypography.bodyMuted(context)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compact ? RpcSpacing.sm : RpcSpacing.md;
        final twoColumns = constraints.maxWidth >=
            (compact ? RpcBreakpoints.narrow : RpcBreakpoints.compact);
        if (!twoColumns) {
          return Column(
            children: [
              for (var i = 0; i < matches.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                MatchHistoryCard(match: matches[i], compact: compact),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < matches.length; i += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MatchHistoryCard(match: matches[i], compact: compact),
                ),
                if (i + 1 < matches.length) ...[
                  SizedBox(width: gap),
                  Expanded(
                    child: MatchHistoryCard(
                      match: matches[i + 1],
                      compact: compact,
                    ),
                  ),
                ] else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          );
          if (i + 2 < matches.length) {
            rows.add(SizedBox(height: gap));
          }
        }

        return Column(children: rows);
      },
    );
  }
}

class MatchHistoryCard extends StatelessWidget {
  const MatchHistoryCard({
    super.key,
    required this.match,
    this.compact = false,
  });

  final MatchInfo match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final court = match.courtNumber ?? match.courtId;
    final accent = _courtAccent(court, c);
    final teamAWon = match.winnerTeam == 'A';
    final teamBWon = match.winnerTeam == 'B';

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(
          compact ? RpcSpacing.inputRadius : RpcSpacing.cardRadius,
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.55),
          width: compact ? 1 : 1.5,
        ),
      ),
      padding: EdgeInsets.all(compact ? RpcSpacing.sm : RpcSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _headerLabel(match, court),
            style: RpcTypography.caption(context).copyWith(color: c.textMuted),
          ),
          SizedBox(height: compact ? RpcSpacing.sm : RpcSpacing.md),
          _TeamRow(
            teamLabel: 'A',
            players: _teamPlayers(match.teamA),
            score: match.scoreA ?? 0,
            isWinner: teamAWon,
            accent: accent,
            compact: compact,
          ),
          SizedBox(height: compact ? RpcSpacing.xs : RpcSpacing.sm),
          _TeamRow(
            teamLabel: 'B',
            players: _teamPlayers(match.teamB),
            score: match.scoreB ?? 0,
            isWinner: teamBWon,
            accent: accent,
            compact: compact,
          ),
        ],
      ),
    );
  }

  List<MatchPlayer> _teamPlayers(Map<String, MatchPlayer?> team) {
    return [
      team['player1'],
      team['player2'],
    ].whereType<MatchPlayer>().toList();
  }

  String _headerLabel(MatchInfo match, int court) {
    final parts = <String>[];
    if (match.isChallengeCourt) parts.add('CC');
    parts.add('Court $court');
    final time = _formatTime(match.finishedAt ?? match.startedAt);
    if (time != null) parts.add(time);
    final duration = _formatDuration(match);
    if (duration != null) parts.add(duration);
    return parts.join(' · ');
  }

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String? _formatDuration(MatchInfo match) {
    if (match.durationMinutes != null && match.durationMinutes! > 0) {
      return '${match.durationMinutes} mins';
    }
    if (match.elapsedSeconds != null && match.elapsedSeconds! > 0) {
      final mins = (match.elapsedSeconds! / 60).ceil();
      return '$mins mins';
    }
    if (match.startedAt != null && match.finishedAt != null) {
      final start = DateTime.tryParse(match.startedAt!);
      final end = DateTime.tryParse(match.finishedAt!);
      if (start != null && end != null) {
        final mins = end.difference(start).inMinutes;
        if (mins > 0) return '$mins mins';
      }
    }
    return null;
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.teamLabel,
    required this.players,
    required this.score,
    required this.isWinner,
    required this.accent,
    this.compact = false,
  });

  final String teamLabel;
  final List<MatchPlayer> players;
  final int score;
  final bool isWinner;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? RpcSpacing.sm : RpcSpacing.md,
        vertical: compact ? RpcSpacing.xs : RpcSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isWinner
            ? accent.withValues(alpha: isDark ? 0.14 : 0.1)
            : (isDark ? c.background : c.surfaceHover),
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StackedTeamLabel(
            teamLabel: teamLabel,
            color: isWinner ? accent : c.textMuted,
          ),
          const SizedBox(width: RpcSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < players.length; i++) ...[
                  if (i > 0) const SizedBox(height: RpcSpacing.xs),
                  _PlayerLine(player: players[i], accent: accent),
                ],
                if (players.isEmpty)
                  Text(
                    '—',
                    style: RpcTypography.bodyMuted(context),
                  ),
              ],
            ),
          ),
          const SizedBox(width: RpcSpacing.sm),
          Text(
            '$score',
            style: RpcTypography.statMedium(context).copyWith(
              fontSize: compact ? 22 : 28,
              height: 1,
              color: isWinner ? accent : c.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _StackedTeamLabel extends StatelessWidget {
  const _StackedTeamLabel({
    required this.teamLabel,
    required this.color,
  });

  final String teamLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Column(
        children: [
          Text(
            'TEAM',
            style: RpcTypography.overline(context).copyWith(
              color: color,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            teamLabel,
            style: RpcTypography.bodyBold(context).copyWith(
              color: color,
              fontSize: 16,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({required this.player, required this.accent});

  final MatchPlayer player;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PlayerAvatar(name: player.name, accent: accent),
        const SizedBox(width: RpcSpacing.sm),
        Expanded(
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RpcTypography.bodySemibold(context),
          ),
        ),
      ],
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.name, required this.accent});

  final String name;
  final Color accent;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.rpc.surface,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

Color _courtAccent(int courtNumber, RpcPalette c) {
  return switch (courtNumber % 3) {
    1 => c.accentOrange,
    2 => c.textMuted,
    _ => c.success,
  };
}
