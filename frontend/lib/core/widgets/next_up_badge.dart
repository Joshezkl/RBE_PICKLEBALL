import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import 'rpc_status_badge.dart';

enum NextUpBadgeStyle { primary, onDeck }

class NextUpBadge extends StatelessWidget {
  const NextUpBadge({
    super.key,
    this.style = NextUpBadgeStyle.primary,
  });

  final NextUpBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    final isPrimary = style == NextUpBadgeStyle.primary;
    return RpcStatusBadge(
      label: isPrimary ? 'Next Up' : 'On Deck',
      tone: isPrimary ? RpcBadgeTone.success : RpcBadgeTone.warning,
    );
  }
}

class NextUpGroupHeader extends StatelessWidget {
  const NextUpGroupHeader({
    super.key,
    required this.queueLabel,
    required this.playerNames,
    required this.groupSize,
    required this.ready,
    required this.accentColor,
    required this.isPriority,
  });

  final String queueLabel;
  final List<String> playerNames;
  final int groupSize;
  final bool ready;
  final Color accentColor;
  final bool isPriority;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final names = playerNames.isEmpty
        ? 'Waiting for players'
        : playerNames.join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPriority
            ? accentColor.withValues(alpha: 0.08)
            : c.background,
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        border: Border.all(
          color: isPriority
              ? accentColor.withValues(alpha: 0.35)
              : c.border,
          width: isPriority ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      queueLabel,
                      style: RpcTypography.bodyBold(context)
                          .copyWith(color: accentColor),
                    ),
                    if (isPriority) const NextUpBadge(),
                    if (!isPriority && ready)
                      const NextUpBadge(style: NextUpBadgeStyle.onDeck),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  names,
                  style: RpcTypography.body(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'Ready for court ($groupSize players)'
                      : 'Need ${groupSize - playerNames.length} more player${groupSize - playerNames.length == 1 ? '' : 's'}',
                  style: RpcTypography.bodySmallMuted(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
