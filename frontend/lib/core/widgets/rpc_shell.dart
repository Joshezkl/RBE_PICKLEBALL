import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import '../theme/theme_controller.dart';
import '../decor/rpc_court_background.dart';
import '../decor/rpc_decor_theme.dart';
import '../admin_pin_controller.dart';
import 'brand_logo.dart';
import 'rpc_responsive.dart';
import 'theme_toggle_button.dart';

enum RpcNavDestination {
  dashboard,
  players,
  tournaments,
  stats,
  history,
  revenue,
  displays,
  publicBoard,
  publicStats,
  // Legacy aliases used in a few call sites during migration
  sessionRankings,
  calendar,
  board,
  allTimeRankings,
}

class RpcShell extends StatelessWidget {
  const RpcShell({
    super.key,
    required this.body,
    this.activeDestination,
    this.pageTitle,
    this.pageSubtitle,
    this.actions = const [],
    this.themeController,
    this.onPlayersTap,
    this.adminPin,
    this.sessionId,
    this.loading = false,
    this.navDestinations = const [
      RpcNavDestination.dashboard,
      RpcNavDestination.players,
      RpcNavDestination.stats,
      RpcNavDestination.history,
      RpcNavDestination.displays,
    ],
    this.maxWidth = RpcSpacing.pageMaxWidth,
    this.dense = true,
    this.fillViewport = false,
    this.centerPageTitle = false,
    this.decorIntensity = RpcDecorIntensity.subtle,
  });

  final Widget body;
  final RpcNavDestination? activeDestination;
  final String? pageTitle;
  final String? pageSubtitle;
  final List<Widget> actions;
  final ThemeController? themeController;
  final VoidCallback? onPlayersTap;
  final String? adminPin;
  final int? sessionId;
  final bool loading;
  final List<RpcNavDestination> navDestinations;
  final double maxWidth;
  final bool dense;
  final bool fillViewport;
  final bool centerPageTitle;
  final RpcDecorIntensity decorIntensity;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final headerGap = dense ? RpcSpacing.md : RpcSpacing.lg;

