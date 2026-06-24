import 'package:flutter/material.dart';

import 'core/check_in_url.dart';
import 'core/page_visibility.dart';
import 'core/theme/rpc_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/admin/admin_page.dart';
import 'features/admin/calendar_page.dart';
import 'features/admin/displays_hub_page.dart';
import 'features/admin/leaderboard_page.dart';
import 'features/admin/tournament_page.dart';
import 'features/admin/revenue_page.dart';
import 'features/admin/players_page.dart';
import 'features/board/board_page.dart';
import 'features/display/court_signage_page.dart';
import 'features/display/display_page.dart';
import 'features/display/tournament_display_page.dart';
import 'core/display_url.dart';
import 'features/check_in/check_in_page.dart';
import 'features/check_in/queue_status_page.dart';

final rpcThemeController = ThemeController();

void main() {
  runApp(const RpcApp());
}

class RpcApp extends StatefulWidget {
  const RpcApp({super.key});

  @override
  State<RpcApp> createState() => _RpcAppState();
}

class _RpcAppState extends State<RpcApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    rpcThemeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    rpcThemeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => true,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };
    rpcPageVisibility.setVisible(visible);
  }

  void _onThemeChanged() => setState(() {});

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final name = normalizeRouteName(settings.name);
    final args = settings.arguments;

    Widget page;
    switch (name) {
      case '/admin':
        page = const AdminPage();
      case '/admin/players':
        page = PlayersPage(adminPin: args as String?);
      case '/admin/tournaments':
        page = TournamentPage(adminPin: args as String?);
      case '/admin/stats':
      case '/admin/leaderboard':
        if (args is Map<String, dynamic>) {
          page = LeaderboardPage(
            scope: LeaderboardScope.session,
            adminPin: args['adminPin'] as String?,
            sessionId: args['sessionId'] as int?,
          );
        } else {
          page = const LeaderboardPage(scope: LeaderboardScope.session);
        }
      case '/admin/history':
      case '/admin/calendar':
        page = CalendarPage(adminPin: args as String?);
      case '/admin/displays':
        page = DisplaysHubPage(adminPin: args as String?);
      case '/admin/revenue':
        page = RevenuePage(adminPin: args as String?);
      case '/leaderboard':
        final sessionId = args as int?;
        page = sessionId != null
            ? LeaderboardPage(
                scope: LeaderboardScope.session,
                sessionId: sessionId,
              )
            : const LeaderboardPage(scope: LeaderboardScope.allTime);
      case '/board':
        page = const BoardPage();
      case '/display':
        page = const DisplayPage();
      case '/tournament-display':
        page = const TournamentDisplayPage();
      case '/court':
        page = CourtSignagePage(courtNumber: courtNumberFromUri());
      case '/check-in':
        page = CheckInPage(
          token: args is String ? args : checkInTokenFromUri(),
        );
      case '/queue-status':
        page = QueueStatusPage(
          token: args is String ? args : checkInTokenFromUri(),
        );
      default:
        page = const AdminPage();
    }

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name, arguments: args),
      builder: (_) => page,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rosales Pickleball Club',
      debugShowCheckedModeBanner: false,
      theme: RpcTheme.light,
      darkTheme: RpcTheme.dark,
      themeMode: rpcThemeController.mode,
      themeAnimationDuration: const Duration(milliseconds: 250),
      themeAnimationCurve: Curves.easeInOut,
      initialRoute: resolveInitialRoute(),
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: _onGenerateRoute,
    );
  }
}
