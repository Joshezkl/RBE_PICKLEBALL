import 'package:flutter/material.dart';

import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/tournament_display_cue_controller.dart';

class TournamentCelebrationOverlay extends StatelessWidget {
  const TournamentCelebrationOverlay({
    super.key,
    required this.celebration,
    required this.onDismiss,
  });

  final TournamentCelebrationState celebration;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final result = celebration.result;
    final scoreA = result.scoreA ?? 0;
    final scoreB = result.scoreB ?? 0;
    final teamAWins = scoreA > scoreB;
    final teamBWins = scoreB > scoreA;
    final courtLabel = celebration.courtNumber != null
        ? 'Court ${celebration.courtNumber}'
        : 'Match complete';

    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(RpcSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: context.rpc.accentOrange,
                  ),
                  const SizedBox(height: RpcSpacing.md),
                  Text(
                    courtLabel,
                    style: RpcTypography.overline(context).copyWith(
                      color: Colors.white60,
                      fontSize: 13,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: RpcSpacing.sm),
                  Text(
                    'Winner!',
                    style: RpcTypography.display(context).copyWith(
                      fontSize: 38,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: RpcSpacing.lg),
                  _TournamentWinnerLine(
                    name: result.teamA ?? '—',
                    score: scoreA,
                    isWinner: teamAWins,
                  ),
                  const SizedBox(height: RpcSpacing.sm),
                  Text(
                    '$scoreA  –  $scoreB',
                    style: RpcTypography.stat(context).copyWith(
                      fontSize: 40,
                      color: context.rpc.primary,
                    ),
                  ),
                  const SizedBox(height: RpcSpacing.sm),
                  _TournamentWinnerLine(
                    name: result.teamB ?? '—',
                    score: scoreB,
                    isWinner: teamBWins,
                  ),
                  const SizedBox(height: RpcSpacing.lg),
                  Text(
                    'Tap to dismiss',
                    style: RpcTypography.caption(context).copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentWinnerLine extends StatelessWidget {
  const _TournamentWinnerLine({
    required this.name,
    required this.score,
    required this.isWinner,
  });

  final String name;
  final int score;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: RpcSpacing.lg,
        vertical: RpcSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isWinner
            ? c.accentOrange.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(
          color: isWinner ? c.accentOrange : Colors.white24,
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: RpcTypography.title(context).copyWith(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '$score',
            style: RpcTypography.statMedium(context).copyWith(
              fontSize: 30,
              color: isWinner ? c.accentOrange : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
