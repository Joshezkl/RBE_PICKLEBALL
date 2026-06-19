import 'package:flutter/material.dart';

import '../../core/display/display_cue_controller.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';

class CelebrationOverlay extends StatelessWidget {
  const CelebrationOverlay({
    super.key,
    required this.celebration,
    required this.onDismiss,
  });

  final CelebrationState celebration;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final match = celebration.match;
    final teamAWon = match.winnerTeam == 'A';
    final teamBWon = match.winnerTeam == 'B';
    final courtLabel = celebration.courtNumber != null
        ? 'Court ${celebration.courtNumber}'
        : 'Match Complete';

    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: GestureDetector(
        onTap: onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(RpcSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 72,
                    color: context.rpc.accentOrange,
                  ),
                  const SizedBox(height: RpcSpacing.lg),
                  Text(
                    courtLabel,
                    style: RpcTypography.overline(context).copyWith(
                      color: Colors.white60,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: RpcSpacing.sm),
                  Text(
                    'Winner!',
                    style: RpcTypography.display(context).copyWith(
                      fontSize: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: RpcSpacing.xl),
                  _WinnerCard(
                    label: 'Team A',
                    players: match.teamA,
                    score: match.scoreA ?? 0,
                    isWinner: teamAWon,
                  ),
                  const SizedBox(height: RpcSpacing.md),
                  Text(
                    '${match.scoreA ?? 0}  –  ${match.scoreB ?? 0}',
                    style: RpcTypography.stat(context).copyWith(
                      fontSize: 48,
                      color: context.rpc.primary,
                    ),
                  ),
                  const SizedBox(height: RpcSpacing.md),
                  _WinnerCard(
                    label: 'Team B',
                    players: match.teamB,
                    score: match.scoreB ?? 0,
                    isWinner: teamBWon,
                  ),
                  const SizedBox(height: RpcSpacing.xl),
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
    ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({
    required this.label,
    required this.players,
    required this.score,
    required this.isWinner,
  });

  final String label;
  final Map<String, MatchPlayer?> players;
  final int score;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final names = [
      players['player1']?.name,
      players['player2']?.name,
    ].whereType<String>().join(' & ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RpcSpacing.lg),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RpcTypography.overline(context).copyWith(
                    color: isWinner ? c.accentOrange : Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  names.isEmpty ? '—' : names,
                  style: RpcTypography.title(context).copyWith(
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$score',
            style: RpcTypography.statMedium(context).copyWith(
              fontSize: 36,
              color: isWinner ? c.accentOrange : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
