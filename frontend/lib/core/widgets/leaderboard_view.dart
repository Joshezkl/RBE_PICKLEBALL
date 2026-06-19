import 'package:flutter/material.dart';

import '../match_modes.dart';
import '../models.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import 'rpc_status_badge.dart';

enum LeaderboardSortMode { overall, thisMonth, season, currentSession }

String leaderboardSortModeLabel(LeaderboardSortMode mode, {int? seasonYear}) {
  return switch (mode) {
    LeaderboardSortMode.overall => 'Overall',
    LeaderboardSortMode.thisMonth => 'This Month',
    LeaderboardSortMode.season => 'Season ${seasonYear ?? DateTime.now().year}',
    LeaderboardSortMode.currentSession => 'Current Session',
  };
}

String formatPointDifferential(int pd) => pd >= 0 ? '+$pd' : '$pd';

enum LeaderboardGenderFilter { all, male, female }

List<LeaderboardEntry> filterLeaderboardEntries(
  List<LeaderboardEntry> entries,
  LeaderboardGenderFilter genderFilter,
) {
  final filtered = switch (genderFilter) {
    LeaderboardGenderFilter.all => entries,
    LeaderboardGenderFilter.male =>
      entries.where((e) => e.gender == 'male').toList(),
    LeaderboardGenderFilter.female =>
      entries.where((e) => e.gender == 'female').toList(),
  };

  return filtered
      .asMap()
      .entries
      .map((e) => e.value.copyWith(rank: e.key + 1))
      .toList();
}

class LeaderboardView extends StatelessWidget {
  const LeaderboardView({
    super.key,
    required this.entries,
    required this.sortMode,
    required this.genderFilter,
    required this.onSortChanged,
    required this.onGenderFilterChanged,
    this.sessionAvailable = true,
    this.loading = false,
    this.emptyMessage = 'No ranked players yet',
    this.seasonYear = 2026,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardSortMode sortMode;
  final LeaderboardGenderFilter genderFilter;
  final ValueChanged<LeaderboardSortMode> onSortChanged;
  final ValueChanged<LeaderboardGenderFilter> onGenderFilterChanged;
  final bool sessionAvailable;
  final bool loading;
  final String emptyMessage;
  final int seasonYear;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final displayEntries = filterLeaderboardEntries(entries, genderFilter);
    final topThree = displayEntries.where((e) => e.rank <= 3).toList();
    final rest = displayEntries.where((e) => e.rank > 3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LeaderboardControls(
          sortMode: sortMode,
          genderFilter: genderFilter,
          sessionAvailable: sessionAvailable,
          seasonYear: seasonYear,
          onSortChanged: onSortChanged,
          onGenderFilterChanged: onGenderFilterChanged,
        ),
        const SizedBox(height: RpcSpacing.lg),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (displayEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: RpcTypography.bodyMuted(context),
            ),
          )
        else ...[
          if (topThree.isNotEmpty) ...[
            _PodiumSection(entries: topThree),
            const SizedBox(height: RpcSpacing.lg),
          ],
          if (rest.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
                border: Border.all(color: c.border),
              ),
              constraints: const BoxConstraints(maxHeight: 480),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(RpcSpacing.md),
                itemCount: rest.length,
                separatorBuilder: (_, __) => const SizedBox(height: RpcSpacing.sm),
                itemBuilder: (context, index) =>
                    _LeaderboardListTile(entry: rest[index]),
              ),
            ),
        ],
      ],
    );
  }
}

class _LeaderboardControls extends StatelessWidget {
  const _LeaderboardControls({
    required this.sortMode,
    required this.genderFilter,
    required this.sessionAvailable,
    required this.seasonYear,
    required this.onSortChanged,
    required this.onGenderFilterChanged,
  });

  final LeaderboardSortMode sortMode;
  final LeaderboardGenderFilter genderFilter;
  final bool sessionAvailable;
  final int seasonYear;
  final ValueChanged<LeaderboardSortMode> onSortChanged;
  final ValueChanged<LeaderboardGenderFilter> onGenderFilterChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < RpcBreakpoints.compact;

        final sortControl = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SORT', style: RpcTypography.overline(context)),
            const SizedBox(width: RpcSpacing.sm),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<LeaderboardSortMode>(
                isExpanded: true,
                value: sortMode,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: LeaderboardSortMode.overall,
                    child: Text('Overall'),
                  ),
                  const DropdownMenuItem(
                    value: LeaderboardSortMode.thisMonth,
                    child: Text('This Month'),
                  ),
                  DropdownMenuItem(
                    value: LeaderboardSortMode.season,
                    child: Text(
                      leaderboardSortModeLabel(
                        LeaderboardSortMode.season,
                        seasonYear: seasonYear,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: LeaderboardSortMode.currentSession,
                    enabled: sessionAvailable,
                    child: Text(
                      sessionAvailable
                          ? 'Current Session'
                          : 'Current Session (none)',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
          ],
        );

        final genderControl = _GenderFilterBar(
          selected: genderFilter,
          onChanged: onGenderFilterChanged,
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sortControl,
              const SizedBox(height: RpcSpacing.md),
              genderControl,
            ],
          );
        }

