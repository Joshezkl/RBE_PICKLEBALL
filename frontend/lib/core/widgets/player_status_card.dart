import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import 'court_timer.dart';
import 'rpc_card.dart';
import 'rpc_status_badge.dart';

class PlayerStatusCard extends StatelessWidget {
  const PlayerStatusCard({
    super.key,
    required this.status,
    this.onStepOut,
    this.onStepBack,
    this.onOpenFullStatus,
    this.submitting = false,
    this.compact = false,
  });

  final CheckInPlayerStatus status;
  final VoidCallback? onStepOut;
  final VoidCallback? onStepBack;
  final VoidCallback? onOpenFullStatus;
  final bool submitting;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final tone = switch (status.status) {
      'playing' => RpcBadgeTone.success,
      'waiting' => RpcBadgeTone.primary,
      'away' => RpcBadgeTone.warning,
      'awaiting_payment' => RpcBadgeTone.warning,
      _ => RpcBadgeTone.neutral,
    };

    final headline = switch (status.status) {
      'playing' => 'On court now',
      'waiting' => 'In the queue',
      'away' => 'Stepped out',
      'awaiting_payment' => 'Awaiting payment',
      'not_joined' => 'Not checked in',
      _ => 'Checked in',
    };

    return RpcCard(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                switch (status.status) {
                  'playing' => Icons.sports_tennis_rounded,
                  'waiting' => Icons.hourglass_top_rounded,
                  'away' => Icons.pause_circle_outline_rounded,
                  'awaiting_payment' => Icons.payments_outlined,
                  _ => Icons.person_outline_rounded,
                },
                color: c.primary,
              ),
              const SizedBox(width: RpcSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: RpcTypography.title(context)),
                    if (status.playerName != null)
                      Text(
                        status.playerName!,
                        style: RpcTypography.bodySmallMuted(context),
                      ),
                  ],
                ),
              ),
              if (status.isGuest)
                const RpcStatusBadge(
                  label: 'Guest',
                  tone: RpcBadgeTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: RpcSpacing.md),
          Text(status.message, style: RpcTypography.body(context)),
          if (status.status == 'awaiting_payment' &&
              status.sessionFeeCents != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            Text(
              'Session fee: ₱${(status.sessionFeeCents! / 100).toStringAsFixed(0)} — pay at the registration desk',
              style: RpcTypography.bodySmallMuted(context),
            ),
          ],
          if (status.status == 'playing' && status.elapsedSeconds != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            CourtTimer(elapsedSeconds: status.elapsedSeconds),
          ],
          if (status.position != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            Text(
              'Queue position ${status.position}'
              '${status.groupsAhead != null && status.groupsAhead! > 0 ? ' · ${status.groupsAhead} group(s) ahead' : ''}',
              style: RpcTypography.bodySmallMuted(context),
            ),
          ],
          if (status.sessionWins != null || status.sessionLosses != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            Text(
              'Today: ${status.sessionWins ?? 0}W / ${status.sessionLosses ?? 0}L',
              style: RpcTypography.bodySmallMuted(context),
            ),
          ],
          const SizedBox(height: RpcSpacing.sm),
          RpcStatusBadge(label: status.message, tone: tone),
          if (!compact && status.inSession) ...[
            const SizedBox(height: RpcSpacing.lg),
            if (status.status == 'away')
              FilledButton.icon(
                onPressed: submitting ? null : onStepBack,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('I\'m Back'),
              )
            else if (status.status != 'playing')
              OutlinedButton.icon(
                onPressed: submitting ? null : onStepOut,
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                label: const Text('Step Out'),
              ),
            if (onOpenFullStatus != null) ...[
              const SizedBox(height: RpcSpacing.sm),
              TextButton(
                onPressed: onOpenFullStatus,
                child: const Text('Open full status page'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
