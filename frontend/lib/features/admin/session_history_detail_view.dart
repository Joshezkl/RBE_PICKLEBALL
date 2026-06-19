import 'package:flutter/material.dart';

import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_kpi_card.dart';
import '../../core/widgets/rpc_kpi_row.dart';
import '../../core/widgets/rpc_section_header.dart';
import '../../core/widgets/match_history_grid.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/widgets/rpc_responsive.dart';

class SessionHistoryDetailView extends StatefulWidget {
  const SessionHistoryDetailView({
    super.key,
    required this.detail,
    this.onExport,
    this.exporting = false,
  });

  final SessionHistoryDetail detail;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  State<SessionHistoryDetailView> createState() =>
      _SessionHistoryDetailViewState();
}

class _SessionHistoryDetailViewState extends State<SessionHistoryDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finishedMatches = widget.detail.matches
        .where((match) => match.status == 'finished')
        .toList();
    final sortedPlayers = [...widget.detail.players]
      ..sort((a, b) {
        final winsCmp = b.wins.compareTo(a.wins);
        if (winsCmp != 0) return winsCmp;
        return b.losses.compareTo(a.losses);
      });

    return RpcCard(
      padding: const EdgeInsets.all(RpcSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionOverviewHeader(
            detail: widget.detail,
            onExport: widget.onExport,
            exporting: widget.exporting,
          ),
          const SizedBox(height: RpcSpacing.sm),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Overview'),
              Tab(text: 'Matches (${finishedMatches.length})'),
              Tab(text: 'Players (${sortedPlayers.length})'),
            ],
          ),
          const SizedBox(height: RpcSpacing.sm),
          SizedBox(
            height: RpcLayout.dialogContentHeight(
              context,
              fraction: 0.45,
              min: 280,
              max: 480,
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  child: _OverviewTab(detail: widget.detail),
                ),
                SingleChildScrollView(
                  child: _MatchResultsSection(matches: finishedMatches),
                ),
                SingleChildScrollView(
                  child: _PlayersRosterSection(players: sortedPlayers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionOverviewHeader extends StatelessWidget {
  const _SessionOverviewHeader({
    required this.detail,
    this.onExport,
    this.exporting = false,
  });

  final SessionHistoryDetail detail;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final isActive = session.status != 'ended';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < RpcBreakpoints.compact;
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'View leaderboard',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pushNamed(
                context,
                '/leaderboard',
                arguments: detail.session.id,
              ),
              icon: const Icon(Icons.leaderboard_outlined, size: 20),
            ),
            if (onExport != null)
              exporting
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Export full session report (includes revenue)',
                      visualDensity: VisualDensity.compact,
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined, size: 20),
                    ),
          ],
        );

        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.name,
                    style: RpcTypography.bodySemibold(context),
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: RpcSpacing.sm),
                  RpcStatusBadge(
                    label: isActive ? 'Active' : 'Ended',
                    tone: isActive
                        ? RpcBadgeTone.success
                        : RpcBadgeTone.neutral,
                  ),
                ],
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 4),
              RpcStatusBadge(
                label: isActive ? 'Active' : 'Ended',
                tone:
                    isActive ? RpcBadgeTone.success : RpcBadgeTone.neutral,
              ),
            ],
            const SizedBox(height: 2),
            Text(
              '${session.matchModeLabel} · ${session.playFormat.toUpperCase()} · ${session.courtCount} courts',
              style: RpcTypography.caption(context),
            ),
            if (session.startedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Started ${_formatTimestamp(session.startedAt!)}'
                '${session.endedAt != null ? ' · Ended ${_formatTimestamp(session.endedAt!)}' : ''}',
                style: RpcTypography.caption(context),
              ),
            ],
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: RpcSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            const SizedBox(width: RpcSpacing.sm),
            actions,
          ],
        );
      },
    );
  }

  String _formatTimestamp(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final local = parsed.toLocal();
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_monthLabel(local.month)} ${local.day} · $hour:$minute $period';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