        return Row(
          children: [
            const Spacer(),
            sortControl,
            const SizedBox(width: RpcSpacing.lg),
            genderControl,
          ],
        );
      },
    );
  }
}

class _GenderFilterBar extends StatelessWidget {
  const _GenderFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final LeaderboardGenderFilter selected;
  final ValueChanged<LeaderboardGenderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('FILTER', style: RpcTypography.overline(context)),
        const SizedBox(width: RpcSpacing.sm),
        _GenderFilterChip(
          tooltip: 'All players',
          icon: Icons.people_outline_rounded,
          selected: selected == LeaderboardGenderFilter.all,
          onTap: () => onChanged(LeaderboardGenderFilter.all),
        ),
        const SizedBox(width: RpcSpacing.xs),
        _GenderFilterChip(
          tooltip: 'Male only',
          icon: Icons.male_rounded,
          selected: selected == LeaderboardGenderFilter.male,
          onTap: () => onChanged(LeaderboardGenderFilter.male),
        ),
        const SizedBox(width: RpcSpacing.xs),
        _GenderFilterChip(
          tooltip: 'Female only',
          icon: Icons.female_rounded,
          selected: selected == LeaderboardGenderFilter.female,
          onTap: () => onChanged(LeaderboardGenderFilter.female),
        ),
      ],
    );
  }
}

