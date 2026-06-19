import 'package:flutter/material.dart';

import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';

class DisplayQueuePanelShell extends StatelessWidget {
  const DisplayQueuePanelShell({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.subtitle,
    this.footer,
    this.compact = false,
    this.titleFontSize,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final String? subtitle;
  final String? footer;
  final bool compact;
  final double? titleFontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final headerPad = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
        : const EdgeInsets.fromLTRB(14, 12, 14, 10);

    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: headerPad,
            child: Row(
              children: [
                Icon(icon, size: compact ? 16 : 18, color: c.primary),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: RpcTypography.bodyBold(context).copyWith(
                          fontSize: titleFontSize ?? (compact ? 13 : 15),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: RpcTypography.caption(context).copyWith(
                            color: c.textMuted,
                            fontSize: compact ? 9 : 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(child: child),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 14,
                0,
                compact ? 10 : 14,
                compact ? 8 : 12,
              ),
              child: Text(
                footer!,
                style: RpcTypography.caption(context).copyWith(
                  color: c.accentOrange.withValues(alpha: 0.9),
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DisplayQueueMatchRow extends StatelessWidget {
  const DisplayQueueMatchRow({
    super.key,
    required this.index,
    required this.label,
    required this.teamANames,
    required this.teamBNames,
    required this.slotsPerTeam,
    required this.accent,
    required this.isReady,
    this.queueLabel,
    this.compact = false,
    this.highlightReady = false,
    this.openSlots = 0,
  });

  final int index;
  final String label;
  final List<String> teamANames;
  final List<String> teamBNames;
  final int slotsPerTeam;
  final Color accent;
  final bool isReady;
  final String? queueLabel;
  final bool compact;
  final bool highlightReady;
  final int openSlots;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final pad = compact ? 8.0 : 10.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(
          color: isReady && highlightReady
              ? c.success.withValues(alpha: 0.4)
              : accent.withValues(alpha: 0.25),
          width: highlightReady && isReady ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 20 : 24,
                height: compact ? 20 : 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: RpcTypography.caption(context).copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 9 : null,
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: RpcTypography.bodySemibold(context).copyWith(
                        fontSize: compact ? 11 : 12,
                        color: accent,
                      ),
                    ),
                    if (queueLabel != null)
                      Text(
                        queueLabel!,
                        style: RpcTypography.caption(context).copyWith(
                          color: c.textMuted,
                          fontSize: compact ? 9 : 10,
                        ),
                      ),
                  ],
                ),
              ),
              if (isReady)
                DisplayQueueStatusPill(
                  label: 'READY',
                  color: c.success,
                  compact: compact,
                )
              else if (openSlots > 0)
                DisplayQueueStatusPill(
                  label: '$openSlots slot${openSlots == 1 ? '' : 's'} open',
                  color: c.warning,
                  compact: compact,
                ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DisplayQueueTeamColumn(
                  label: 'Team A',
                  names: teamANames,
                  slots: slotsPerTeam,
                  tint: c.primary,
                  compact: compact,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 4 : 8,
                  vertical: compact ? 8 : 12,
                ),
                child: Text(
                  'VS',
                  style: RpcTypography.caption(context).copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 9 : null,
                  ),
                ),
              ),
              Expanded(
                child: DisplayQueueTeamColumn(
                  label: 'Team B',
                  names: teamBNames,
                  slots: slotsPerTeam,
                  tint: c.accentOrange,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DisplayQueueStatusPill extends StatelessWidget {
  const DisplayQueueStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: RpcTypography.caption(context).copyWith(
          color: color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DisplayQueueTeamColumn extends StatelessWidget {
  const DisplayQueueTeamColumn({
    super.key,
    required this.label,
    required this.names,
    required this.slots,
    required this.tint,
    this.compact = false,
  });

  final String label;
  final List<String> names;
  final int slots;
  final Color tint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: RpcTypography.caption(context).copyWith(
            color: tint,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 9 : 10,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        for (var i = 0; i < slots; i++) ...[
          if (i > 0) SizedBox(height: compact ? 4 : 6),
          i < names.length
              ? DisplayQueuePlayerTile(
                  name: names[i],
                  tint: tint,
                  compact: compact,
                )
              : DisplayQueueEmptySlot(compact: compact),
        ],
      ],
    );
  }
}

class DisplayQueuePlayerTile extends StatelessWidget {
  const DisplayQueuePlayerTile({
    super.key,
    required this.name,
    required this.tint,
    this.compact = false,
  });

  final String name;
  final Color tint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Text(
        name,
        style: RpcTypography.bodySemibold(context).copyWith(
          fontSize: compact ? 10 : 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class DisplayQueueEmptySlot extends StatelessWidget {
  const DisplayQueueEmptySlot({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: c.border),
      ),
      child: Text(
        '— waiting —',
        textAlign: TextAlign.center,
        style: RpcTypography.caption(context).copyWith(
          color: c.textMuted,
          fontSize: compact ? 9 : 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

String displayQueueLabel(SessionState state) {
  return MatchModes.labelForQueue(_activeQueueType(state));
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
