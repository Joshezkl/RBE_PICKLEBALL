import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';

class DisplayTopPerformersPanel extends StatelessWidget {
  const DisplayTopPerformersPanel({
    super.key,
    required this.entries,
    this.compact = false,
  });

  final List<LeaderboardEntry> entries;
  final bool compact;

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
                Icon(
                  Icons.emoji_events_outlined,
                  size: compact ? 16 : 18,
                  color: c.accentOrange,
                ),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  'Top performers',
                  style: RpcTypography.bodyBold(context).copyWith(
                    fontSize: compact ? 13 : 15,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 8 : RpcSpacing.md),
                      child: Text(
                        'No results yet',
                        style: RpcTypography.bodyMuted(context).copyWith(
                          fontSize: compact ? 11 : 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(compact ? 8 : 12),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: compact ? 6 : 8),
                    itemBuilder: (context, index) {
                      return _PerformerRow(
                        entry: entries[index],
                        compact: compact,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PerformerRow extends StatelessWidget {
  const _PerformerRow({
    required this.entry,
    this.compact = false,
  });

  final LeaderboardEntry entry;
  final bool compact;

  Color _rankColor(int rank, RpcPalette c) {
    return switch (rank) {
      1 => c.accentOrange,
      2 => c.textMuted,
      3 => const Color(0xFFCD7F32),
      _ => c.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final rankColor = _rankColor(entry.rank, c);
    final record = '${entry.wins}W-${entry.losses}L';
    final diff = entry.pointDifferential;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 22 : 28,
            height: compact ? 22 : 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              '${entry.rank}',
              style: RpcTypography.bodyBold(context).copyWith(
                color: rankColor,
                fontSize: compact ? 11 : 13,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: RpcTypography.bodySemibold(context).copyWith(
                    fontSize: compact ? 11 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  record,
                  style: RpcTypography.caption(context).copyWith(
                    color: c.textMuted,
                    fontSize: compact ? 9 : 11,
                  ),
                ),
              ],
            ),
          ),
          if (diff != 0)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 3,
              ),
              decoration: BoxDecoration(
                color: (diff > 0 ? c.success : c.danger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                diff > 0 ? '+$diff' : '$diff',
                style: RpcTypography.caption(context).copyWith(
                  color: diff > 0 ? c.success : c.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 9 : 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