class _GenderFilterChip extends StatelessWidget {
  const _GenderFilterChip({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? c.primaryLight : c.surface,
        borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
              border: Border.all(
                color: selected ? c.primary : c.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? c.primary : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PodiumSection extends StatelessWidget {
  const _PodiumSection({required this.entries});

  final List<LeaderboardEntry> entries;

  LeaderboardEntry? _byRank(int rank) {
    for (final entry in entries) {
      if (entry.rank == rank) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final first = _byRank(1);
    final second = _byRank(2);
    final third = _byRank(3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < RpcBreakpoints.medium;

        if (compact) {
          return Column(
            children: [
              if (first != null) _PodiumCard(entry: first, tier: _PodiumTier.gold),
              if (second != null) ...[
                const SizedBox(height: RpcSpacing.md),
                _PodiumCard(entry: second, tier: _PodiumTier.silver),
              ],
              if (third != null) ...[
                const SizedBox(height: RpcSpacing.md),
                _PodiumCard(entry: third, tier: _PodiumTier.bronze),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: second != null
                  ? _PodiumCard(entry: second, tier: _PodiumTier.silver)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: RpcSpacing.md),
            Expanded(
              flex: second != null || third != null ? 1 : 1,
              child: first != null
                  ? _PodiumCard(
                      entry: first,
                      tier: _PodiumTier.gold,
                      elevated: true,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: RpcSpacing.md),
            Expanded(
              child: third != null
                  ? _PodiumCard(entry: third, tier: _PodiumTier.bronze)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

enum _PodiumTier { gold, silver, bronze }

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.tier,
    this.elevated = false,
  });

  final LeaderboardEntry entry;
  final _PodiumTier tier;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final style = _tierStyle(context, tier);
    final skill = entry.skillLevel != null
        ? MatchModes.skillLabel(entry.skillLevel!)
        : '—';

    return Container(
      padding: EdgeInsets.all(elevated ? RpcSpacing.lg : RpcSpacing.md),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(color: style.border, width: elevated ? 1.5 : 1),
        boxShadow: elevated ? [context.rpc.cardShadow] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RankMedallion(rank: entry.rank, tier: tier),
              const Spacer(),
              Text(
                style.rankLabel,
                style: RpcTypography.overline(context).copyWith(
                  color: style.accent,
                ),
              ),
            ],
          ),
          SizedBox(height: elevated ? RpcSpacing.md : RpcSpacing.sm),
          Text(
            entry.name,
            style: elevated
                ? RpcTypography.statMedium(context)
                : RpcTypography.title(context),
          ),
          const SizedBox(height: RpcSpacing.xs),
          Text(skill, style: RpcTypography.bodySmallMuted(context)),
          SizedBox(height: elevated ? RpcSpacing.md : RpcSpacing.sm),
          Text(
            '${entry.winRate.toStringAsFixed(0)}%',
            style: (elevated
                    ? RpcTypography.stat(context)
                    : RpcTypography.statMedium(context))
                .copyWith(color: style.accent, height: 1),
          ),
          Text(
            'Win Rate',
            style: RpcTypography.caption(context),
          ),
          const SizedBox(height: RpcSpacing.md),
          Wrap(
            spacing: RpcSpacing.sm,
            runSpacing: RpcSpacing.sm,
            children: [
              RpcStatusBadge(
                label: 'WR ${entry.winRate.toStringAsFixed(0)}%',
                tone: RpcBadgeTone.success,
              ),
              RpcStatusBadge(
                label: 'W ${entry.wins}',
                tone: RpcBadgeTone.neutral,
              ),
              RpcStatusBadge(
                label: 'L ${entry.losses}',
                tone: RpcBadgeTone.neutral,
              ),
              RpcStatusBadge(
                label: 'M ${entry.matches}',
                tone: RpcBadgeTone.primary,
              ),
              RpcStatusBadge(
                label: 'PD ${formatPointDifferential(entry.pointDifferential)}',
                tone: entry.pointDifferential >= 0
                    ? RpcBadgeTone.success
                    : RpcBadgeTone.warning,
              ),
              if (entry.matches > 0)
                RpcStatusBadge(
                  label: 'Avg ${entry.avgMargin >= 0 ? '+' : ''}${entry.avgMargin.toStringAsFixed(1)}',
                  tone: RpcBadgeTone.neutral,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankMedallion extends StatelessWidget {
  const _RankMedallion({required this.rank, required this.tier});

  final int rank;
  final _PodiumTier tier;

  @override
  Widget build(BuildContext context) {
    final style = _tierStyle(context, tier);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: style.medal,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: style.medal.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: RpcTypography.labelSemibold(context).copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LeaderboardListTile extends StatelessWidget {
  const _LeaderboardListTile({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final skill = entry.skillLevel != null
        ? MatchModes.skillLabel(entry.skillLevel!)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RpcSpacing.md,
        vertical: RpcSpacing.md,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < RpcBreakpoints.compact;

          final rankBadge = Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.surfaceHover,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: RpcTypography.labelSemibold(context),
            ),
          );

          final playerInfo = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: RpcTypography.bodySemibold(context),
                ),
                if (skill != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    skill,
                    style: RpcTypography.bodySmallMuted(context),
                  ),
                ],
              ],
            ),
          );

          final stats = Wrap(
            spacing: RpcSpacing.sm,
            runSpacing: RpcSpacing.xs,
            alignment: WrapAlignment.end,
            children: [
              RpcStatusBadge(
                label: 'WR ${entry.winRate.toStringAsFixed(0)}%',
                tone: RpcBadgeTone.success,
              ),
              RpcStatusBadge(
                label: 'PD ${formatPointDifferential(entry.pointDifferential)}',
                tone: entry.pointDifferential >= 0
                    ? RpcBadgeTone.success
                    : RpcBadgeTone.warning,
              ),
              Text(
                'W ${entry.wins}  L ${entry.losses}  M ${entry.matches}',
                style: RpcTypography.caption(context),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    rankBadge,
                    const SizedBox(width: RpcSpacing.md),
                    playerInfo,
                  ],
                ),
                const SizedBox(height: RpcSpacing.sm),
                stats,
              ],
            );
          }

          return Row(
            children: [
              rankBadge,
              const SizedBox(width: RpcSpacing.md),
              playerInfo,
              const SizedBox(width: RpcSpacing.md),
              stats,
            ],
          );
        },
      ),
    );
  }
}

class _TierStyle {
  const _TierStyle({
    required this.background,
    required this.border,
    required this.medal,
    required this.accent,
    required this.rankLabel,
  });

  final Color background;
  final Color border;
  final Color medal;
  final Color accent;
  final String rankLabel;
}

_TierStyle _tierStyle(BuildContext context, _PodiumTier tier) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return switch (tier) {
    _PodiumTier.gold => _TierStyle(
        background: isDark
            ? const Color(0xFF3D3419)
            : const Color(0xFFFFFBEB),
        border: const Color(0xFFF59E0B),
        medal: const Color(0xFFF59E0B),
        accent: const Color(0xFFD97706),
        rankLabel: 'TOP RANK',
      ),
    _PodiumTier.silver => _TierStyle(
        background: isDark
            ? const Color(0xFF2A3140)
            : const Color(0xFFF8FAFC),
        border: const Color(0xFFCBD5E1),
        medal: const Color(0xFF94A3B8),
        accent: const Color(0xFF64748B),
        rankLabel: 'RANK 2',
      ),
    _PodiumTier.bronze => _TierStyle(
        background: isDark
            ? const Color(0xFF3D2C1F)
            : const Color(0xFFFFF7ED),
        border: const Color(0xFFFDBA74),
        medal: const Color(0xFFB45309),
        accent: const Color(0xFFC2410C),
        rankLabel: 'RANK 3',
      ),
  };
}
