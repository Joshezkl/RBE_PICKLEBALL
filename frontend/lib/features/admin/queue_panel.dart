import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/next_up_badge.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/theme/rpc_spacing.dart';

class QueueDragData {
  const QueueDragData({
    required this.playerId,
    required this.sourceQueueType,
  });

  final int playerId;
  final String sourceQueueType;
}

typedef QueueMoveCallback = Future<void> Function(
  int playerId,
  String targetQueueType,
  int targetPosition,
);

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.title,
    required this.accentColor,
    required this.players,
    required this.groupSize,
    this.queueType,
    this.onMovePlayer,
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
  final String? queueType;
  final QueueMoveCallback? onMovePlayer;
  final void Function(int playerId)? onRemove;
  final void Function(int playerId, String name)? onEdit;
  final Set<int> nextUpPlayerIds;
  final Set<int> onDeckPlayerIds;
  final bool isPriorityQueue;
  final bool compact;

  bool get _dragEnabled => onMovePlayer != null && queueType != null;

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
            _buildEmptyState(context)
          else
            ..._buildPlayerList(context, c, avatarRadius),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 20),
      child: Center(
        child: Text(
          'No players waiting',
          style: RpcTypography.bodyMuted(context),
        ),
      ),
    );

    if (!_dragEnabled) return content;

    return _QueueDropZone(
      queueType: queueType!,
      insertIndex: 0,
      accentColor: accentColor,
      onMovePlayer: onMovePlayer!,
      child: content,
    );
  }

  List<Widget> _buildPlayerList(
    BuildContext context,
    RpcPalette c,
    double avatarRadius,
  ) {
    final widgets = <Widget>[];

    for (var index = 0; index < players.length; index++) {
      final player = players[index];

      if (_dragEnabled) {
        widgets.add(
          _QueueDropZone(
            queueType: queueType!,
            insertIndex: index,
            accentColor: accentColor,
            onMovePlayer: onMovePlayer!,
          ),
        );
      }

      widgets.add(
        _buildPlayerCard(
          context: context,
          c: c,
          player: player,
          avatarRadius: avatarRadius,
        ),
      );
    }

    if (_dragEnabled) {
      widgets.add(
        _QueueDropZone(
          queueType: queueType!,
          insertIndex: players.length,
          accentColor: accentColor,
          onMovePlayer: onMovePlayer!,
        ),
      );
    }

    return widgets;
  }

  Widget _buildPlayerCard({
    required BuildContext context,
    required RpcPalette c,
    required QueuePlayer player,
    required double avatarRadius,
  }) {
    final isNextUp = nextUpPlayerIds.contains(player.id);
    final isOnDeck = onDeckPlayerIds.contains(player.id);

    final card = Container(
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
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_dragEnabled) ...[
              MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: compact ? 16 : 18,
                  color: c.textMuted,
                ),
              ),
              SizedBox(width: compact ? 4 : 6),
            ],
            CircleAvatar(
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
          ],
        ),
        title: Text(
          player.name,
          style: RpcTypography.bodySemibold(context),
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

    if (!_dragEnabled) return card;

    return Draggable<QueueDragData>(
      data: QueueDragData(
        playerId: player.id,
        sourceQueueType: queueType!,
      ),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        child: SizedBox(
          width: 260,
          child: Opacity(
            opacity: 0.95,
            child: card,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: card,
      ),
      child: card,
    );
  }
}

class _QueueDropZone extends StatelessWidget {
  const _QueueDropZone({
    required this.queueType,
    required this.insertIndex,
    required this.accentColor,
    required this.onMovePlayer,
    this.child,
  });

  final String queueType;
  final int insertIndex;
  final Color accentColor;
  final QueueMoveCallback onMovePlayer;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<QueueDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.sourceQueueType != queueType) {
          return true;
        }

        final panel = context.findAncestorWidgetOfExactType<QueuePanel>();
        if (panel == null) return true;

        final sourcePlayer = panel.players
            .where((player) => player.id == data.playerId)
            .firstOrNull;
        if (sourcePlayer == null) return true;

        return sourcePlayer.position != insertIndex + 1;
      },
      onAcceptWithDetails: (details) {
        onMovePlayer(
          details.data.playerId,
          queueType,
          insertIndex + 1,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        final minHeight = child != null ? 0.0 : (isActive ? 28.0 : 6.0);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(bottom: child == null ? 0 : 2),
          height: child == null ? minHeight : null,
          decoration: isActive
              ? BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                )
              : null,
          child: child,
        );
      },
    );
  }
}
