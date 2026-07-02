import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_nav.dart';
import 'tournament_bracket_view.dart';
import 'tournament_admin_register_panel.dart';
import '../../core/admin_pin_controller.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/rpc_session_controller.dart';
import '../../core/tournament_models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/court_match_layout.dart';
import '../../core/widgets/tournament_court_helpers.dart';
import '../../core/widgets/tournament_up_next_strip.dart';
import '../../core/widgets/edit_court_count_dialog.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_error_banner.dart';
import '../../core/widgets/collapsible_section.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/widgets/rpc_responsive.dart';
import '../../core/decor/rpc_decor_empty_state.dart';
import '../../main.dart' show rpcThemeController;

class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key, this.adminPin});

  final String? adminPin;

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  static _TournamentPageSnapshot? _snapshot;

  final ApiClient _api = rpcApiClient;
  List<TournamentListItem> _tournaments = [];
  List<TournamentCategoryDivisionGroup> _categoryGroups = [];
  TournamentState? _active;
  bool _loading = true;
  String? _error;
  final _selectedTournamentIds = <int>{};
  final _pendingTournamentDeleteIds = <int>{};

  @override
  void initState() {
    super.initState();
    final pin = widget.adminPin ?? rpcAdminPinController.pin;
    _api.setAdminPin(pin);

    final cached = _snapshot;
    if (cached != null && cached.isFresh) {
      _tournaments = cached.tournaments;
      _categoryGroups = cached.categoryGroups;
      _active = cached.active;
      _loading = false;
    }

    _load(silent: cached != null && cached.isFresh);
  }

  Future<void> _load({
    int? selectId,
    bool silent = false,
    bool force = false,
  }) async {
    if (!silent) {
      setState(() {
        _loading = _tournaments.isEmpty && _active == null;
        _error = null;
      });
    }
    try {
      final list = await _api.listTournaments(force: force);
      TournamentState? active;
      if (selectId != null) {
        active = await _api.getTournament(selectId, force: force);
      } else if (_active != null) {
        active = await _api.getTournament(_active!.tournament.id, force: force);
      }
      if (mounted) {
        setState(() {
          _tournaments = list.tournaments;
          _categoryGroups = list.categoryGroups;
          _active = active;
        });
        _snapshot = _TournamentPageSnapshot(
          tournaments: _tournaments,
          categoryGroups: _categoryGroups,
          active: _active,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTournament() async {
    final result = await showDialog<_CreateTournamentResult>(
      context: context,
      builder: (context) => _CreateTournamentDialog(
        categoryGroups: _categoryGroups,
      ),
    );
    if (result == null) return;

    try {
      final state = await _api.createTournament(
        name: result.name,
        groupCount: result.groupCount,
        categories: result.categories,
        courtCount: result.courtCount,
      );
      if (mounted) {
        setState(() => _active = state);
        await _load(selectId: state.tournament.id);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _startTournament() async {
    final active = _active;
    if (active == null) return;
    try {
      final state = await _api.startTournament(active.tournament.id);
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _editCourtCount() async {
    final active = _active;
    if (active == null) return;

    final current = active.tournament.courtCount;
    final selected = await showEditCourtCountDialog(
      context,
      currentCount: current,
    );
    if (selected == null || selected == current) return;

    try {
      final state = await _api.updateTournament(
        active.tournament.id,
        courtCount: selected,
      );
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _assignCourt(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) async {
    final active = _active;
    if (active == null || candidates.isEmpty) return;

    final selected = await showDialog<TournamentUpNextMatchInfo>(
      context: context,
      builder: (context) => _TournamentAssignCourtDialog(
        courtNumber: court.courtNumber,
        preferredGroupLabel: court.preferredGroupLabel,
        matches: tournamentCandidatesForCourt(
          candidates,
          court.preferredGroupKey,
        ),
      ),
    );
    if (selected == null) return;

    try {
      final state = await _api.assignTournamentCourtMatch(
        active.tournament.id,
        selected.id,
        courtNumber: court.courtNumber,
      );
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _replaceCourt(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) async {
    final active = _active;
    if (active == null || !court.hasMatch || candidates.isEmpty) return;

    final currentMatchId = court.match?.id;
    final filtered = tournamentCandidatesForCourt(
      candidates,
      court.preferredGroupKey,
      excludeMatchId: currentMatchId,
    );
    if (filtered.isEmpty) return;

    final selected = await showDialog<TournamentUpNextMatchInfo>(
      context: context,
      builder: (context) => _TournamentAssignCourtDialog(
        courtNumber: court.courtNumber,
        preferredGroupLabel: court.preferredGroupLabel,
        replacing: true,
        matches: filtered,
      ),
    );
    if (selected == null) return;

    try {
      final state = await _api.replaceTournamentCourtMatch(
        active.tournament.id,
        selected.id,
        courtNumber: court.courtNumber,
      );
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _handleCourtTap(
    TournamentCourtInfo court,
    TournamentMatchInfo? match,
  ) async {
    if (!court.isActive || match == null || !match.canScore) return;
    await _scoreMatch(match);
  }

  Future<void> _scoreMatch(TournamentMatchInfo match) async {
    final active = _active;
    if (active == null) return;

    final scores = await showDialog<({int a, int b})>(
      context: context,
      builder: (context) => _TournamentScoreDialog(match: match),
    );
    if (scores == null) return;

    try {
      final state = await _api.scoreTournamentMatch(
        active.tournament.id,
        match.id,
        scoreA: scores.a,
        scoreB: scores.b,
      );
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _drawLotsForCategory(
    String categoryKey, {
    required List<String> playerNames,
    List<String>? genders,
  }) async {
    final active = _active;
    if (active == null) return;

    try {
      final result = await _api.drawLotsTournamentTeams(
        active.tournament.id,
        categoryKey,
        playerNames: playerNames,
        genders: genders,
      );
      if (mounted) setState(() => _active = result.state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      rethrow;
    }
  }

  Future<void> _addTeamToCategory(
    String categoryKey,
    List<String> playerNames,
  ) async {
    final active = _active;
    if (active == null) return;

    final definition = active.availableCategories
        .where((row) => row.key == categoryKey)
        .firstOrNull;
    if (definition == null) {
      if (mounted) {
        setState(() => _error = 'Unknown category: $categoryKey');
      }
      return;
    }

    try {
      final genders = List.generate(
        playerNames.length,
        (i) => tournamentGenderForPlayerSlot(definition, i),
      );

      final state = await _api.registerTournamentTeam(
        active.tournament.id,
        categoryKey,
        playerNames: playerNames,
        genders: genders,
      );
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _removeTeam(TournamentTeamInfo team) async {
    final active = _active;
    if (active == null) return;

    final isLive = active.tournament.isLive;
    final confirmed = isLive
        ? await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove participant?'),
              content: Text(
                'Remove "${team.displayName}" from the tournament? '
                'Unplayed matches will be cancelled.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.rpc.danger,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          )
        : true;

    if (confirmed != true) return;

    try {
      final state = await _api.removeTournamentTeam(active.tournament.id, team.id);
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _editPlayerName(int clubPlayerId, String currentName) async {
    final active = _active;
    if (active == null) return;

    final updated = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: currentName);
        return AlertDialog(
          title: const Text('Edit participant name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Correct spelling or updated name',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updated == null || updated.isEmpty || updated == currentName) return;

    try {
      final state = await _api.updateTournamentPlayerName(
        active.tournament.id,
        clubPlayerId,
        updated,
      );
      if (mounted) setState(() => _active = state);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmBulkDeleteTournaments() async {
    if (_selectedTournamentIds.isEmpty) return;

    final selectedTournaments = _tournaments
        .where((tournament) => _selectedTournamentIds.contains(tournament.id))
        .toList();
    final count = selectedTournaments.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove tournaments'),
        content: Text(
          count == 1
              ? 'Remove "${selectedTournaments.first.name}"? All teams, matches, and bracket data will be permanently deleted.'
              : 'Remove $count tournaments? All teams, matches, and bracket data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.rpc.danger,
            ),
            child: Text(count == 1 ? 'Remove' : 'Remove $count'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ids = selectedTournaments.map((tournament) => tournament.id).toList();
    setState(() {
      _pendingTournamentDeleteIds.addAll(ids);
      _error = null;
    });

    final previous = _tournaments;
    final failedEntries = <String>[];
    final deletedIds = <int>{};

    for (final tournament in selectedTournaments) {
      try {
        await _api.deleteTournament(tournament.id);
        deletedIds.add(tournament.id);
      } catch (e) {
        final reason = e is ApiException ? e.message : 'Delete failed';
        failedEntries.add('${tournament.name}: $reason');
      }
    }

    if (!mounted) return;

    setState(() {
      _tournaments = _tournaments
          .where((tournament) => !deletedIds.contains(tournament.id))
          .toList();
      _selectedTournamentIds.removeAll(deletedIds);
      _pendingTournamentDeleteIds.removeAll(ids);

      if (deletedIds.contains(_active?.tournament.id)) {
        _active = null;
      }

      if (failedEntries.isEmpty) {
        _error = null;
      } else if (deletedIds.isEmpty) {
        _tournaments = previous;
        _error = failedEntries.join('\n');
      } else {
        _error =
            'Removed ${deletedIds.length} tournament(s).\n${failedEntries.join('\n')}';
      }
    });

    if (failedEntries.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedIds.length == 1
                ? 'Tournament removed'
                : '${deletedIds.length} tournaments removed',
          ),
        ),
      );
    }
  }

  void _toggleTournamentSelection(int tournamentId, bool selected) {
    setState(() {
      if (selected) {
        _selectedTournamentIds.add(tournamentId);
      } else {
        _selectedTournamentIds.remove(tournamentId);
      }
    });
  }

  void _selectAllTournaments() {
    setState(() {
      _selectedTournamentIds.addAll(_tournaments.map((tournament) => tournament.id));
    });
  }

  void _clearTournamentSelection() {
    setState(() => _selectedTournamentIds.clear());
  }

  bool get _allTournamentsSelected =>
      _tournaments.isNotEmpty &&
      _tournaments.every(
        (tournament) => _selectedTournamentIds.contains(tournament.id),
      );

  @override
  Widget build(BuildContext context) {
    return RpcShell(
      activeDestination: RpcNavDestination.tournaments,
      pageTitle: 'Tournaments',
      pageSubtitle: 'Round robin → playoffs · by category',
      themeController: rpcThemeController,
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
      navDestinations: adminNavDestinations,
      maxWidth: _active == null ? 960 : RpcSpacing.pageMaxWidth,
      fillViewport: _active == null,
      loading: _loading && _active == null && _tournaments.isEmpty,
      actions: [
        if (_active != null)
          TextButton.icon(
            onPressed: () => setState(() => _active = null),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('All tournaments'),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : () => _load(force: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (_active == null)
          FilledButton.icon(
            onPressed: _createTournament,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New tournament'),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            RpcErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
          if (_active != null)
            _TournamentDetailView(
              state: _active!,
              onStart: _startTournament,
              onAddTeam: _addTeamToCategory,
              onDrawLots: _drawLotsForCategory,
              onRemoveTeam: _removeTeam,
              onEditPlayer: _editPlayerName,
              onScoreMatch: _scoreMatch,
              onAssignCourt: _assignCourt,
              onReplaceCourt: _replaceCourt,
              onCourtTap: _handleCourtTap,
              onEditCourtCount: _editCourtCount,
            )
          else
            Expanded(
              child: _TournamentListView(
                tournaments: _tournaments,
                selectedIds: _selectedTournamentIds,
                pendingIds: _pendingTournamentDeleteIds,
                allSelected: _allTournamentsSelected,
                onSelect: (id) => _load(selectId: id),
                onSelectionChanged: _toggleTournamentSelection,
                onSelectAll: _selectAllTournaments,
                onClearSelection: _clearTournamentSelection,
                onBulkDelete: _confirmBulkDeleteTournaments,
              ),
            ),
        ],
      ),
    );
  }
}

class _TournamentListView extends StatelessWidget {
  const _TournamentListView({
    required this.tournaments,
    required this.selectedIds,
    required this.pendingIds,
    required this.allSelected,
    required this.onSelect,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onBulkDelete,
  });

  final List<TournamentListItem> tournaments;
  final Set<int> selectedIds;
  final Set<int> pendingIds;
  final bool allSelected;
  final ValueChanged<int> onSelect;
  final void Function(int tournamentId, bool selected) onSelectionChanged;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    if (tournaments.isEmpty) {
      return const RpcDecorEmptyState(
        title: 'No tournaments yet',
        subtitle: 'Create a tournament to register players and run group play.',
        icon: Icons.emoji_events_outlined,
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcSelectionToolbar(
          leading: [
            TextButton(
              onPressed: allSelected ? onClearSelection : onSelectAll,
              child: Text(allSelected ? 'Clear selection' : 'Select all'),
            ),
            if (selectedIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '${selectedIds.length} selected',
                style: RpcTypography.bodyMuted(context),
              ),
            ],
          ],
          action: FilledButton.icon(
            onPressed: selectedIds.isEmpty ||
                    selectedIds.any(pendingIds.contains)
                ? null
                : onBulkDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete selected'),
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: RpcPalette.onPrimaryForeground,
            ),
          ),
        ),
        const SizedBox(height: RpcSpacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: tournaments.length,
            separatorBuilder: (_, __) => const SizedBox(height: RpcSpacing.sm),
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return _TournamentListCard(
                tournament: tournament,
                selected: selectedIds.contains(tournament.id),
                pending: pendingIds.contains(tournament.id),
                onSelect: () => onSelect(tournament.id),
                onSelectionChanged: (selected) =>
                    onSelectionChanged(tournament.id, selected),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TournamentListCard extends StatelessWidget {
  const _TournamentListCard({
    required this.tournament,
    required this.selected,
    required this.pending,
    required this.onSelect,
    required this.onSelectionChanged,
  });

  final TournamentListItem tournament;
  final bool selected;
  final bool pending;
  final VoidCallback onSelect;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusMeta(tournament.status);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RpcSpacing.sm,
          vertical: RpcSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark ? c.elevatedSurface : c.surface,
          borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
          border: Border.all(
            color: c.border.withValues(alpha: isDark ? 0.85 : 1),
          ),
          boxShadow: isDark ? null : [c.cardShadow],
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: pending
                  ? null
                  : (value) => onSelectionChanged(value ?? false),
            ),
            Expanded(
              child: InkWell(
                onTap: onSelect,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.emoji_events_outlined,
                        size: 20,
                        color: c.primary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: RpcSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tournament.name,
                            style: RpcTypography.bodySemibold(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: RpcSpacing.xs,
                            runSpacing: RpcSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              RpcStatusBadge(
                                label: status.label,
                                tone: status.tone,
                              ),
                              Text(
                                '${tournament.groupCount} groups',
                                style: RpcTypography.caption(context).copyWith(
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (pending)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: c.textMuted,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, RpcBadgeTone tone}) _statusMeta(String status) {
    return switch (status) {
      'draft' || 'setup' => (label: 'Setup', tone: RpcBadgeTone.neutral),
      'round_robin' => (
          label: 'Round robin',
          tone: RpcBadgeTone.primary,
        ),
      'single_elimination' => (
          label: 'Playoffs',
          tone: RpcBadgeTone.warning,
        ),
      'final_round_robin' => (
          label: 'Final RR',
          tone: RpcBadgeTone.warning,
        ),
      'completed' => (label: 'Completed', tone: RpcBadgeTone.success),
      _ => (label: status, tone: RpcBadgeTone.neutral),
    };
  }
}

class _TournamentDetailView extends StatelessWidget {
  const _TournamentDetailView({
    required this.state,
    required this.onStart,
    required this.onAddTeam,
    required this.onDrawLots,
    required this.onRemoveTeam,
    required this.onEditPlayer,
    required this.onScoreMatch,
    required this.onAssignCourt,
    required this.onReplaceCourt,
    required this.onCourtTap,
    required this.onEditCourtCount,
  });

  final TournamentState state;
  final VoidCallback onStart;
  final Future<void> Function(String categoryKey, List<String> playerNames)
      onAddTeam;
  final Future<void> Function(
    String categoryKey, {
    required List<String> playerNames,
    List<String>? genders,
  }) onDrawLots;
  final ValueChanged<TournamentTeamInfo> onRemoveTeam;
  final Future<void> Function(int clubPlayerId, String currentName) onEditPlayer;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;
  final Future<void> Function(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) onAssignCourt;
  final Future<void> Function(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) onReplaceCourt;
  final void Function(TournamentCourtInfo court, TournamentMatchInfo? match)
      onCourtTap;
  final VoidCallback onEditCourtCount;

  @override
  Widget build(BuildContext context) {
    final t = state.tournament;
    final c = context.rpc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _statusMeta(t.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcCard.compact(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      t.status == 'completed'
                          ? Icons.emoji_events_rounded
                          : Icons.emoji_events_outlined,
                      size: 18,
                      color: t.status == 'completed'
                          ? c.warning
                          : c.primary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: RpcSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: RpcTypography.headline(context).copyWith(
                            fontSize: RpcTypeScale.subtitle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t.groupCount} groups · 1 advances each · ${t.courtCount} courts · RR → playoffs',
                          style: RpcTypography.caption(context).copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RpcStatusBadge(label: status.label, tone: status.tone),
                ],
              ),
              if (state.activeCategories.length > 1) ...[
                for (final category in state.activeCategories)
                  if (category.placements.isNotEmpty) ...[
                    const SizedBox(height: RpcSpacing.sm),
                    _TournamentPodium(
                      placements: category.placements,
                      categoryLabel: category.label,
                      compact: true,
                    ),
                  ],
              ],
              if (t.canEdit) ...[
                const SizedBox(height: RpcSpacing.sm),
                FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start tournament'),
                ),
              ],
            ],
          ),
        ),
        if (!t.canEdit && state.display != null) ...[
          const SizedBox(height: RpcSpacing.md),
          _TournamentCourtsPanel(
            display: state.display!,
            state: state,
            courtCount: t.courtCount,
            onAssignCourt: onAssignCourt,
            onReplaceCourt: onReplaceCourt,
            onCourtTap: onCourtTap,
            onEditCourtCount: onEditCourtCount,
          ),
        ],
        const SizedBox(height: RpcSpacing.md),
        ...state.activeCategories.map(
          (category) => Padding(
            padding: const EdgeInsets.only(bottom: RpcSpacing.md),
            child: _CategoryPanel(
              category: category,
              categoryDefinition: state.availableCategories
                  .where((row) => row.key == category.key)
                  .firstOrNull,
              canEdit: t.canEdit,
              canManageParticipants: t.canEdit ||
                  (t.canManageParticipants && category.phase == 'round_robin'),
              canEditNames: t.status != 'completed',
              onAddTeam: onAddTeam,
              onDrawLots: onDrawLots,
              onRemoveTeam: onRemoveTeam,
              onEditPlayer: onEditPlayer,
              onScoreMatch: onScoreMatch,
            ),
          ),
        ),
        if (state.activeCategories.isEmpty)
          RpcCard.compact(
            child: Text(
              'No categories selected. Edit the tournament to enable categories.',
              style: RpcTypography.body(context).copyWith(color: c.textMuted),
            ),
          ),
      ],
    );
  }

  ({String label, RpcBadgeTone tone}) _statusMeta(String status) {
    return switch (status) {
      'draft' || 'setup' => (label: 'Setup', tone: RpcBadgeTone.neutral),
      'round_robin' => (
          label: 'Round robin',
          tone: RpcBadgeTone.primary,
        ),
      'single_elimination' => (
          label: 'Playoffs',
          tone: RpcBadgeTone.warning,
        ),
      'final_round_robin' => (
          label: 'Final RR',
          tone: RpcBadgeTone.warning,
        ),
      'completed' => (label: 'Completed', tone: RpcBadgeTone.success),
      _ => (label: status, tone: RpcBadgeTone.neutral),
    };
  }
}

TournamentMatchInfo? findTournamentMatchById(
  TournamentState state,
  int matchId,
) {
  for (final category in state.categories) {
    for (final match in category.matches) {
      if (match.id == matchId) return match;
    }
    final third = category.thirdPlaceMatch;
    if (third?.id == matchId) return third;
    for (final round in category.bracket?.rounds ?? <TournamentBracketRound>[]) {
      for (final match in round.matches) {
        if (match.id == matchId) return match;
      }
    }
  }
  return null;
}

MatchInfo? _tournamentMatchForLayout(TournamentMatchInfo? match) {
  if (match == null) return null;

  MatchPlayer? playerAt(TournamentTeamInfo? team, int index) {
    if (team == null || index >= team.players.length) return null;
    final player = team.players[index];
    return MatchPlayer(id: player.id, name: player.name);
  }

  return MatchInfo(
    id: match.id,
    courtId: match.courtNumber ?? 0,
    status: match.status,
    scoreA: match.scoreA,
    scoreB: match.scoreB,
    winnerTeam: null,
    teamA: {
      'player1': playerAt(match.teamA, 0),
      'player2': playerAt(match.teamA, 1),
    },
    teamB: {
      'player1': playerAt(match.teamB, 0),
      'player2': playerAt(match.teamB, 1),
    },
  );
}

int tournamentSlotsPerTeamForState(TournamentState state) {
  final activeKey = state.display?.activeCategory?.key;
  if (activeKey != null) {
    for (final category in state.activeCategories) {
      if (category.key == activeKey) {
        return category.eventKey.contains('singles') ? 1 : 2;
      }
    }
  }

  for (final category in state.activeCategories) {
    if (category.eventKey.contains('singles')) {
      return 1;
    }
  }

  return 2;
}

int _tournamentSlotsPerTeam(TournamentMatchInfo? match) {
  if (match == null) return 2;
  final teamA = match.teamA?.players.length ?? 0;
  final teamB = match.teamB?.players.length ?? 0;
  return teamA > 1 || teamB > 1 ? 2 : 1;
}

class _TournamentCourtsPanel extends StatelessWidget {
  const _TournamentCourtsPanel({
    required this.display,
    required this.state,
    required this.courtCount,
    required this.onAssignCourt,
    required this.onReplaceCourt,
    required this.onCourtTap,
    required this.onEditCourtCount,
  });

  final TournamentDisplayState display;
  final TournamentState state;
  final int courtCount;
  final Future<void> Function(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) onAssignCourt;
  final Future<void> Function(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) onReplaceCourt;
  final void Function(TournamentCourtInfo court, TournamentMatchInfo? match)
      onCourtTap;
  final VoidCallback onEditCourtCount;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final activeCategory = display.activeCategory?.label;
    final liveCount = display.courts.where((court) => court.isActive).length;
    final defaultSlotsPerTeam = tournamentSlotsPerTeamForState(state);
    final maxSlotsPerTeam = display.courts.fold(
      defaultSlotsPerTeam,
      (max, court) {
        final slots = court.match != null
            ? tournamentSlotsFromTeamNames(
                court.match!.teamA,
                court.match!.teamB,
              )
            : defaultSlotsPerTeam;
        return slots > max ? slots : max;
      },
    );
    final hasOpenCourt = display.courts.any(
      (court) => !court.isActive && !court.isAssigned,
    );
    final hasOccupiedCourt = display.courts.any((court) => court.hasMatch);
    final courtCardHeight =
        tournamentCourtCardHeightFor(maxSlotsPerTeam) +
        ((hasOpenCourt || hasOccupiedCourt) ? 48.0 : 0.0);

    return RpcCard.compact(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sports_tennis_rounded, size: 18, color: c.primary),
              const SizedBox(width: RpcSpacing.xs),
              Expanded(
                child: Text(
                  'Court assignments',
                  style: RpcTypography.bodySemibold(context),
                ),
              ),
              TextButton.icon(
                onPressed: onEditCourtCount,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: Text('$courtCount courts'),
              ),
              const SizedBox(width: RpcSpacing.xs),
              Text(
                liveCount > 0 ? '$liveCount playing' : 'No live matches',
                style: RpcTypography.caption(context).copyWith(
                  color: c.textMuted,
                ),
              ),
            ],
          ),
          if (activeCategory != null) ...[
            const SizedBox(height: 4),
            Text(
              activeCategory,
              style: RpcTypography.caption(context).copyWith(color: c.textMuted),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Each court is paired with a group (Court 1 → Group A, etc.). OPEN — Assign court. PLAYING — tap to score or Change match.',
            style: RpcTypography.caption(context).copyWith(
              color: c.textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: RpcSpacing.sm),
          SizedBox(
            height: courtCardHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 6.0;
                final courts = display.courts;
                final useScroll = courts.length > 4;
                final cardWidth = useScroll
                    ? 220.0
                    : (constraints.maxWidth - gap * (courts.length - 1)) /
                        courts.length;

                final cards = [
                  for (final court in courts)
                    SizedBox(
                      width: cardWidth,
                      child: _TournamentCourtScoreCard(
                        court: court,
                        match: court.match != null
                            ? findTournamentMatchById(state, court.match!.id)
                            : null,
                        defaultSlotsPerTeam: defaultSlotsPerTeam,
                        pendingMatches: display.upNext,
                        onAssignCourt: onAssignCourt,
                        onReplaceCourt: onReplaceCourt,
                        onCourtTap: onCourtTap,
                      ),
                    ),
                ];

                if (useScroll) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          cards[i],
                        ],
                      ],
                    ),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: RpcSpacing.sm),
          TournamentUpNextStrip(
            matches: tournamentUpNextSortedByCourt(display.upNext),
          ),
        ],
      ),
    );
  }
}

class _TournamentAssignCourtDialog extends StatelessWidget {
  const _TournamentAssignCourtDialog({
    required this.courtNumber,
    required this.matches,
    this.preferredGroupLabel,
    this.replacing = false,
  });

  final int courtNumber;
  final List<TournamentUpNextMatchInfo> matches;
  final String? preferredGroupLabel;
  final bool replacing;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return AlertDialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      title: Text(replacing ? 'Change Court $courtNumber' : 'Assign to Court $courtNumber'),
      content: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: 420),
        child: SizedBox(
          width: double.maxFinite,
          child: matches.isEmpty
            ? Text(
                preferredGroupLabel != null
                    ? 'No ${preferredGroupLabel!} matches waiting for this court.'
                    : 'No matches waiting for a court.',
                style: RpcTypography.body(context).copyWith(color: c.textMuted),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preferredGroupLabel != null) ...[
                    Text(
                      replacing
                          ? 'Choose a new ${preferredGroupLabel!} match for this court.'
                          : 'Showing ${preferredGroupLabel!} matches for this court.',
                      style: RpcTypography.caption(context).copyWith(
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final group = match.groupLabel != null
                            ? '${match.groupLabel} · '
                            : '';
                        final queueLabel = match.isReady
                            ? (index == 0 ? 'Next · ' : 'On deck · ')
                            : 'Waiting · ';

                        return Material(
                    color: c.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(match),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.border.withValues(alpha: 0.85),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$queueLabel$group${match.teamA ?? 'TBD'} vs ${match.teamB ?? 'TBD'}',
                              style: RpcTypography.bodySemibold(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              match.isReady
                                  ? 'Ready to play'
                                  : 'Players currently on another court',
                              style: RpcTypography.caption(context).copyWith(
                                color: match.isReady
                                    ? c.primary
                                    : c.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                    ),
                  ),
                ],
              ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _TournamentCourtScoreCard extends StatelessWidget {
  const _TournamentCourtScoreCard({
    required this.court,
    required this.match,
    required this.defaultSlotsPerTeam,
    required this.pendingMatches,
    required this.onAssignCourt,
    required this.onReplaceCourt,
    required this.onCourtTap,
  });

  final TournamentCourtInfo court;
  final TournamentMatchInfo? match;
  final int defaultSlotsPerTeam;
  final List<TournamentUpNextMatchInfo> pendingMatches;
  final Future<void> Function(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) onAssignCourt;
  final Future<void> Function(
    TournamentCourtInfo court,
    List<TournamentUpNextMatchInfo> candidates,
  ) onReplaceCourt;
  final void Function(TournamentCourtInfo court, TournamentMatchInfo? match)
      onCourtTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isActive = court.isActive;
    final isAssigned = court.isAssigned;
    final isOpen = !isActive && !isAssigned;
    final courtMatch = court.match;
    final courtCandidates = tournamentCandidatesForCourt(
      pendingMatches,
      court.preferredGroupKey,
      excludeMatchId: court.match?.id,
    );
    final replaceCandidates = court.hasMatch ? courtCandidates : const <TournamentUpNextMatchInfo>[];
    final slotsPerTeam = _tournamentSlotsPerTeam(match);
    final layoutMatch = match != null
        ? _tournamentMatchForLayout(match)
        : tournamentCourtMatchForLayout(courtMatch, slotsPerTeam);
    final effectiveSlots =
        layoutMatch != null ? slotsPerTeam : defaultSlotsPerTeam;
    final statusLabel = isActive
        ? 'PLAYING'
        : isAssigned
            ? 'READY'
            : 'OPEN';
    final statusColor = isActive
        ? c.primary
        : isAssigned
            ? c.accentOrange
            : c.textMuted;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Court ${court.courtNumber}',
              style: RpcTypography.caption(context).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              statusLabel,
              style: RpcTypography.caption(context).copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ],
        ),
        if (isOpen && court.preferredGroupLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            court.preferredGroupLabel!,
            textAlign: TextAlign.center,
            style: RpcTypography.caption(context).copyWith(
              color: c.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ] else if (courtMatch?.groupLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            courtMatch!.groupLabel!,
            textAlign: TextAlign.center,
            style: RpcTypography.caption(context).copyWith(
              color: c.primary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Expanded(
          child: CourtMatchLayout(
            match: layoutMatch,
            slotsPerTeam: effectiveSlots,
            dense: true,
            showTeamLabels: false,
          ),
        ),
        if (courtMatch != null &&
            courtMatch.scoreA != null &&
            courtMatch.scoreB != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${courtMatch.scoreA}',
                style: RpcTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '–',
                  style: RpcTypography.caption(context).copyWith(
                    color: c.textMuted,
                  ),
                ),
              ),
              Text(
                '${courtMatch.scoreB}',
                style: RpcTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
        if (isOpen) ...[
          const SizedBox(height: 8),
          _TournamentCourtActionButton(
            label: 'Assign court',
            icon: Icons.add_circle_outline_rounded,
            onPressed: courtCandidates.isNotEmpty
                ? () => onAssignCourt(court, pendingMatches)
                : null,
          ),
        ] else if (court.hasMatch) ...[
          const SizedBox(height: 8),
          _TournamentCourtActionButton(
            label: 'Change match',
            icon: Icons.swap_horiz_rounded,
            outlined: true,
            onPressed: replaceCandidates.isNotEmpty
                ? () => onReplaceCourt(court, pendingMatches)
                : null,
          ),
        ],
      ],
    );

    final decorated = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? c.primary.withValues(alpha: 0.35)
              : isAssigned
                  ? c.accentOrange.withValues(alpha: 0.3)
                  : c.border.withValues(alpha: 0.85),
        ),
      ),
      child: content,
    );

    return Material(
      color: c.elevatedSurface,
      borderRadius: BorderRadius.circular(12),
      child: isActive
          ? InkWell(
              onTap: match != null && match!.canScore
                  ? () => onCourtTap(court, match)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: decorated,
            )
          : decorated,
    );
  }
}

class _TournamentCourtActionButton extends StatelessWidget {
  const _TournamentCourtActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    const buttonHeight = 36.0;
    const maxButtonWidth = 240.0;

    final child = SizedBox(
      height: buttonHeight,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxButtonWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _TournamentPodium extends StatelessWidget {
  const _TournamentPodium({
    required this.placements,
    this.categoryLabel,
    this.compact = false,
  });

  final List<TournamentPlacement> placements;
  final String? categoryLabel;
  final bool compact;

  TournamentPlacement? _place(int n) {
    for (final entry in placements) {
      if (entry.place == n) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final first = _place(1);
    final second = _place(2);
    final third = _place(3);

    if (first == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: RpcSpacing.sm,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.warning.withValues(alpha: isDark ? 0.14 : 0.1),
            c.primary.withValues(alpha: isDark ? 0.08 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: c.warning.withValues(alpha: isDark ? 0.3 : 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categoryLabel != null) ...[
            Text(
              categoryLabel!,
              style: RpcTypography.caption(context).copyWith(
                color: c.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          _PodiumRow(
            placement: first,
            tier: _PodiumTier.gold,
            compact: compact,
          ),
          if (second != null) ...[
            SizedBox(height: compact ? 4 : 6),
            _PodiumRow(
              placement: second,
              tier: _PodiumTier.silver,
              compact: compact,
            ),
          ],
          if (third != null) ...[
            SizedBox(height: compact ? 4 : 6),
            _PodiumRow(
              placement: third,
              tier: _PodiumTier.bronze,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

enum _PodiumTier { gold, silver, bronze }

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({
    required this.placement,
    required this.tier,
    required this.compact,
  });

  final TournamentPlacement placement;
  final _PodiumTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    final (icon, color, label) = switch (tier) {
      _PodiumTier.gold => (
          Icons.emoji_events_rounded,
          c.warning,
          '1st',
        ),
      _PodiumTier.silver => (
          Icons.workspace_premium_rounded,
          c.textMuted,
          '2nd',
        ),
      _PodiumTier.bronze => (
          Icons.military_tech_rounded,
          c.accentOrange,
          '3rd',
        ),
    };

    return Row(
      children: [
        Icon(icon, size: compact ? 15 : 17, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: RpcTypography.caption(context).copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            placement.displayName,
            style: RpcTypography.bodySemibold(context).copyWith(
              fontSize: compact ? RpcTypeScale.caption : RpcTypeScale.label,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.category,
    required this.categoryDefinition,
    required this.canEdit,
    required this.canManageParticipants,
    required this.canEditNames,
    required this.onAddTeam,
    required this.onDrawLots,
    required this.onRemoveTeam,
    required this.onEditPlayer,
    required this.onScoreMatch,
  });

  final TournamentCategoryState category;
  final TournamentCategoryDefinition? categoryDefinition;
  final bool canEdit;
  final bool canManageParticipants;
  final bool canEditNames;
  final Future<void> Function(String categoryKey, List<String> playerNames)
      onAddTeam;
  final Future<void> Function(
    String categoryKey, {
    required List<String> playerNames,
    List<String>? genders,
  }) onDrawLots;
  final ValueChanged<TournamentTeamInfo> onRemoveTeam;
  final Future<void> Function(int clubPlayerId, String currentName) onEditPlayer;
  final ValueChanged<TournamentMatchInfo> onScoreMatch;

  TournamentTeamInfo? get _champion {
    for (final team in category.teams) {
      if (team.status == 'champion') return team;
    }
    return null;
  }

  String? _teamPlacementLabel(TournamentTeamInfo team) => switch (team.status) {
        'champion' => '1st',
        'runner_up' => '2nd',
        'third' => '3rd',
        _ => null,
      };

  IconData? _teamPlacementIcon(String? label) => switch (label) {
        '1st' => Icons.emoji_events_rounded,
        '2nd' => Icons.workspace_premium_rounded,
        '3rd' => Icons.military_tech_rounded,
        _ => null,
      };

  Color? _teamPlacementColor(BuildContext context, String? label) {
    final c = context.rpc;
    return switch (label) {
      '1st' => c.warning,
      '2nd' => c.textMuted,
      '3rd' => c.accentOrange,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final champion = _champion;
    final phase = _phaseMeta(category.phase);

    return RpcCard.compact(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (champion != null) ...[
                Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: c.warning,
                ),
                const SizedBox(width: RpcSpacing.xs),
              ],
              Expanded(
                child: Text(
                  category.label,
                  style: RpcTypography.bodySemibold(context).copyWith(
                    fontSize: RpcTypeScale.subtitle,
                  ),
                ),
              ),
              RpcStatusBadge(label: phase.label, tone: phase.tone),
            ],
          ),
          if (category.placements.isNotEmpty) ...[
            const SizedBox(height: RpcSpacing.sm),
            _TournamentPodium(placements: category.placements),
          ],
          if (canManageParticipants && categoryDefinition != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            TournamentAdminRegisterPanel(
              category: category,
              categoryDefinition: categoryDefinition!,
              isLive: !canEdit && category.phase == 'round_robin',
              showDrawLots: canEdit,
              onRegister: (names) => onAddTeam(category.key, names),
              onDrawLots: ({
                required playerNames,
                genders,
              }) =>
                  onDrawLots(
                category.key,
                playerNames: playerNames,
                genders: genders,
              ),
            ),
          ],
          if (category.teams.isNotEmpty || canManageParticipants) ...[
            const SizedBox(height: RpcSpacing.sm),
            CollapsibleSection(
              title: 'Teams',
              subtitle: _teamsSectionSubtitle(category),
              initiallyExpanded: canManageParticipants || category.teams.isNotEmpty,
              child: category.teams.isEmpty
                  ? Text(
                      'No players registered yet.',
                      style: RpcTypography.body(context).copyWith(
                        color: context.rpc.textMuted,
                      ),
                    )
                  : _TeamsByGroupView(
                      groups: category.groups,
                      teams: category.teams,
                      phase: category.phase,
                      canManageParticipants: canManageParticipants,
                      canEditNames: canEditNames,
                      onRemoveTeam: onRemoveTeam,
                      onEditPlayer: onEditPlayer,
                      placementLabel: _teamPlacementLabel,
                      placementIcon: _teamPlacementIcon,
                      placementColor: _teamPlacementColor,
                    ),
            ),
          ],
          if (category.groups.isNotEmpty ||
              category.bracket != null ||
              category.thirdPlaceMatch != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            CollapsibleSection(
              title: _flowSectionTitle(category.phase),
              subtitle: _flowSectionSubtitle(category),
              initiallyExpanded: category.phase != 'completed',
              child: TournamentFlowView(
                groups: category.groups,
                categoryPhase: category.phase,
                bracket: category.bracket,
                thirdPlaceMatch: category.thirdPlaceMatch,
                onScoreMatch: onScoreMatch,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({String label, RpcBadgeTone tone}) _phaseMeta(String phase) => switch (phase) {
        'setup' => (label: 'Setup', tone: RpcBadgeTone.neutral),
        'round_robin' => (label: 'Round robin', tone: RpcBadgeTone.primary),
        'final_round_robin' => (
          label: 'Final RR',
          tone: RpcBadgeTone.warning,
        ),
        'single_elimination' => (label: 'Playoffs', tone: RpcBadgeTone.warning),
        'completed' => (label: 'Done', tone: RpcBadgeTone.success),
        _ => (label: phase, tone: RpcBadgeTone.neutral),
      };

  String _flowSectionTitle(String phase) => switch (phase) {
        'single_elimination' || 'completed' => 'Tournament bracket',
        'final_round_robin' => 'Final round robin',
        _ => 'Round robin groups',
      };

  String _teamsSectionSubtitle(TournamentCategoryState category) {
    final groupCount = category.groups.length;
    if (groupCount > 0) {
      return '${category.teams.length} registered · $groupCount groups';
    }
    return '${category.teams.length} registered';
  }

  String _flowSectionSubtitle(TournamentCategoryState category) {
    final groupCount = category.groups.length;
    final hasBracket = category.bracket != null;
    final hasThirdPlace = category.thirdPlaceMatch != null;
    final hasFinalGroup =
        category.groups.any((group) => group.key == 'final');
    final tieBreakNote = switch (category.phase) {
      'round_robin' => ' · ties: wins → +pts → H2H',
      'final_round_robin' =>
        ' · ties: wins → +pts → H2H → pts scored → tiebreaker',
      _ => '',
    };
    if (hasBracket && hasThirdPlace) {
      return '$groupCount groups · playoffs · 3rd place match';
    }
    if (hasBracket) {
      return '$groupCount groups · playoffs';
    }
    if (category.phase == 'final_round_robin' || hasFinalGroup) {
      return '3 teams · each plays each other once · ties: wins → +pts → H2H → pts scored → tiebreaker';
    }
    if (hasThirdPlace) {
      return '3rd place match';
    }
    return '$groupCount groups$tieBreakNote';
  }
}

class _TeamsByGroupView extends StatelessWidget {
  const _TeamsByGroupView({
    required this.groups,
    required this.teams,
    required this.phase,
    required this.canManageParticipants,
    required this.canEditNames,
    required this.onRemoveTeam,
    required this.onEditPlayer,
    required this.placementLabel,
    required this.placementIcon,
    required this.placementColor,
  });

  final List<TournamentGroupState> groups;
  final List<TournamentTeamInfo> teams;
  final String phase;
  final bool canManageParticipants;
  final bool canEditNames;
  final ValueChanged<TournamentTeamInfo> onRemoveTeam;
  final Future<void> Function(int clubPlayerId, String currentName) onEditPlayer;
  final String? Function(TournamentTeamInfo team) placementLabel;
  final IconData? Function(String? label) placementIcon;
  final Color? Function(BuildContext context, String? label) placementColor;

  static const _minColumnWidth = 148.0;
  static const _columnGap = 10.0;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Column(
        children: teams
            .map(
              (team) => Padding(
                padding: const EdgeInsets.only(bottom: RpcSpacing.xs),
                child: _TeamGroupCard(
                  team: team,
                  phase: phase,
                  canManageParticipants: canManageParticipants,
                  canEditNames: canEditNames,
                  onRemoveTeam: onRemoveTeam,
                  onEditPlayer: onEditPlayer,
                  placementLabel: placementLabel,
                  placementIcon: placementIcon,
                  placementColor: placementColor,
                ),
              ),
            )
            .toList(),
      );
    }

    final teamsByGroup = <String, List<TournamentTeamInfo>>{};
    for (final group in groups) {
      teamsByGroup[group.key] = [];
    }

    final unassigned = <TournamentTeamInfo>[];
    for (final team in teams) {
      final key = team.groupKey;
      if (key != null && teamsByGroup.containsKey(key)) {
        teamsByGroup[key]!.add(team);
      } else {
        unassigned.add(team);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final groupCount = groups.length + (unassigned.isNotEmpty ? 1 : 0);
        final needsScroll =
            groupCount * _minColumnWidth + (groupCount - 1) * _columnGap >
                constraints.maxWidth;

        final columns = <Widget>[
          for (var i = 0; i < groups.length; i++)
            _GroupTeamsColumn(
              label: groups[i].label,
              teams: _sortedTeams(teamsByGroup[groups[i].key] ?? []),
              phase: phase,
              canManageParticipants: canManageParticipants,
              canEditNames: canEditNames,
              onRemoveTeam: onRemoveTeam,
              onEditPlayer: onEditPlayer,
              placementLabel: placementLabel,
              placementIcon: placementIcon,
              placementColor: placementColor,
              expanded: !needsScroll,
              width: needsScroll ? _minColumnWidth : null,
            ),
          if (unassigned.isNotEmpty)
            _GroupTeamsColumn(
              label: 'Unassigned',
              teams: _sortedTeams(unassigned),
              phase: phase,
              canManageParticipants: canManageParticipants,
              canEditNames: canEditNames,
              onRemoveTeam: onRemoveTeam,
              onEditPlayer: onEditPlayer,
              placementLabel: placementLabel,
              placementIcon: placementIcon,
              placementColor: placementColor,
              expanded: !needsScroll,
              width: needsScroll ? _minColumnWidth : null,
            ),
        ];

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) const SizedBox(width: _columnGap),
              columns[i],
            ],
          ],
        );

        if (needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: row,
          );
        }

        return row;
      },
    );
  }

  List<TournamentTeamInfo> _sortedTeams(List<TournamentTeamInfo> groupTeams) {
    final sorted = List<TournamentTeamInfo>.from(groupTeams);
    sorted.sort((a, b) {
      final placementCompare =
          _placementRank(a).compareTo(_placementRank(b));
      if (placementCompare != 0) return placementCompare;
      final winsCompare = b.wins.compareTo(a.wins);
      if (winsCompare != 0) return winsCompare;
      return a.displayName.compareTo(b.displayName);
    });
    return sorted;
  }

  int _placementRank(TournamentTeamInfo team) => switch (team.status) {
        'champion' => 0,
        'runner_up' => 1,
        'third' => 2,
        _ => 3,
      };
}

class _GroupTeamsColumn extends StatelessWidget {
  const _GroupTeamsColumn({
    required this.label,
    required this.teams,
    required this.phase,
    required this.canManageParticipants,
    required this.canEditNames,
    required this.onRemoveTeam,
    required this.onEditPlayer,
    required this.placementLabel,
    required this.placementIcon,
    required this.placementColor,
    required this.expanded,
    this.width,
  });

  final String label;
  final List<TournamentTeamInfo> teams;
  final String phase;
  final bool canManageParticipants;
  final bool canEditNames;
  final ValueChanged<TournamentTeamInfo> onRemoveTeam;
  final Future<void> Function(int clubPlayerId, String currentName) onEditPlayer;
  final String? Function(TournamentTeamInfo team) placementLabel;
  final IconData? Function(String? label) placementIcon;
  final Color? Function(BuildContext context, String? label) placementColor;
  final bool expanded;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: RpcTypography.caption(context).copyWith(
            fontWeight: FontWeight.w600,
            color: c.text.withValues(alpha: 0.85),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        if (teams.isEmpty)
          Text(
            'No teams',
            textAlign: TextAlign.center,
            style: RpcTypography.caption(context).copyWith(color: c.textMuted),
          )
        else
          ...teams.map(
            (team) => Padding(
              padding: const EdgeInsets.only(bottom: RpcSpacing.xs),
              child: _TeamGroupCard(
                team: team,
                phase: phase,
                canManageParticipants: canManageParticipants,
                canEditNames: canEditNames,
                onRemoveTeam: onRemoveTeam,
                onEditPlayer: onEditPlayer,
                placementLabel: placementLabel,
                placementIcon: placementIcon,
                placementColor: placementColor,
              ),
            ),
          ),
      ],
    );

    final child = Container(
      padding: const EdgeInsets.all(RpcSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? c.elevatedSurface : c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
      ),
      child: column,
    );

    if (expanded) {
      return Expanded(child: child);
    }

    return SizedBox(width: width, child: child);
  }
}

class _TeamGroupCard extends StatelessWidget {
  const _TeamGroupCard({
    required this.team,
    required this.phase,
    required this.canManageParticipants,
    required this.canEditNames,
    required this.onRemoveTeam,
    required this.onEditPlayer,
    required this.placementLabel,
    required this.placementIcon,
    required this.placementColor,
  });

  final TournamentTeamInfo team;
  final String phase;
  final bool canManageParticipants;
  final bool canEditNames;
  final ValueChanged<TournamentTeamInfo> onRemoveTeam;
  final Future<void> Function(int clubPlayerId, String currentName) onEditPlayer;
  final String? Function(TournamentTeamInfo team) placementLabel;
  final IconData? Function(String? label) placementIcon;
  final Color? Function(BuildContext context, String? label) placementColor;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final label = placementLabel(team);
    final icon = placementIcon(label);
    final color = placementColor(context, label);
    final subtitle = _subtitle(label);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RpcTypography.bodySemibold(context).copyWith(
                  fontSize: RpcTypeScale.caption,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: RpcTypography.caption(context).copyWith(
                    color: color ?? c.textMuted,
                    fontWeight:
                        color != null ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (canEditNames)
          InkWell(
            onTap: () => _editTeam(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.edit_rounded, size: 14, color: c.primary),
            ),
          ),
        if (canManageParticipants)
          InkWell(
            onTap: () => onRemoveTeam(team),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: c.danger),
            ),
          ),
      ],
    );
  }

  String? _subtitle(String? placement) {
    if (placement != null) {
      return switch (placement) {
        '1st' => 'Champion',
        '2nd' => 'Runner-up',
        '3rd' => '3rd place',
        _ => placement,
      };
    }
    if (phase == 'setup') {
      return 'Assigned at start';
    }
    return '${team.wins}W · ${team.losses}L · '
        '${team.pointDifferential >= 0 ? '+' : ''}${team.pointDifferential} pts';
  }

  Future<void> _editTeam(BuildContext context) async {
    if (team.players.length == 1) {
      await onEditPlayer(team.players.first.id, team.players.first.name);
      return;
    }

    final selected = await showDialog<TournamentPlayerRef>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Edit participant'),
        children: [
          for (final player in team.players)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, player),
              child: Text(player.name),
            ),
        ],
      ),
    );

    if (selected != null) {
      await onEditPlayer(selected.id, selected.name);
    }
  }
}

class _CreateTournamentResult {
  _CreateTournamentResult({
    required this.name,
    required this.groupCount,
    required this.categories,
    required this.courtCount,
  });

  final String name;
  final int groupCount;
  final List<String> categories;
  final int courtCount;
}

class _CreateTournamentDialog extends StatefulWidget {
  const _CreateTournamentDialog({required this.categoryGroups});

  final List<TournamentCategoryDivisionGroup> categoryGroups;

  @override
  State<_CreateTournamentDialog> createState() => _CreateTournamentDialogState();
}

class _CreateTournamentDialogState extends State<_CreateTournamentDialog> {
  final _nameController = TextEditingController(text: 'Club Tournament');
  final _searchController = TextEditingController();
  final _groupCountController = TextEditingController(text: '4');
  final _selected = <String>{};
  int _groupCount = 4;
  int _courtCount = 4;
  int _divisionIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _groupCountController.dispose();
    super.dispose();
  }

  TournamentCategoryDivisionGroup get _activeDivision =>
      widget.categoryGroups[_divisionIndex];

  int _selectedCountInDivision(TournamentCategoryDivisionGroup division) {
    var count = 0;
    for (final event in division.events) {
      for (final skill in event.skillLevels) {
        if (_selected.contains(skill.key)) count++;
      }
    }
    return count;
  }

  Iterable<String> _keysInDivision(TournamentCategoryDivisionGroup division) sync* {
    for (final event in division.events) {
      for (final skill in event.skillLevels) {
        yield skill.key;
      }
    }
  }

  void _toggleSkill(String key, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  void _selectAllInDivision() {
    setState(() => _selected.addAll(_keysInDivision(_activeDivision)));
  }

  void _clearDivision() {
    setState(() => _selected.removeAll(_keysInDivision(_activeDivision)));
  }

  void _toggleAllSkillsForEvent(TournamentCategoryEventGroup event, bool select) {
    setState(() {
      for (final skill in event.skillLevels) {
        if (select) {
          _selected.add(skill.key);
        } else {
          _selected.remove(skill.key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final division = _activeDivision;
    final query = _searchController.text.trim().toLowerCase();
    final filteredEvents = division.events.where((event) {
      if (query.isEmpty) return true;
      return event.eventLabel.toLowerCase().contains(query);
    }).toList();
    final divisionSelected = _selectedCountInDivision(division);

    return AlertDialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      title: const Text('New tournament'),
      content: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: 640),
        child: SizedBox(
          width: double.maxFinite,
          height: RpcLayout.dialogContentHeight(
            context,
            fraction: 0.65,
            max: 580,
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tournament name',
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Text('Groups', style: RpcTypography.bodySemibold(context)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _groupCountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '4',
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        setState(() => _groupCount = parsed.clamp(1, 12));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [2, 3, 4, 6, 8].map((count) {
                      return ChoiceChip(
                        label: Text('$count', style: TextStyle(color: c.text)),
                        selected: _groupCount == count,
                        selectedColor: c.primaryLight,
                        checkmarkColor: c.text,
                        labelStyle: TextStyle(color: c.text),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() {
                          _groupCount = count;
                          _groupCountController.text = '$count';
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Round robin within each group (A–L). Top 1 per group advances.',
              style: RpcTypography.caption(context).copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 16),
            Text('Categories', style: RpcTypography.bodySemibold(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(widget.categoryGroups.length, (index) {
                final group = widget.categoryGroups[index];
                final count = _selectedCountInDivision(group);
                final label = count > 0
                    ? '${group.divisionLabel} ($count)'
                    : group.divisionLabel;

                return ChoiceChip(
                  label: Text(label, style: TextStyle(color: c.text)),
                  selected: _divisionIndex == index,
                  selectedColor: c.primaryLight,
                  checkmarkColor: c.text,
                  labelStyle: TextStyle(color: c.text),
                  onSelected: (_) => setState(() => _divisionIndex = index),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search events in ${division.divisionLabel}',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$divisionSelected in ${division.divisionLabel} · ${_selected.length} total selected',
                    style: RpcTypography.caption(context)
                        .copyWith(color: c.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: divisionSelected ==
                              division.events.length *
                                  (division.events.isEmpty
                                      ? 0
                                      : division.events.first.skillLevels.length)
                          ? null
                          : _selectAllInDivision,
                      child: const Text('All'),
                    ),
                    TextButton(
                      onPressed: divisionSelected == 0 ? null : _clearDivision,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: filteredEvents.isEmpty
                  ? Center(
                      child: Text(
                        'No events match your search.',
                        style: RpcTypography.body(context)
                            .copyWith(color: c.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredEvents.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        final eventSelected = event.skillLevels
                            .where((s) => _selected.contains(s.key))
                            .length;

                        return _EventCategoryCard(
                          event: event,
                          selectedKeys: _selected,
                          onToggleSkill: _toggleSkill,
                          onToggleAll: (select) =>
                              _toggleAllSkillsForEvent(event, select),
                          allSelected:
                              eventSelected == event.skillLevels.length,
                          someSelected: eventSelected > 0 &&
                              eventSelected < event.skillLevels.length,
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  Navigator.pop(
                    context,
                    _CreateTournamentResult(
                      name: _nameController.text.trim().isEmpty
                          ? 'Tournament'
                          : _nameController.text.trim(),
                      groupCount: _groupCount.clamp(1, 12),
                      categories: _selected.toList(),
                      courtCount: _courtCount.clamp(1, 12),
                    ),
                  );
                },
          child: Text('Create (${_selected.length})'),
        ),
      ],
    );
  }
}

class _EventCategoryCard extends StatelessWidget {
  const _EventCategoryCard({
    required this.event,
    required this.selectedKeys,
    required this.onToggleSkill,
    required this.onToggleAll,
    required this.allSelected,
    required this.someSelected,
  });

  final TournamentCategoryEventGroup event;
  final Set<String> selectedKeys;
  final void Function(String key, bool selected) onToggleSkill;
  final void Function(bool select) onToggleAll;
  final bool allSelected;
  final bool someSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allSelected || someSelected
              ? c.primary.withValues(alpha: 0.4)
              : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.eventLabel,
                  style: RpcTypography.bodySemibold(context),
                ),
              ),
              IconButton(
                tooltip: allSelected ? 'Clear event' : 'Select all skill levels',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  allSelected
                      ? Icons.check_box_rounded
                      : someSelected
                          ? Icons.indeterminate_check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: allSelected || someSelected ? c.primary : c.textMuted,
                ),
                onPressed: () => onToggleAll(!allSelected),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < event.skillLevels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _SkillLevelChip(
                    label: event.skillLevels[i].skillLabel,
                    selected: selectedKeys.contains(event.skillLevels[i].key),
                    onSelected: (value) =>
                        onToggleSkill(event.skillLevels[i].key, value),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillLevelChip extends StatelessWidget {
  const _SkillLevelChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.primaryLight : c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? c.primary.withValues(alpha: 0.55)
                  : c.border.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RpcTypography.caption(context).copyWith(
              color: c.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentScoreDialog extends StatefulWidget {
  const _TournamentScoreDialog({required this.match});

  final TournamentMatchInfo match;

  @override
  State<_TournamentScoreDialog> createState() => _TournamentScoreDialogState();
}

class _TournamentScoreDialogState extends State<_TournamentScoreDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();

  @override
  void initState() {
    super.initState();
    final match = widget.match;
    if (match.scoreA != null) _a.text = '${match.scoreA}';
    if (match.scoreB != null) _b.text = '${match.scoreB}';
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  bool get _canSave {
    final scoreA = int.tryParse(_a.text);
    final scoreB = int.tryParse(_b.text);
    return scoreA != null && scoreB != null;
  }

  void _submit() {
    final scoreA = int.tryParse(_a.text);
    final scoreB = int.tryParse(_b.text);
    if (scoreA == null || scoreB == null) return;
    Navigator.pop(context, (a: scoreA, b: scoreB));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final match = widget.match;
    final teamA = match.teamA?.displayName ?? 'Team A';
    final teamB = match.teamB?.displayName ?? 'Team B';
    final courtLabel =
        match.courtNumber != null ? 'Court ${match.courtNumber}' : null;

    return Dialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      backgroundColor: c.elevatedSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (courtLabel != null) ...[
                Text(
                  courtLabel,
                  style: RpcTypography.caption(context).copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                match.label,
                style: RpcTypography.headline(context).copyWith(
                  fontSize: RpcTypeScale.title,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record the final score for this court.',
                style: RpcTypography.body(context).copyWith(
                  color: c.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              _ScoreTeamField(
                label: teamA,
                controller: _a,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              _ScoreTeamField(
                label: teamB,
                controller: _b,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: c.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: RpcTypography.bodySemibold(context).copyWith(
                        color: c.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _canSave ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      disabledBackgroundColor: c.border,
                      foregroundColor: RpcPalette.onPrimaryForeground,
                      disabledForegroundColor: c.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save score',
                      style: RpcTypography.bodySemibold(context).copyWith(
                        color: _canSave
                            ? RpcPalette.onPrimaryForeground
                            : c.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreTeamField extends StatelessWidget {
  const _ScoreTeamField({
    required this.label,
    required this.controller,
    this.autofocus = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: RpcTypography.bodySemibold(context).copyWith(
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 56,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.elevatedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border.withValues(alpha: 0.85)),
            ),
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: onChanged,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: RpcTypography.bodyBold(context).copyWith(
                fontSize: RpcTypeScale.subtitle,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '0',
                hintStyle: RpcTypography.body(context).copyWith(
                  color: c.textMuted.withValues(alpha: 0.65),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentPageSnapshot {
  _TournamentPageSnapshot({
    required this.tournaments,
    required this.categoryGroups,
    required this.active,
  }) : loadedAt = DateTime.now();

  final List<TournamentListItem> tournaments;
  final List<TournamentCategoryDivisionGroup> categoryGroups;
  final TournamentState? active;
  final DateTime loadedAt;

  bool get isFresh =>
      DateTime.now().difference(loadedAt) < AppConfig.screenCacheTtl;
}
