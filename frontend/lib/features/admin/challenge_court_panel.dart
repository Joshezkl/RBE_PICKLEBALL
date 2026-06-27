import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/session_controller.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_status_badge.dart';
import 'join_cc_dialog.dart';

class ChallengeCourtPanel extends StatelessWidget {
  const ChallengeCourtPanel({
    super.key,
    required this.state,
    required this.controller,
    this.compact = false,
  });

  final SessionState state;
  final SessionController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final cc = state.challengeCourt;

    return RpcCard(
      padding: EdgeInsets.all(compact ? RpcSpacing.sm : RpcSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Challenge Court',
                          style: RpcTypography.bodySemibold(context),
                        ),
                        const SizedBox(width: RpcSpacing.sm),
                        const ChallengeCourtBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cc.courtNumbers.isEmpty
                          ? 'No court assigned · ${cc.isOpen ? 'Open' : 'Closed'}'
                          : 'Courts ${cc.courtNumbers.join(', ')} · '
                              '${cc.isOpen ? 'Open' : 'Closed'}',
                      style: RpcTypography.caption(context).copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (cc.isOpen)
                TextButton(
                  onPressed: () => controller.closeChallengeCourt(),
                  child: const Text('Close'),
                )
              else
                FilledButton(
                  onPressed: cc.courtNumbers.isEmpty
                      ? null
                      : () => controller.openChallengeCourt(),
                  child: const Text('Open CC'),
                ),
            ],
          ),
          const SizedBox(height: RpcSpacing.sm),
          _CourtConfigRow(
            courtCount: state.session.courtCount,
            selected: cc.courtNumbers,
            onChanged: controller.configureChallengeCourts,
          ),
          if (cc.isOpen) ...[
            const SizedBox(height: RpcSpacing.md),
            Text(
              'CC Queue (${cc.teams.length} teams)',
              style: RpcTypography.caption(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: RpcSpacing.xs),
            if (cc.teams.isEmpty)
              Text(
                'No teams yet. Add players from the session roster below.',
                style: RpcTypography.bodyMuted(context),
              )
            else
              ..._buildTeamRows(cc.teams, controller),
            const SizedBox(height: RpcSpacing.md),
            Text(
              'In session — eligible for CC',
              style: RpcTypography.caption(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: RpcSpacing.xs),
            if (cc.eligiblePlayers.isEmpty)
              Text(
                'No eligible players right now.',
                style: RpcTypography.bodyMuted(context),
              )
            else
              Wrap(
                spacing: RpcSpacing.xs,
                runSpacing: RpcSpacing.xs,
                children: cc.eligiblePlayers.map((player) {
                  return ActionChip(
                    label: Text(player.name),
                    avatar: const Icon(Icons.person_add_alt_1, size: 16),
                    onPressed: () async {
                      await _joinCc(context, player);
                    },
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _joinCc(BuildContext context, ChallengeCourtPlayer player) async {
    final partner = await JoinCcDialog.show(
      context,
      anchorPlayer: player,
      eligiblePlayers: state.challengeCourt.eligiblePlayers,
    );
    if (partner == null) return;
    await controller.joinChallengeCourtTeam(
      playerId: player.id,
      partnerId: partner.id,
    );
  }

  List<Widget> _buildTeamRows(
    List<ChallengeCourtTeam> teams,
    SessionController controller,
  ) {
    final queuedTeams = teams.where((team) => team.status == 'queued').toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final queuePositionByTeamId = {
      for (var i = 0; i < queuedTeams.length; i++) queuedTeams[i].id: i + 1,
    };

    return teams
        .map(
          (team) => _TeamRow(
            team: team,
            queuePosition: queuePositionByTeamId[team.id],
            onReturn: team.canReturn
                ? () => controller.returnChallengeCourtTeam(team.id)
                : null,
            onRemove: team.status == 'queued'
                ? () => controller.removeChallengeCourtTeam(team.id)
                : null,
          ),
        )
        .toList();
  }
}

class _CourtConfigRow extends StatelessWidget {
  const _CourtConfigRow({
    required this.courtCount,
    required this.selected,
    required this.onChanged,
  });

  final int courtCount;
  final List<int> selected;
  final Future<bool> Function(List<int> courtNumbers) onChanged;

  @override
  Widget build(BuildContext context) {
    if (courtCount < 1) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var number = 1; number <= courtCount; number++)
          FilterChip(
            label: Text('Court $number'),
            selected: selected.contains(number),
            onSelected: (isSelected) {
              final next = [...selected];
              if (isSelected) {
                if (!next.contains(number)) next.add(number);
              } else {
                next.remove(number);
              }
              next.sort();
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    this.queuePosition,
    this.onReturn,
    this.onRemove,
  });

  final ChallengeCourtTeam team;
  final int? queuePosition;
  final VoidCallback? onReturn;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final statusLabel = switch (team.status) {
      'playing' => 'Playing',
      'idle' => team.ccWins > 0
          ? 'Defending ${team.recordLabel} on court'
          : 'On court',
      _ => 'Queued #${queuePosition ?? 1}',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: RpcSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.displayName, style: RpcTypography.body(context)),
                Text(
                  statusLabel,
                  style: RpcTypography.caption(context).copyWith(
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (team.status == 'playing')
            const RpcStatusBadge(label: 'Live', tone: RpcBadgeTone.success),
          if (onReturn != null) ...[
            const SizedBox(width: RpcSpacing.xs),
            TextButton(
              onPressed: onReturn,
              child: const Text('Join session'),
            ),
          ],
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from queue',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18, color: c.danger),
            ),
        ],
      ),
    );
  }
}
