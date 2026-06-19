import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import 'display_cc_badge.dart';
import 'display_queue_widgets.dart';

class _CcMatchPreview {
  const _CcMatchPreview({
    required this.index,
    required this.label,
    required this.teamANames,
    required this.teamBNames,
  });

  final int index;
  final String label;
  final List<String> teamANames;
  final List<String> teamBNames;

  bool get isReady =>
      teamANames.length >= 2 && teamBNames.length >= 2;
}

class DisplayChallengeCourtQueuePanel extends StatelessWidget {
  const DisplayChallengeCourtQueuePanel({
    super.key,
    required this.state,
    required this.slotsPerTeam,
    this.compact = false,
  });

  final SessionState state;
  final int slotsPerTeam;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final previews = _buildPreviews(state);
    final headerSize = compact ? 13.0 : 15.0;

    return DisplayQueuePanelShell(
      compact: compact,
      icon: Icons.groups_rounded,
      title: 'Challenge Court Queue',
      titleFontSize: headerSize,
      trailing: const DisplayCcBadge(compact: true),
      footer: previews.isEmpty
          ? 'Teams join from the admin desk when Challenge Court is open.'
          : null,
      child: previews.isEmpty
          ? Center(
              child: Text(
                'No teams queued yet',
                style: RpcTypography.bodyMuted(context).copyWith(
                  fontSize: compact ? 11 : 12,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(compact ? 8 : 12),
              itemCount: previews.length,
              separatorBuilder: (_, __) => SizedBox(height: compact ? 6 : 10),
              itemBuilder: (context, index) {
                final preview = previews[index];
                return DisplayQueueMatchRow(
                  index: preview.index,
                  label: preview.label,
                  teamANames: preview.teamANames,
                  teamBNames: preview.teamBNames,
                  slotsPerTeam: slotsPerTeam,
                  compact: compact,
                  accent: _accentForLabel(context, preview.label),
                  isReady: preview.isReady,
                  highlightReady: preview.label == 'Next up',
                );
              },
            ),
    );
  }

  List<_CcMatchPreview> _buildPreviews(SessionState state) {
    final queued = state.challengeCourt.teams
        .where((team) => team.status == 'queued')
        .toList();

    if (queued.isEmpty) return [];

    List<String> namesFor(ChallengeCourtTeam team) {
      final names = <String>[];
      if (team.player1 != null) names.add(team.player1!.name);
      if (team.player2 != null) names.add(team.player2!.name);
      return names;
    }

    _CcMatchPreview preview(int index, String label, int teamAIdx, int? teamBIdx) {
      return _CcMatchPreview(
        index: index,
        label: label,
        teamANames: teamAIdx < queued.length ? namesFor(queued[teamAIdx]) : [],
        teamBNames: teamBIdx != null && teamBIdx < queued.length
            ? namesFor(queued[teamBIdx])
            : [],
      );
    }

    return [
      preview(1, 'Next up', 0, queued.length > 1 ? 1 : null),
      if (queued.length > 2)
        preview(2, 'On deck', 2, queued.length > 3 ? 3 : null),
      if (queued.length > 4)
        preview(3, 'Next on deck', 4, queued.length > 5 ? 5 : null),
    ];
  }

  Color _accentForLabel(BuildContext context, String label) {
    final c = context.rpc;
    return switch (label) {
      'Next up' => c.accentOrange,
      'On deck' => c.warning,
      'Next on deck' => c.primary,
      _ => c.textMuted,
    };
  }
}
