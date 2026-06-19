import 'package:flutter/material.dart';

import '../decor/rpc_court_accent.dart';
import '../models.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';
import 'challenge_court_closed_placeholder.dart';
import 'court_match_layout.dart';
import 'court_timer.dart';
import 'gradient_action_button.dart';

class MatchCourtCard extends StatelessWidget {
  const MatchCourtCard({
    super.key,
    required this.court,
    required this.slotsPerTeam,
    this.dense = false,
    this.canAssignNext = false,
    this.challengeCourtIsOpen = true,
    this.onEnterScore,
    this.onManualAssign,
    this.onAssignNext,
    this.onRemovePlayer,
  });

  final CourtInfo court;
  final int slotsPerTeam;
  final bool dense;
  final bool canAssignNext;
  final bool challengeCourtIsOpen;
  final void Function(MatchInfo match)? onEnterScore;
  final void Function(CourtInfo court)? onManualAssign;
  final void Function(CourtInfo court)? onAssignNext;
  final void Function(CourtInfo court, int playerId)? onRemovePlayer;

  @override
  Widget build(BuildContext context) {
    final match = court.match;
    final status = _statusInfo(context);
    final isActive = court.status == 'in_match';
    final showClosedPlaceholder = _showClosedPlaceholder;

    return RpcCourtAccent(
      active: isActive,
      borderRadius: BorderRadius.circular(dense ? 12 : 14),
      padding: EdgeInsets.all(dense ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CourtHeader(
              courtNumber: court.courtNumber,
              skillBracket: court.skillBracket,
              isChallengeCourt: court.isChallengeCourt,
              status: status,
              isLive: isActive,
              match: match,
              dense: dense,
            ),
            SizedBox(height: dense ? 10 : 14),
            if (showClosedPlaceholder)
              ChallengeCourtClosedPlaceholder(dense: dense)
            else if (match == null && court.defendingTeam != null)
              _DefendingTeamLayout(
                team: court.defendingTeam!,
                slotsPerTeam: slotsPerTeam,
                dense: dense,
              )
            else
              CourtMatchLayout(
                match: match,
                slotsPerTeam: slotsPerTeam,
                dense: dense,
                onRemovePlayer: match != null &&
                        match.status == 'in_match' &&
                        onRemovePlayer != null
                    ? (playerId) => onRemovePlayer!(court, playerId)
                    : null,
              ),
            if (match != null && match.scoreA != null && match.scoreB != null) ...[
              SizedBox(height: dense ? 6 : 10),
              _ScoreStrip(scoreA: match.scoreA!, scoreB: match.scoreB!, dense: dense),
            ],
            if (onEnterScore != null || onManualAssign != null || onAssignNext != null) ...[
              SizedBox(height: dense ? 10 : 14),
              if (match != null && match.status == 'in_match')
                GradientActionButton(
                  label: 'Enter Score',
                  icon: Icons.sports_score_rounded,
                  compact: dense,
                  onPressed: () => onEnterScore!(match),
                )
              else if (court.status == 'available' && !showClosedPlaceholder) ...[
                if (onAssignNext != null)
                  GradientActionButton(
                    label: _assignButtonLabel ??
                        (court.isChallengeCourt
                            ? 'Assign CC Match'
                            : 'Assign Next Up'),
                    icon: Icons.bolt_rounded,
                    compact: dense,
                    onPressed: canAssignNext ? () => onAssignNext!(court) : null,
                  ),
                if (onAssignNext != null &&
                    onManualAssign != null &&
                    !court.isChallengeCourt)
                  SizedBox(height: dense ? 6 : 8),
                if (onManualAssign != null && !court.isChallengeCourt)
                  GradientActionButton(
                    label: 'Manual Assign',
                    icon: Icons.group_add_outlined,
                    outlined: true,
                    compact: dense,
                    onPressed: () => onManualAssign!(court),
                  ),
              ],
            ],
          ],
        ),
    );
  }

  bool get _showClosedPlaceholder =>
      court.isChallengeCourt &&
      !challengeCourtIsOpen &&
      court.match == null &&
      court.defendingTeam == null;

  String? get _assignButtonLabel {
    if (!court.isChallengeCourt) return null;
    if (court.canNextChallenger) return 'Next Challenger';
    if (court.canAssignInitial) return 'Assign CC Match';
    return 'Assign CC Match';
  }

  ({Color color, String label, IconData icon}) _statusInfo(BuildContext context) {
    final c = context.rpc;
    if (_showClosedPlaceholder) {
      return (
        color: c.textMuted,
        label: 'Closed',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (court.defendingTeam != null && court.status == 'available') {
      return (
        color: c.accentOrange,
        label: 'Defending',
        icon: Icons.shield_outlined,
      );
    }
    switch (court.status) {
      case 'in_match':
        return (
          color: c.success,
          label: 'Live',
          icon: Icons.circle,
        );
      case 'waiting_result':
        return (
          color: c.warning,
          label: 'Waiting',
          icon: Icons.hourglass_top_rounded,
        );
      default:
        return (
          color: c.textMuted,
          label: 'Available',
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }
}

class _DefendingTeamLayout extends StatelessWidget {
  const _DefendingTeamLayout({
    required this.team,
    required this.slotsPerTeam,
    this.dense = false,
  });

  final ChallengeCourtTeam team;
  final int slotsPerTeam;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final players = [
      team.player1,
      if (slotsPerTeam > 1) team.player2,
    ];

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: c.accentOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.accentOrange.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: dense ? 14 : 16, color: c.accentOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Defending ${team.recordLabel}',
                  style: RpcTypography.bodySemibold(context).copyWith(
                    color: c.accentOrange,
                    fontSize: dense ? 12 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: dense ? 10 : 14),
        CourtMatchLayout(
          match: MatchInfo(
            id: 0,
            courtId: team.courtId ?? 0,
            status: 'idle',
            teamA: {
              'player1': players[0] != null
                  ? MatchPlayer(id: players[0]!.id, name: players[0]!.name)
                  : null,
              'player2': players.length > 1 && players[1] != null
                  ? MatchPlayer(id: players[1]!.id, name: players[1]!.name)
                  : null,
            },
            teamB: {
              'player1': null,
              'player2': null,
            },
          ),
          slotsPerTeam: slotsPerTeam,
          dense: dense,
          showTeamLabels: false,
        ),
        SizedBox(height: dense ? 6 : 8),
        Text(
          'Awaiting next challenger',
          textAlign: TextAlign.center,
          style: RpcTypography.bodySmallMuted(context),
        ),
      ],
    );
  }
}

