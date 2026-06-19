import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/next_up_badge.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/theme/rpc_spacing.dart';

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.title,
    required this.accentColor,
    required this.players,
    required this.groupSize,
    this.onRemove,
    this.onEdit,
    this.nextUpPlayerIds = const {},
    this.onDeckPlayerIds = const {},
    this.isPriorityQueue = false,
    this.compact = false,
  });

  final String title;
  final Color accentColor;
  final List<QueuePlayer> players;
  final int groupSize;
  final void Function(int playerId)? onRemove;
  final void Function(int playerId, String name)? onEdit;
  final Set<int> nextUpPlayerIds;
  final Set<int> onDeckPlayerIds;
  final bool isPriorityQueue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final nextUpCount =
        players.where((p) => nextUpPlayerIds.contains(p.id)).length;
    final cardPadding = compact ? 12.0 : 20.0;
    final avatarRadius = compact ? 14.0 : 16.0;

    return RpcCard(
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: compact ? 4 : 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: compact
                          ? RpcTypography.bodySemibold(context)
                          : RpcTypography.labelSemibold(context),
                    ),
                    if (isPriorityQueue) const NextUpBadge(),
                    RpcStatusBadge(
                      label: '${players.length} waiting',
                      tone: RpcBadgeTone.neutral,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextUpCount > 0) ...[
            SizedBox(height: compact ? 6 : 8),
            Text(
              'Positions 1–$groupSize are next in line for assignment',
              style: RpcTypography.bodySmallMuted(context),
            ),
          ],
          SizedBox(height: compact ? 10 : 16),
          if (players.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 12 : 20),
              child: Center(
                child: Text(
                  'No players waiting',
                  style: RpcTypography.bodyMuted(context),
                ),
              ),
            )
          else
            ...players.map(
              (player) {
                final isNextUp = nextUpPlayerIds.contains(player.id);
                final isOnDeck = onDeckPlayerIds.contains(player.id);

                return Container(
                  margin: EdgeInsets.only(bottom: compact ? 4 : 6),
                  decoration: BoxDecoration(
                    color: isNextUp
                        ? accentColor.withValues(alpha: 0.08)
                        : c.background,
                    borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                    border: Border.all(
                      color: isNextUp
                          ? accentColor.withValues(alpha: 0.45)
                          : isOnDeck
                              ? c.warning.withValues(alpha: 0.35)
                              : c.border,
                      width: isNextUp ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 2 : 0,
                    ),
                    leading: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: isNextUp
                          ? accentColor.withValues(alpha: 0.18)
                          : accentColor.withValues(alpha: 0.1),
                      child: Text(
                        '${player.position}',
                        style: (compact
                                ? RpcTypography.caption(context)
                                : RpcTypography.bodyBold(context))
                            .copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      player.name,
                      style: compact
                          ? RpcTypography.bodySemibold(context)
                          : RpcTypography.bodySemibold(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${player.wins}W · ${player.losses}L',
                          style: RpcTypography.bodySmallMuted(context),
                        ),
                        if (isNextUp || isOnDeck) ...[
                          const SizedBox(height: 4),
                          NextUpBadge(
                            style: isNextUp
                                ? NextUpBadgeStyle.primary
                                : NextUpBadgeStyle.onDeck,
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: isNextUp || isOnDeck,
                    trailing: (onRemove == null && onEdit == null)
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: compact ? 14 : 16,
                                  ),
                                  color: c.textMuted,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Edit name',
                                  onPressed: () => onEdit!(player.id, player.name),
                                ),
                              if (onRemove != null)
                                IconButton(
                                  icon: Icon(Icons.close, size: compact ? 14 : 16),
                                  color: c.textMuted,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove from session',
                                  onPressed: () => onRemove!(player.id),
                                ),
                            ],
                          ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