    Widget pageContent({
      required bool scrollable,
      required EdgeInsets pagePadding,
    }) {
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pageTitle != null) ...[
            _PageHeader(
              title: pageTitle!,
              subtitle: pageSubtitle,
              dense: dense,
              centered: centerPageTitle,
            ),
            SizedBox(height: headerGap),
          ],
          if (scrollable) body else Expanded(child: body),
        ],
      );

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: scrollable
              ? column
              : SizedBox(
                  height: double.infinity,
                  child: column,
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _TopNavBar(
            activeDestination: activeDestination,
            destinations: navDestinations,
            actions: actions,
            themeController: themeController,
            onPlayersTap: onPlayersTap,
            adminPin: adminPin,
            sessionId: sessionId,
          ),
          Expanded(
            child: RpcCourtBackground(
              intensity: decorIntensity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pagePadding =
                      RpcLayout.pagePadding(constraints.maxWidth);
                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (fillViewport) {
                    return Padding(
                      padding: pagePadding,
                      child: pageContent(
                        scrollable: false,
                        pagePadding: pagePadding,
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: pagePadding,
                    child: pageContent(
                      scrollable: true,
                      pagePadding: pagePadding,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  const _TopNavBar({
    required this.activeDestination,
    required this.destinations,
    required this.actions,
    this.themeController,
    this.onPlayersTap,
    this.adminPin,
    this.sessionId,
  });

  final RpcNavDestination? activeDestination;
  final List<RpcNavDestination> destinations;
  final List<Widget> actions;
  final ThemeController? themeController;
  final VoidCallback? onPlayersTap;
  final String? adminPin;
  final int? sessionId;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
            boxShadow: [
              BoxShadow(
                color: c.text.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RpcSpacing.pagePaddingH,
                vertical: RpcSpacing.md,
              ),
              child: LayoutBuilder(
            builder: (context, constraints) {
              final useMenu = constraints.maxWidth < RpcBreakpoints.medium;
              final iconOnly = !useMenu &&
                  constraints.maxWidth < RpcBreakpoints.wide;
              final logoHeight = RpcLayout.navLogoHeight(constraints.maxWidth);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BrandLogo(height: logoHeight),
                  if (!useMenu) ...[
                    const SizedBox(width: RpcSpacing.md),
                    Container(
                      width: 1,
                      height: 40,
                      color: c.border.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: RpcSpacing.md),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < destinations.length; i++) ...[
                              if (i > 0) const SizedBox(width: RpcSpacing.sm),
                              _NavPill(
                                label: _labelFor(destinations[i]),
                                icon: _iconFor(destinations[i]),
                                active: activeDestination == destinations[i],
                                iconOnly: iconOnly,
                                onTap: () => _navigate(context, destinations[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    PopupMenuButton<RpcNavDestination>(
                      tooltip: 'Navigation',
                      icon: Icon(Icons.menu_rounded, color: c.textMuted),
                      onSelected: (dest) => _navigate(context, dest),
                      itemBuilder: (context) => destinations
                          .map(
                            (dest) => PopupMenuItem(
                              value: dest,
                              child: Text(_labelFor(dest)),
                            ),
                          )
                          .toList(),
                    ),
                    const Spacer(),
                  ],
                  ...actions,
                  if (themeController != null) ...[
                    const SizedBox(width: RpcSpacing.sm),
                    Material(
                      color: c.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(24),
                      child: ThemeToggleButton(controller: themeController!),
                    ),
                  ],
                ],
              );
            },
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 72,
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  colors: [
                    c.primary.withValues(alpha: 0),
                    c.primary.withValues(alpha: 0.35),
                    c.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _labelFor(RpcNavDestination dest) {
    return switch (dest) {
      RpcNavDestination.dashboard => 'Dashboard',
      RpcNavDestination.players => 'Players',
      RpcNavDestination.tournaments => 'Tournaments',
      RpcNavDestination.stats => 'Stats',
      RpcNavDestination.sessionRankings => 'Stats',
      RpcNavDestination.allTimeRankings => 'Stats',
      RpcNavDestination.history => 'History',
      RpcNavDestination.calendar => 'History',
      RpcNavDestination.revenue => 'Revenue',
      RpcNavDestination.displays => 'Displays',
      RpcNavDestination.board => 'Displays',
      RpcNavDestination.publicBoard => 'Board',
      RpcNavDestination.publicStats => 'Rankings',
    };
  }

  IconData _iconFor(RpcNavDestination dest) {
    return switch (dest) {
      RpcNavDestination.dashboard => Icons.dashboard_outlined,
      RpcNavDestination.players => Icons.people_outline_rounded,
      RpcNavDestination.tournaments => Icons.emoji_events_outlined,
      RpcNavDestination.stats => Icons.leaderboard_outlined,
      RpcNavDestination.sessionRankings => Icons.leaderboard_outlined,
      RpcNavDestination.allTimeRankings => Icons.leaderboard_outlined,
      RpcNavDestination.publicStats => Icons.leaderboard_outlined,
      RpcNavDestination.history => Icons.calendar_month_outlined,
      RpcNavDestination.calendar => Icons.calendar_month_outlined,
      RpcNavDestination.revenue => Icons.payments_outlined,
      RpcNavDestination.displays => Icons.cast_rounded,
      RpcNavDestination.board => Icons.cast_rounded,
      RpcNavDestination.publicBoard => Icons.tv_outlined,
    };
  }

  void _navigate(BuildContext context, RpcNavDestination dest) {
    if (dest == activeDestination) return;

    final pin = (adminPin != null && adminPin!.isNotEmpty)
        ? adminPin
        : rpcAdminPinController.pin;

    switch (dest) {
      case RpcNavDestination.dashboard:
        Navigator.pushReplacementNamed(context, '/admin');
      case RpcNavDestination.players:
        if (onPlayersTap != null) {
          onPlayersTap!();
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/admin/players',
            arguments: pin,
          );
        }
      case RpcNavDestination.tournaments:
        Navigator.pushReplacementNamed(
          context,
          '/admin/tournaments',
          arguments: pin,
        );
      case RpcNavDestination.stats:
      case RpcNavDestination.sessionRankings:
        Navigator.pushReplacementNamed(
          context,
          '/admin/stats',
          arguments: {
            'adminPin': pin,
            'sessionId': sessionId,
          },
        );
      case RpcNavDestination.history:
      case RpcNavDestination.calendar:
        Navigator.pushReplacementNamed(
          context,
          '/admin/history',
          arguments: pin,
        );
      case RpcNavDestination.revenue:
        Navigator.pushReplacementNamed(
          context,
          '/admin/revenue',
          arguments: pin,
        );
      case RpcNavDestination.displays:
        Navigator.pushReplacementNamed(
          context,
          '/admin/displays',
          arguments: pin,
        );
      case RpcNavDestination.board:
      case RpcNavDestination.publicBoard:
        Navigator.pushReplacementNamed(context, '/board');
      case RpcNavDestination.allTimeRankings:
      case RpcNavDestination.publicStats:
        Navigator.pushReplacementNamed(context, '/leaderboard');
    }
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.iconOnly = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final fg = active ? onPrimary : c.textMuted;

    final pill = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
        boxShadow: active
            ? [
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        border: active
            ? null
            : Border.all(color: c.border.withValues(alpha: 0.55)),
      ),
      child: Material(
        color: active
            ? c.primary
            : c.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 12 : 14,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                if (!iconOnly) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: RpcTypography.nav(context).copyWith(
                      color: fg,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (iconOnly) {
      return Tooltip(message: label, child: pill);
    }

    return pill;
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    this.subtitle,
    this.dense = true,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final bool dense;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: dense
              ? RpcTypography.headline(context)
              : RpcTypography.display(context),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: RpcSpacing.xs),
          Text(
            subtitle!,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: RpcTypography.bodySmallMuted(context),
          ),
        ],
      ],
    );
  }
}
