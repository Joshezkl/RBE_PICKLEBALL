import 'package:flutter/material.dart';

import '../../core/decor/rpc_decor_empty_state.dart';
import '../../core/decor/rpc_decor_theme.dart';
import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/session_controller.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/check_in_qr_panel.dart';
import '../../core/widgets/court_card_wrap.dart';
import '../../core/widgets/rpc_responsive.dart';
import '../../core/admin_nav.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../main.dart' show rpcThemeController;

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  late final SessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SessionController();
    _controller.initialize(readOnly: true);
    _controller.addListener(_onUpdate);
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return RpcShell(
      activeDestination: RpcNavDestination.publicBoard,
      decorIntensity: RpcDecorIntensity.venue,
      pageTitle: state?.session.name ?? 'Live Board',
      pageSubtitle: state != null
          ? '${state.session.matchModeLabel} · Public display'
          : 'Waiting for an active session',
      themeController: rpcThemeController,
      loading: _controller.loading && state == null,
      navDestinations: publicNavDestinations,
      actions: [
        IconButton(
          tooltip: 'Venue displays',
          onPressed: () => Navigator.pushNamed(context, '/admin/displays'),
          icon: const Icon(Icons.cast_rounded),
        ),
        IconButton(
          tooltip: 'TV display mode',
          onPressed: () => Navigator.pushReplacementNamed(context, '/display'),
          icon: const Icon(Icons.fullscreen_rounded),
        ),
        if (state != null) const _LiveBadge(),
        if (state?.session.checkInToken != null)
          IconButton(
            tooltip: 'Player check-in QR',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                insetPadding: RpcLayout.dialogInsetPadding(context),
                child: ConstrainedBox(
                  constraints: RpcLayout.dialogConstraints(
                    context,
                    maxWidth: 560,
                  ),
                  child: CheckInQrPanel(
                    sessionName: state!.session.name,
                    checkInToken: state.session.checkInToken!,
                  ),
                ),
              ),
            ),
          ),
      ],
      body: state == null
          ? const _EmptyState()
          : LayoutBuilder(
              builder: (context, constraints) {
                final slotsPerTeam =
                    state.session.playFormat == 'singles' ? 1 : 2;
                final isWide = constraints.maxWidth >= RpcBreakpoints.wide;

                if (isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _CourtsPanel(
                              courts: state.courts,
                              slotsPerTeam: slotsPerTeam,
                              challengeCourtIsOpen: state.challengeCourt.isOpen,
                            ),
                          ),
                          const SizedBox(width: RpcSpacing.lg),
                          Expanded(
                            flex: 2,
                            child: _QueueSidebar(
                              queues: state.queues,
                              queueTypes: state.session.queueTypes,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RpcSpacing.lg),
                      _UpNextPanel(
                        upNext: state.upNext,
                        slotsPerTeam: slotsPerTeam,
                      ),
                      const SizedBox(height: RpcSpacing.md),
                      const _ManualAssignBanner(),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CourtsPanel(
                      courts: state.courts,
                      slotsPerTeam: slotsPerTeam,
                      challengeCourtIsOpen: state.challengeCourt.isOpen,
                    ),
                    const SizedBox(height: RpcSpacing.lg),
                    _QueueSidebar(
                      queues: state.queues,
                      queueTypes: state.session.queueTypes,
                    ),
                    const SizedBox(height: RpcSpacing.lg),
                    _UpNextPanel(
                      upNext: state.upNext,
                      slotsPerTeam: slotsPerTeam,
                    ),
                    const SizedBox(height: RpcSpacing.md),
                    const _ManualAssignBanner(),
                  ],
                );
              },
            ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return const RpcStatusBadge(label: 'Live', tone: RpcBadgeTone.success);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: RpcDecorEmptyState(
        title: 'No Active Session',
        subtitle: 'Start a session from the admin dashboard',
        icon: Icons.event_busy_outlined,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: c.text),
          const SizedBox(width: 8),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: RpcTypography.title(context)),
            if (subtitle != null)
              Text(subtitle!, style: RpcTypography.bodyMuted(context)),
          ],
        ),
      ],
    );
  }
}

class _CourtsPanel extends StatelessWidget {
  const _CourtsPanel({
    required this.courts,
    required this.slotsPerTeam,
    required this.challengeCourtIsOpen,
  });

  final List<CourtInfo> courts;
  final int slotsPerTeam;
  final bool challengeCourtIsOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Courts'),
        const SizedBox(height: 14),
        CourtCardWrap(
          courts: courts,
          slotsPerTeam: slotsPerTeam,
          dense: true,
          maxColumns: 2,
          challengeCourtIsOpen: challengeCourtIsOpen,
        ),
      ],
    );
  }
}

class _QueueSidebar extends StatelessWidget {
  const _QueueSidebar({
    required this.queues,
    required this.queueTypes,
  });

