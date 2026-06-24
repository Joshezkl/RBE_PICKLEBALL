import 'package:flutter/material.dart';

import '../../core/adaptive_poll_timer.dart';
import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/widgets/leaderboard_view.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_error_banner.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/admin_nav.dart';
import '../../core/admin_pin_controller.dart';
import '../../main.dart' show rpcThemeController;

enum LeaderboardScope {
  /// Club-wide cumulative stats — shown on the public board for players.
  allTime,

  /// Rankings for one session only — shown in admin during / after a session.
  session,
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({
    super.key,
    this.scope = LeaderboardScope.session,
    this.adminPin,
    this.sessionId,
  });

  final LeaderboardScope scope;
  final String? adminPin;
  final int? sessionId;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final ApiClient _api;

  List<LeaderboardEntry> _overallEntries = [];
  List<LeaderboardEntry> _monthlyEntries = [];
  List<LeaderboardEntry> _seasonEntries = [];
  List<LeaderboardEntry> _sessionEntries = [];
  String? _sessionName;
  String? _monthlyLabel;
  String? _seasonLabel;
  int? _sessionId;
  bool _sessionAvailable = false;

  LeaderboardSortMode _sortMode = LeaderboardSortMode.overall;
  LeaderboardGenderFilter _genderFilter = LeaderboardGenderFilter.all;

  bool _loading = false;
  String? _error;
  AdaptivePollTimer? _pollTimer;

  int get _seasonYear => DateTime.now().year;

  List<LeaderboardEntry> get _activeEntries => switch (_sortMode) {
        LeaderboardSortMode.overall => _overallEntries,
        LeaderboardSortMode.thisMonth => _monthlyEntries,
        LeaderboardSortMode.season => _seasonEntries,
        LeaderboardSortMode.currentSession => _sessionEntries,
      };

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
    );
    _sessionId = widget.sessionId;
    _sortMode = widget.scope == LeaderboardScope.session
        ? LeaderboardSortMode.currentSession
        : LeaderboardSortMode.overall;
    _loadAll(silent: false);
    _pollTimer = AdaptivePollTimer(
      foregroundInterval: const Duration(seconds: 8),
      backgroundInterval: const Duration(seconds: 20),
      onPoll: () => _loadAll(silent: true),
    )..start();
  }

  @override
  void dispose() {
    _pollTimer?.stop();
    super.dispose();
  }

  Future<void> _loadAll({required bool silent}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _loading = _overallEntries.isEmpty &&
            _monthlyEntries.isEmpty &&
            _seasonEntries.isEmpty &&
            _sessionEntries.isEmpty;
        _error = null;
      });
    }

    try {
      final overallFuture = _api.getAllTimeLeaderboard();
      final monthlyFuture = _api.getMonthlyLeaderboard();
      final seasonFuture = _api.getSeasonLeaderboard(year: _seasonYear);
      final sessionFuture = _loadSessionEntries();
      final results = await Future.wait([
        overallFuture,
        monthlyFuture,
        seasonFuture,
        sessionFuture,
      ]);

      if (!mounted) return;
      final monthlyResult = results[1] as ({
        String label,
        List<LeaderboardEntry> entries,
      });
      final seasonResult = results[2] as ({
        String label,
        List<LeaderboardEntry> entries,
      });
      final sessionResult = results[3] as ({
        List<LeaderboardEntry> entries,
        String? sessionName,
        int? sessionId,
        bool available,
      });

      setState(() {
        _overallEntries = results[0] as List<LeaderboardEntry>;
        _monthlyEntries = monthlyResult.entries;
        _monthlyLabel = monthlyResult.label;
        _seasonEntries = seasonResult.entries;
        _seasonLabel = seasonResult.label;
        _sessionEntries = sessionResult.entries;
        _sessionName = sessionResult.sessionName;
        _sessionId = sessionResult.sessionId;
        _sessionAvailable = sessionResult.available;

        if (!_sessionAvailable &&
            _sortMode == LeaderboardSortMode.currentSession) {
          _sortMode = LeaderboardSortMode.overall;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<({
    List<LeaderboardEntry> entries,
    String? sessionName,
    int? sessionId,
    bool available,
  })> _loadSessionEntries() async {
    var sessionId = _sessionId;
    if (sessionId == null) {
      try {
        final state = await _api.getActiveSession();
        sessionId = state.session.id;
      } catch (_) {
        return (
          entries: <LeaderboardEntry>[],
          sessionName: null,
          sessionId: null,
          available: false,
        );
      }
    }

    final result = await _api.getSessionLeaderboard(sessionId);
    return (
      entries: result.entries,
      sessionName: result.sessionName,
      sessionId: result.sessionId,
      available: true,
    );
  }

  void _onSortChanged(LeaderboardSortMode mode) {
    if (mode == LeaderboardSortMode.currentSession && !_sessionAvailable) {
      return;
    }
    setState(() => _sortMode = mode);
  }

  void _onGenderFilterChanged(LeaderboardGenderFilter filter) {
    setState(() => _genderFilter = filter);
  }

  String get _title => 'Stats';

  String get _subtitle {
    const rankingNote = 'min. 3 matches · WR → PD → wins';
    return switch (_sortMode) {
      LeaderboardSortMode.currentSession when _sessionName != null =>
        '$_sessionName · $rankingNote',
      LeaderboardSortMode.thisMonth =>
        '${_monthlyLabel ?? 'This Month'} · $rankingNote',
      LeaderboardSortMode.season =>
        '${_seasonLabel ?? 'Season'} · $rankingNote',
      _ => 'Club-wide · $rankingNote',
    };
  }

  String get _emptyMessage {
    if (_sortMode == LeaderboardSortMode.currentSession && !_sessionAvailable) {
      return 'No active session — start a session or switch to Overall';
    }
    if (_genderFilter != LeaderboardGenderFilter.all) {
      final label = _genderFilter == LeaderboardGenderFilter.male
          ? 'male'
          : 'female';
      return 'No $label players with 3+ matches in this view';
    }
    return switch (_sortMode) {
      LeaderboardSortMode.currentSession =>
        'No players with 3+ matches in this session yet',
      LeaderboardSortMode.thisMonth =>
        'No players with 3+ matches this month yet',
      LeaderboardSortMode.season =>
        'No players with 3+ matches this season yet',
      _ => 'No players with 3+ matches yet',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isAdminContext = widget.scope == LeaderboardScope.session;

    return RpcShell(
      activeDestination: isAdminContext
          ? RpcNavDestination.stats
          : RpcNavDestination.publicStats,
      navDestinations:
          isAdminContext ? adminNavDestinations : publicNavDestinations,
      pageTitle: _title,
      pageSubtitle: _subtitle,
      themeController: rpcThemeController,
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
      sessionId: _sessionId,
      maxWidth: 1100,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _loadAll(silent: false),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: RpcSpacing.md),
              child: RpcErrorBanner(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ),
          RpcCard(
            child: LeaderboardView(
              entries: _activeEntries,
              sortMode: _sortMode,
              genderFilter: _genderFilter,
              sessionAvailable: _sessionAvailable,
              seasonYear: _seasonYear,
              loading: _loading && _activeEntries.isEmpty,
              emptyMessage: _emptyMessage,
              onSortChanged: _onSortChanged,
              onGenderFilterChanged: _onGenderFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}