class _CourtHeader extends StatelessWidget {
  const _CourtHeader({
    required this.courtNumber,
    required this.skillBracket,
    required this.isChallengeCourt,
    required this.status,
    required this.isLive,
    this.match,
    this.dense = false,
  });

  final int courtNumber;
  final String? skillBracket;
  final bool isChallengeCourt;
  final ({Color color, String label, IconData icon}) status;
  final bool isLive;
  final MatchInfo? match;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 10,
            vertical: dense ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: c.primaryLight,
            borderRadius: BorderRadius.circular(dense ? 6 : 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_tennis_rounded,
                size: dense ? 12 : 14,
                color: c.primary,
              ),
              SizedBox(width: dense ? 4 : 6),
              Text(
                _courtTitle(),
                style: (dense
                        ? RpcTypography.bodySemibold(context)
                        : RpcTypography.bodyBold(context))
                    .copyWith(
                  color: c.primary,
                  letterSpacing: -0.2,
                  fontSize: dense ? 12 : null,
                ),
              ),
              if (isChallengeCourt) ...[
                SizedBox(width: dense ? 4 : 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accentOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'CC',
                    style: RpcTypography.caption(context).copyWith(
                      color: c.accentOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: dense ? 10 : 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        if (isLive && match != null)
          Padding(
            padding: EdgeInsets.only(right: dense ? 6 : 8),
            child: CourtTimer(
              startedAt: match!.startedAt,
              elapsedSeconds: match!.elapsedSeconds,
              compact: true,
            ),
          ),
        _StatusBadge(
          label: status.label,
          color: status.color,
          pulse: isLive,
          dense: dense,
        ),
      ],
    );
  }

  String _courtTitle() {
    if (skillBracket != null) {
      final label =
          '${skillBracket![0].toUpperCase()}${skillBracket!.substring(1)}';
      return 'Court $courtNumber · $label';
    }
    return 'Court $courtNumber';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.pulse = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool pulse;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dense ? 5 : 6,
            height: dense ? 5 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: pulse
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          SizedBox(width: dense ? 4 : 6),
          Text(
            label,
            style: (dense
                    ? RpcTypography.caption(context)
                    : RpcTypography.bodyBold(context))
                .copyWith(
              color: color,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({
    required this.scoreA,
    required this.scoreB,
    this.dense = false,
  });

  final int scoreA;
  final int scoreB;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: dense ? 4 : 6,
        horizontal: dense ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$scoreA',
            style: RpcTypography.bodyBold(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '–',
              style: RpcTypography.bodyMuted(context),
            ),
          ),
          Text(
            '$scoreB',
            style: RpcTypography.bodyBold(context),
          ),
        ],
      ),
    );
  }
}