List<(int, SessionHistoryPlayer)> _topPlayers(List<SessionHistoryPlayer> players) {
  final sorted = [...players]..sort((a, b) => b.wins.compareTo(a.wins));
  return [
    for (var i = 0; i < sorted.length && i < 3; i++) (i + 1, sorted[i]),
  ];
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail});

  final SessionHistoryDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final session = detail.session;
    final report = detail.report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcKpiRow(
          compact: true,
          cards: [
            RpcKpiCard(
              label: 'Players',
              value: '${session.playerCount}',
              icon: Icons.people_outline_rounded,
              iconColor: c.primary,
              compact: true,
            ),
            RpcKpiCard(
              label: 'Matches',
              value: '${report.totalMatches}',
              icon: Icons.sports_tennis_rounded,
              iconColor: c.accentOrange,
              compact: true,
            ),
            RpcKpiCard(
              label: 'Duration',
              value: '${report.durationMinutes}m',
              icon: Icons.schedule_rounded,
              iconColor: c.accentPurple,
              compact: true,
            ),
            RpcKpiCard(
              label: 'Utilization',
              value: '${report.courtUtilizationPercent}%',
              icon: Icons.pie_chart_outline_rounded,
              iconColor: c.success,
              compact: true,
            ),
          ],
        ),
        if (detail.players.isNotEmpty) ...[
          const SizedBox(height: RpcSpacing.md),
          const RpcSectionHeader(
            title: 'Top performers',
            subtitle: 'By wins this session',
            compact: true,
          ),
          const SizedBox(height: RpcSpacing.sm),
          for (final entry in _topPlayers(detail.players))
            Padding(
              padding: const EdgeInsets.only(bottom: RpcSpacing.xs),
              child: _TopPlayerRow(
                rank: entry.$1,
                name: entry.$2.name,
                wins: entry.$2.wins,
                losses: entry.$2.losses,
              ),
            ),
        ],
      ],
    );
  }
}

class _TopPlayerRow extends StatelessWidget {
  const _TopPlayerRow({
    required this.rank,
    required this.name,
    required this.wins,
    required this.losses,
  });

  final int rank;
  final String name;
  final int wins;
  final int losses;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RpcSpacing.sm,
        vertical: RpcSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '#$rank',
              style: RpcTypography.caption(context).copyWith(
                color: c.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: RpcTypography.bodySemibold(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${wins}W ${losses}L',
            style: RpcTypography.caption(context),
          ),
        ],
      ),
    );
  }
}

class _MatchResultsSection extends StatelessWidget {
  const _MatchResultsSection({required this.matches});

  final List<MatchInfo> matches;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcSectionHeader(
          title: 'Match Results',
          subtitle: matches.isEmpty
              ? 'No completed matches yet'
              : '${matches.length} finished',
          compact: true,
          trailing: matches.isNotEmpty
              ? RpcStatusBadge(
                  label: '${matches.length}',
                  tone: RpcBadgeTone.primary,
                )
              : null,
        ),
        const SizedBox(height: RpcSpacing.sm),
        MatchHistoryGrid(
          matches: matches,
          emptyMessage: 'No finished matches',
          compact: true,
        ),
      ],
    );
  }
}

class _PlayersRosterSection extends StatelessWidget {
  const _PlayersRosterSection({required this.players});

  final List<SessionHistoryPlayer> players;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcSectionHeader(
          title: 'Players',
          subtitle: players.isEmpty
              ? 'No roster recorded'
              : '${players.length} participant${players.length == 1 ? '' : 's'}',
          compact: true,
          trailing: players.isNotEmpty
              ? RpcStatusBadge(
                  label: '${players.length}',
                  tone: RpcBadgeTone.neutral,
                )
              : null,
        ),
        const SizedBox(height: RpcSpacing.sm),
        if (players.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: RpcSpacing.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
              border: Border.all(color: c.border),
            ),
            child: Text(
              'No players recorded',
              style: RpcTypography.bodyMuted(context),
            ),
          )
        else
          ...players.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: RpcSpacing.xs),
              child: _PlayerRosterTile(player: player),
            ),
          ),
      ],
    );
  }
}

class _PlayerRosterTile extends StatelessWidget {
  const _PlayerRosterTile({required this.player});

  final SessionHistoryPlayer player;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final matches = player.wins + player.losses;
    final winRate = matches > 0 ? (player.wins / matches) * 100 : 0.0;
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RpcSpacing.sm,
        vertical: RpcSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: c.primaryLight,
            child: Text(
              initial,
              style: RpcTypography.caption(context).copyWith(
                color: c.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: RpcSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: RpcTypography.bodySemibold(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (player.skillLevel != null || player.gender != null)
                  Wrap(
                    spacing: RpcSpacing.xs,
                    runSpacing: 2,
                    children: [
                      if (player.skillLevel != null)
                        RpcStatusBadge(
                          label: MatchModes.skillLabel(player.skillLevel!),
                          tone: RpcBadgeTone.purple,
                        ),
                      if (player.gender != null)
                        RpcStatusBadge(
                          label: MatchModes.genderLabel(player.gender!),
                          tone: player.gender == 'female'
                              ? RpcBadgeTone.orange
                              : RpcBadgeTone.primary,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (matches > 0)
                Text(
                  '${winRate.toStringAsFixed(0)}% WR',
                  style: RpcTypography.caption(context).copyWith(
                    color: c.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                '${player.wins}W ${player.losses}L',
                style: RpcTypography.caption(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
