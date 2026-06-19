import 'package:flutter/material.dart';

import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/next_up_badge.dart';
import '../../core/widgets/rpc_responsive.dart';

class ManualAssignDialog extends StatefulWidget {
  const ManualAssignDialog({
    super.key,
    required this.court,
    required this.state,
  });

  final CourtInfo court;
  final SessionState state;

  @override
  State<ManualAssignDialog> createState() => _ManualAssignDialogState();
}

class _ManualAssignDialogState extends State<ManualAssignDialog> {
  final Set<int> _selected = {};

  int get _groupSize => widget.state.groupSize;

  @override
  Widget build(BuildContext context) {
    final primary = widget.state.primaryUpNext;
    final queueTypes = widget.state.session.queueTypes;

    return Dialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      child: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(
          context,
          maxWidth: 480,
          maxHeightFraction: 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Assign Court ${widget.court.courtNumber}',
                style: RpcTypography.title(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Select $_groupSize players (${_selected.length}/$_groupSize)',
                style: RpcTypography.bodyMuted(context),
              ),
              if (primary != null) ...[
                const SizedBox(height: 12),
                NextUpGroupHeader(
                  queueLabel:
                      '${MatchModes.labelForQueue(primary.queueType)} — Next Up',
                  playerNames:
                      primary.players.map((player) => player.name).toList(),
                  groupSize: _groupSize,
                  ready: primary.ready,
                  accentColor:
                      MatchModes.accentForQueue(context, primary.queueType),
                  isPriority: true,
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: widget.state.allQueuedPlayers.isEmpty
                    ? Center(
                        child: Text(
                          'No players in queue',
                          style: RpcTypography.bodyMuted(context),
                        ),
                      )
                    : ListView(
                        children: [
                          for (var i = 0; i < queueTypes.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _QueueSection(
                              title: MatchModes.labelForQueue(queueTypes[i]),
                              accentColor: MatchModes.accentForQueue(
                                context,
                                queueTypes[i],
                              ),
                              players:
                                  widget.state.queues[queueTypes[i]] ?? [],
                              groupSize: _groupSize,
                              nextUpPlayerIds: widget.state.nextUpPlayerIds,
                              onDeckPlayerIds: widget.state.onDeckPlayerIds,
                              isPriorityQueue: _isPriorityQueue(queueTypes[i]),
                              selected: _selected,
                              selectionLimit: _groupSize,
                              onToggle: _togglePlayer,
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: RpcTypography.body(context)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selected.length == _groupSize
                          ? () => Navigator.pop(context, _selected.toList())
                          : null,
                      child: Text(
                        'Assign',
                        style: RpcTypography.bodySemibold(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPriorityQueue(String queueType) {
    if (widget.state.session.queueTypes.contains('winner')) {
      return widget.state.session.nextCourtQueue == queueType;
    }

    return widget.state.primaryUpNext?.queueType == queueType;
  }

  void _togglePlayer(int playerId, bool checked) {
    setState(() {
      if (checked) {
        if (_selected.length < _groupSize) {
          _selected.add(playerId);
        }
      } else {
        _selected.remove(playerId);
      }
    });
  }
}

class _QueueSection extends StatelessWidget {
  const _QueueSection({
    required this.title,
    required this.accentColor,
    required this.players,
    required this.groupSize,
    required this.nextUpPlayerIds,
    required this.onDeckPlayerIds,
    required this.isPriorityQueue,
    required this.selected,
    required this.selectionLimit,
    required this.onToggle,
  });

  final String title;
  final Color accentColor;
  final List<QueuePlayer> players;
  final int groupSize;
  final Set<int> nextUpPlayerIds;
  final Set<int> onDeckPlayerIds;
  final bool isPriorityQueue;
  final Set<int> selected;
  final int selectionLimit;
  final void Function(int playerId, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    if (players.isEmpty) {
      return Text(
        '$title is empty',
        style: RpcTypography.bodyMuted(context),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: RpcTypography.bodyBold(context).copyWith(color: accentColor),
            ),
            if (isPriorityQueue) ...[
              const SizedBox(width: 8),
              const NextUpBadge(),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ...players.map((player) {
          final isNextUp = nextUpPlayerIds.contains(player.id);
          final isOnDeck = onDeckPlayerIds.contains(player.id);
          final isSelected = selected.contains(player.id);
          final atLimit = selected.length >= selectionLimit;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: isSelected
                  ? c.primaryLight
                  : isNextUp
                      ? accentColor.withValues(alpha: 0.08)
                      : c.background,
              borderRadius: BorderRadius.circular(8),
              child: CheckboxListTile(
                value: isSelected,
                dense: true,
                title: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${player.position}',
                        style: RpcTypography.bodyBold(context).copyWith(
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        player.name,
                        style: RpcTypography.bodySemibold(context),
                      ),
                    ),
                    if (isNextUp)
                      const NextUpBadge()
                    else if (isOnDeck)
                      const NextUpBadge(style: NextUpBadgeStyle.onDeck),
                  ],
                ),
                subtitle: Text(
                  '${player.wins}W · ${player.losses}L',
                  style: RpcTypography.bodySmallMuted(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isNextUp
                        ? accentColor.withValues(alpha: 0.45)
                        : isSelected
                            ? c.primary.withValues(alpha: 0.3)
                            : c.border,
                    width: isNextUp ? 1.5 : 1,
                  ),
                ),
                onChanged: (checked) {
                  if (checked == true && atLimit && !isSelected) return;
                  onToggle(player.id, checked == true);
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
