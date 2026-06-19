import 'package:flutter/material.dart';

import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import 'display_queue_widgets.dart';

class _MatchPreview {
  const _MatchPreview({
    required this.index,
    required this.label,
    required this.players,
    this.queueLabel,
  });

  final int index;
  final String label;
  final List<QueuePlayer> players;
  final String? queueLabel;
}

class DisplayUpNextPanel extends StatelessWidget {
  const DisplayUpNextPanel({
    super.key,
    required this.state,
    required this.slotsPerTeam,
    this.title = 'Queue rotation',
    this.compact = false,
  });

  final SessionState state;
  final int slotsPerTeam;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final previews = _buildMatchPreviews(state);
    final openSlots = _openSlotsInPreviews(previews, state.groupSize);
    final queueLabel = MatchModes.labelForQueue(_activeQueueType(state));

    return DisplayQueuePanelShell(
      compact: compact,
      icon: Icons.schedule_rounded,
      title: title,
      titleFontSize: compact ? 13 : 15,
      subtitle: compact ? queueLabel : null,
      trailing: compact
          ? null
          : _QueueTypeChip(label: queueLabel),
      footer: openSlots > 0
          ? 'Forming matches show empty slots — check in to fill them!'
          : null,
      child: ListView.separated(
        padding: EdgeInsets.all(compact ? 8 : 12),
        itemCount: previews.length,
        separatorBuilder: (_, __) => SizedBox(height: compact ? 6 : 10),
        itemBuilder: (context, index) {
          final preview = previews[index];
          final players = preview.players;
          final teamA = players.take(slotsPerTeam).map((p) => p.name).toList();
          final teamB =
              players.skip(slotsPerTeam).take(slotsPerTeam).map((p) => p.name).toList();
          final ready = players.length >= state.groupSize;
          final open = state.groupSize - players.length;

          return DisplayQueueMatchRow(
            index: preview.index,
            label: preview.label,
            queueLabel: compact ? null : preview.queueLabel,
            teamANames: teamA,
            teamBNames: teamB,
            slotsPerTeam: slotsPerTeam,
            compact: compact,
            accent: _rotationAccent(context, preview.label),
            isReady: ready,
            highlightReady: preview.label == 'Next up',
            openSlots: open > 0 ? open : 0,
          );
        },
      ),
    );
  }

  List<_MatchPreview> _buildMatchPreviews(SessionState state) {
    final groupSize = state.groupSize;
    final primary = state.primaryUpNext;
    final secondary = state.secondaryUpNext;
    final primaryQueueType = primary?.queueType ?? _activeQueueType(state);
    final primaryQueuePlayers = state.queues[primaryQueueType] ?? [];

    final nextUpPlayers = primary != null
        ? primary.players
        : primaryQueuePlayers.take(groupSize).toList();

    final onDeckPlayers = secondary?.players ?? [];

    final nextOnDeckPlayers = primaryQueuePlayers
        .skip(groupSize)
        .take(groupSize)
        .toList();

    return [
      _MatchPreview(
        index: 1,
        label: 'Next up',
        queueLabel: MatchModes.labelForQueue(primaryQueueType),
        players: nextUpPlayers,
      ),
      _MatchPreview(
        index: 2,
        label: 'On deck',
        queueLabel:
            secondary != null ? MatchModes.labelForQueue(secondary.queueType) : null,
        players: onDeckPlayers,
      ),
      _MatchPreview(
        index: 3,
        label: 'Next on deck',
        queueLabel: MatchModes.labelForQueue(primaryQueueType),
        players: nextOnDeckPlayers,
      ),
    ];
  }

  String _activeQueueType(SessionState state) {
    if (state.session.matchMode == 'skill_courts' ||
        state.session.matchMode == 'skill_separated') {
      for (final type in state.session.queueTypes) {
        if ((state.queues[type] ?? []).isNotEmpty) return type;
      }
      return state.session.queueTypes.first;
    }

    return state.session.nextCourtQueue;
  }

  int _openSlotsInPreviews(List<_MatchPreview> previews, int groupSize) {
    var open = 0;
    for (final preview in previews) {
      open += groupSize - preview.players.length;
    }
    return open;
  }

  Color _rotationAccent(BuildContext context, String label) {
    final c = Theme.of(context).extension<RpcPalette>()!;
    return switch (label) {
      'Next up' => c.success,
      'On deck' => c.warning,
      'Next on deck' => c.primary,
      _ => c.textMuted,
    };
  }
}

class _QueueTypeChip extends StatelessWidget {
  const _QueueTypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<RpcPalette>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.primary,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