  final Map<String, List<QueuePlayer>> queues;
  final List<String> queueTypes;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(color: c.border),
        boxShadow: [c.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < queueTypes.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: c.border,
                ),
              Expanded(
                child: _QueueColumn(
                  title: _queueTitle(queueTypes[i]),
                  count: (queues[queueTypes[i]] ?? []).length,
                  players: queues[queueTypes[i]] ?? [],
                  headerColor: MatchModes.headerBackgroundForQueue(
                    context,
                    queueTypes[i],
                  ),
                  accentColor: MatchModes.accentForQueue(context, queueTypes[i]),
                  icon: _queueIcon(queueTypes[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _queueTitle(String queueType) {
    return switch (queueType) {
      'winner' => 'Winners',
      'loser' => 'Losers',
      'beginner' => 'Beginner',
      'novice' => 'Novice',
      'intermediate' => 'Intermediate',
      'advanced' => 'Advanced',
      _ => queueType,
    };
  }

  IconData _queueIcon(String queueType) {
    return switch (queueType) {
      'winner' => Icons.emoji_events_outlined,
      'loser' => Icons.shield_outlined,
      'beginner' => Icons.school_outlined,
      'novice' => Icons.auto_graph_outlined,
      'intermediate' => Icons.trending_up_rounded,
      'advanced' => Icons.workspace_premium_outlined,
      _ => Icons.groups_outlined,
    };
  }
}

class _QueueColumn extends StatelessWidget {
  const _QueueColumn({
    required this.title,
    required this.count,
    required this.players,
    required this.headerColor,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final int count;
  final List<QueuePlayer> players;
  final Color headerColor;
  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: headerColor,
          child: Row(
            children: [
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title ($count)',
                  style: RpcTypography.bodyBold(context).copyWith(
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: players.isEmpty
              ? Text('Empty', style: RpcTypography.bodyMuted(context))
              : Column(
                  children: players.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _QueuePlayerRow(
                        position: p.position,
                        name: p.name,
                        accentColor: accentColor,
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _QueuePlayerRow extends StatelessWidget {
  const _QueuePlayerRow({
    required this.position,
    required this.name,
    required this.accentColor,
  });

  final int position;
  final String name;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$position',
              style: RpcTypography.bodyBold(context).copyWith(color: accentColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: RpcTypography.bodySemibold(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpNextPanel extends StatelessWidget {
  const _UpNextPanel({
    required this.upNext,
    required this.slotsPerTeam,
  });

  final List<UpNextGroup> upNext;
  final int slotsPerTeam;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final winnerGroup = upNext.where((g) => g.queueType == 'winner').firstOrNull;
    final loserGroup = upNext.where((g) => g.queueType == 'loser').firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Up Next',
          subtitle: 'Next matches in queue',
          icon: Icons.schedule_rounded,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth >= RpcBreakpoints.compact;
            final winnerCard = _UpNextQueueCard(
              title: 'Winners — Up Next',
              group: winnerGroup,
              slotsPerTeam: slotsPerTeam,
              headerColor: MatchModes.headerBackgroundForQueue(context, 'winner'),
              accentColor: c.success,
              icon: Icons.emoji_events_outlined,
            );
            final loserCard = _UpNextQueueCard(
              title: 'Losers — Up Next',
              group: loserGroup,
              slotsPerTeam: slotsPerTeam,
              headerColor: MatchModes.headerBackgroundForQueue(context, 'loser'),
              accentColor: c.danger,
              icon: Icons.shield_outlined,
            );

            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: winnerCard),
                  const SizedBox(width: 14),
                  Expanded(child: loserCard),
                ],
              );
            }
            return Column(
              children: [
                winnerCard,
                const SizedBox(height: 14),
                loserCard,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UpNextQueueCard extends StatelessWidget {
  const _UpNextQueueCard({
    required this.title,
    required this.group,
    required this.slotsPerTeam,
    required this.headerColor,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final UpNextGroup? group;
  final int slotsPerTeam;
  final Color headerColor;
  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final players = group?.players ?? [];
    final ready = group?.ready ?? false;
    final displayCount = slotsPerTeam == 1 ? 1 : 4;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(color: c.border),
        boxShadow: [c.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: headerColor,
            child: Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: RpcTypography.bodySemibold(context).copyWith(
                      color: accentColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ready ? 'Ready' : 'Waiting',
                    style: RpcTypography.bodySemibold(context).copyWith(
                      color: ready ? c.success : c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: players.isEmpty
                ? Text(
                    'No players in queue',
                    style: RpcTypography.bodyMuted(context),
                  )
                : _UpNextPlayerGrid(
                    players: players.take(displayCount).toList(),
                    badgeColor: accentColor,
                  ),
          ),
        ],
      ),
    );
  }
}

class _UpNextPlayerGrid extends StatelessWidget {
  const _UpNextPlayerGrid({
    required this.players,
    required this.badgeColor,
  });

  final List<QueuePlayer> players;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < players.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 6));
      rows.add(
        Row(
          children: [
            Expanded(
              child: _UpNextPlayerRow(
                position: players[i].position,
                name: players[i].name,
                badgeColor: badgeColor,
              ),
            ),
            if (i + 1 < players.length) ...[
              const SizedBox(width: 6),
              Expanded(
                child: _UpNextPlayerRow(
                  position: players[i + 1].position,
                  name: players[i + 1].name,
                  badgeColor: badgeColor,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

class _UpNextPlayerRow extends StatelessWidget {
  const _UpNextPlayerRow({
    required this.position,
    required this.name,
    required this.badgeColor,
  });

  final int position;
  final String name;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$position',
              style: RpcTypography.bodyBold(context).copyWith(color: badgeColor),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: RpcTypography.bodySemibold(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualAssignBanner extends StatelessWidget {
  const _ManualAssignBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Courts are assigned manually by the queue master. Players enter a court only when the admin assigns them.',
              style: RpcTypography.bodyRelaxed(context),
            ),
          ),
        ],
      ),
    );
  }
}
