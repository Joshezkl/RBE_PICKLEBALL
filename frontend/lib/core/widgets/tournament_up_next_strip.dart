import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';
import '../tournament_models.dart';

/// Horizontal queue of upcoming tournament matches (admin + venue display).
class TournamentUpNextStrip extends StatelessWidget {
  const TournamentUpNextStrip({
    super.key,
    required this.matches,
    this.maxItems = 8,
    this.emptyMessage = 'No matches waiting for a court',
  });

  final List<TournamentUpNextMatchInfo> matches;
  final int maxItems;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final visible = matches.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Up next',
          style: RpcTypography.caption(context).copyWith(
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        if (visible.isEmpty)
          Text(
            emptyMessage,
            style: RpcTypography.caption(context).copyWith(
              color: c.textMuted,
              fontSize: 11,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  TournamentUpNextChip(match: visible[i], index: i),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class TournamentUpNextChip extends StatelessWidget {
  const TournamentUpNextChip({
    super.key,
    required this.match,
    required this.index,
  });

  final TournamentUpNextMatchInfo match;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final prefix = match.isReady
        ? (index == 0 ? 'Next' : 'On deck')
        : 'Waiting';
    final group = match.groupLabel != null ? '${match.groupLabel} · ' : '';

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.elevatedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$prefix · $group${match.teamA ?? 'TBD'} vs ${match.teamB ?? 'TBD'}',
            style: RpcTypography.caption(context).copyWith(
              fontWeight: index == 0 && match.isReady
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Venue display panel: vertical list of upcoming matches with full detail.
class TournamentUpNextPanel extends StatelessWidget {
  const TournamentUpNextPanel({
    super.key,
    required this.matches,
    this.emptyMessage = 'All round robin matches are on court or finished',
  });

  final List<TournamentUpNextMatchInfo> matches;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  'Up next',
                  style: RpcTypography.bodyBold(context).copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: RpcTypography.bodyMuted(context),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return TournamentUpNextListRow(
                        match: matches[index],
                        index: index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TournamentUpNextListRow extends StatelessWidget {
  const TournamentUpNextListRow({
    super.key,
    required this.match,
    required this.index,
  });

  final TournamentUpNextMatchInfo match;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final label = match.isReady
        ? (index == 0 ? 'Next up' : 'On deck')
        : 'Waiting';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: RpcTypography.caption(context).copyWith(
                  color: match.isReady ? c.primary : c.accentOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (match.groupLabel != null)
                Text(
                  match.groupLabel!,
                  style: RpcTypography.caption(context).copyWith(
                    color: c.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${match.teamA ?? 'TBD'}  vs  ${match.teamB ?? 'TBD'}',
            style: RpcTypography.bodySemibold(context),
          ),
          const SizedBox(height: 4),
          Text(
            match.categoryLabel,
            style: RpcTypography.caption(context).copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
