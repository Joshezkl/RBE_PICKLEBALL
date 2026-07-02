import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/decor/rpc_decor_empty_state.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/session_controller.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/rpc_status_badge.dart';
import '../../core/widgets/rpc_responsive.dart';
import 'player_profile_modal.dart';
import 'pending_payments_panel.dart' show formatPesos;

class PlayerManagementModal extends StatefulWidget {
  const PlayerManagementModal({
    super.key,
    required this.api,
    this.sessionController,
    this.activeSessionId,
    this.rosterPlayerNames = const {},
    this.matchMode,
    this.requirePayment = false,
    this.sessionFeeCents = 0,
    this.embedded = false,
  });

  final ApiClient api;
  final SessionController? sessionController;
  final int? activeSessionId;
  final Set<String> rosterPlayerNames;
  final String? matchMode;
  final bool requirePayment;
  final int sessionFeeCents;
  final bool embedded;

  static Future<void> show(
    BuildContext context, {
    required ApiClient api,
    SessionController? sessionController,
    int? activeSessionId,
    Set<String> rosterPlayerNames = const {},
    String? matchMode,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PlayerManagementModal(
        api: api,
        sessionController: sessionController,
        activeSessionId: activeSessionId,
        rosterPlayerNames: rosterPlayerNames,
        matchMode: matchMode,
      ),
    );
  }

  @override
  State<PlayerManagementModal> createState() => _PlayerManagementModalState();
}

class _PlayerManagementModalState extends State<PlayerManagementModal> {
  static List<ClubPlayerInfo>? _cachedPlayers;
  static DateTime? _cacheLoadedAt;

  final _searchController = TextEditingController();
  final _registerController = TextEditingController();
  final _pendingIds = <int>{};
  final _selectedIds = <int>{};
  Timer? _searchDebounce;

  List<ClubPlayerInfo> _players = [];
  int? _activeSessionId;
  bool _initialLoading = false;
  bool _refreshing = false;
  bool _registering = false;
  String? _error;
  String? _skillLevel = 'beginner';
  String? _gender = 'male';

  bool get _hasActiveSession => _activeSessionId != null;

  @override
  void initState() {
    super.initState();
    _activeSessionId =
        widget.activeSessionId ?? widget.sessionController?.state?.session.id;

    if (_cachedPlayers != null) {
      _players = _applyRosterHints(_cachedPlayers!);
    }

    _loadPlayers(showInitialSpinner: _players.isEmpty);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _registerController.dispose();
    super.dispose();
  }

  List<ClubPlayerInfo> _applyRosterHints(List<ClubPlayerInfo> players) {
    if (widget.rosterPlayerNames.isEmpty) return players;
    return players
        .map(
          (player) => player.copyWith(
            inCurrentSession:
                player.inCurrentSession || widget.rosterPlayerNames.contains(player.name),
          ),
        )
        .toList();
  }

  void _updateCache(List<ClubPlayerInfo> players) {
    _cachedPlayers = players;
    _cacheLoadedAt = DateTime.now();
  }

  Future<void> _loadPlayers({
    String? search,
    bool showInitialSpinner = false,
    bool force = false,
  }) async {
    final query = search?.trim();
    final isSearch = query != null && query.isNotEmpty;
    final cacheFresh = _cacheLoadedAt != null &&
        DateTime.now().difference(_cacheLoadedAt!) < AppConfig.screenCacheTtl;

    if (!force && !isSearch && cacheFresh && _cachedPlayers != null) {
      setState(() {
        _players = _applyRosterHints(_cachedPlayers!);
        _activeSessionId = widget.activeSessionId ??
            widget.sessionController?.state?.session.id;
      });
      return;
    }

    if (showInitialSpinner && _players.isEmpty) {
      setState(() => _initialLoading = true);
    } else {
      setState(() => _refreshing = true);
    }
    setState(() => _error = null);

    try {
      final result = await widget.api.getClubPlayers(search: query);
      final merged = _applyRosterHints(result.players);
      _updateCache(merged);
      if (!mounted) return;
      setState(() {
        _players = merged;
        _activeSessionId = result.activeSessionId ?? _activeSessionId;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadPlayers(search: value, force: true);
    });
  }

  void _patchPlayer(int id, ClubPlayerInfo Function(ClubPlayerInfo) patch) {
    setState(() {
      _players = _players.map((player) {
        if (player.id != id) return player;
        return patch(player);
      }).toList();
      _updateCache(_players);
    });
  }

  Future<void> _registerPlayer({bool joinAfter = false}) async {
    final name = _registerController.text.trim();
    if (name.isEmpty || _registering) return;

    setState(() {
      _registering = true;
      _error = null;
    });

    try {
      final created = await widget.api.registerClubPlayer(
        name,
        skillLevel: _skillLevel!,
        gender: _gender!,
      );
      _registerController.clear();

      final inSession = widget.rosterPlayerNames.contains(created.name);
      final next = [
        ..._players.where((player) => player.id != created.id),
        created.copyWith(inCurrentSession: inSession),
      ]..sort((a, b) => a.name.compareTo(b.name));

      setState(() => _players = next);
      _updateCache(next);

      if (joinAfter && _hasActiveSession && !inSession) {
        await _joinSession(created);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _joinSession(ClubPlayerInfo player) async {
    if (!_hasActiveSession || _pendingIds.contains(player.id)) return;

    String? paymentAction;
    if (widget.requirePayment) {
      paymentAction = await _pickPaymentAction();
      if (paymentAction == null) return;
    }

    setState(() {
      _pendingIds.add(player.id);
      _error = null;
    });

    if (paymentAction != 'pending') {
      _patchPlayer(player.id, (p) => p.copyWith(inCurrentSession: true));
    }

    try {
      final fresh = await widget.api.joinSession(
        player.id,
        paymentAction: paymentAction,
      );
      widget.sessionController?.applyState(fresh);
      if (paymentAction == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${player.name} added to awaiting payment')),
          );
        }
      }
    } catch (e) {
      _patchPlayer(player.id, (p) => p.copyWith(inCurrentSession: false));
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _pendingIds.remove(player.id));
    }
  }

  Future<String?> _pickPaymentAction() async {
    final fee = formatPesos(widget.sessionFeeCents);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment'),
        content: Text('How should this player enter the session? Fee: $fee'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'pending'),
            child: const Text('Pending'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'waived'),
            child: const Text('Waived'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'paid'),
            child: const Text('Paid'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromSession(ClubPlayerInfo player) async {
    if (_pendingIds.contains(player.id)) return;

    setState(() {
      _pendingIds.add(player.id);
      _error = null;
    });

    _patchPlayer(player.id, (p) => p.copyWith(inCurrentSession: false));

    try {
      final fresh =
          await widget.api.removeFromSession(clubPlayerId: player.id);
      widget.sessionController?.applyState(fresh);
    } catch (e) {
      _patchPlayer(player.id, (p) => p.copyWith(inCurrentSession: true));
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _pendingIds.remove(player.id));
    }
  }

  Future<void> _confirmDelete(ClubPlayerInfo player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Player'),
        content: const Text('Are you sure you want to delete this player?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _pendingIds.add(player.id));
    final previous = _players;

    setState(() {
      _players = _players.where((p) => p.id != player.id).toList();
      _updateCache(_players);
    });

    try {
      await widget.api.deleteClubPlayer(player.id);
    } catch (e) {
      setState(() {
        _players = previous;
        _updateCache(previous);
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _pendingIds.remove(player.id));
    }
  }

  void _togglePlayerSelection(int playerId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(playerId);
      } else {
        _selectedIds.remove(playerId);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedIds.addAll(_players.map((player) => player.id));
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  bool get _allVisibleSelected =>
      _players.isNotEmpty &&
      _players.every((player) => _selectedIds.contains(player.id));

  Future<void> _confirmBulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final selectedPlayers = _players
        .where((player) => _selectedIds.contains(player.id))
        .toList();
    final count = selectedPlayers.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Players'),
        content: Text(
          count == 1
              ? 'Delete ${selectedPlayers.first.name}? This cannot be undone.'
              : 'Delete $count players? This cannot be undone.',
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
            child: Text(count == 1 ? 'Delete' : 'Delete $count'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ids = selectedPlayers.map((player) => player.id).toList();
    setState(() {
      _pendingIds.addAll(ids);
      _error = null;
    });

    final previous = _players;
    final failedEntries = <String>[];
    final deletedIds = <int>{};

    for (final player in selectedPlayers) {
      try {
        await widget.api.deleteClubPlayer(player.id);
        deletedIds.add(player.id);
      } catch (e) {
        final reason = e is ApiException ? e.message : 'Delete failed';
        failedEntries.add('${player.name}: $reason');
      }
    }

    if (!mounted) return;

    setState(() {
      _players =
          _players.where((player) => !deletedIds.contains(player.id)).toList();
      _selectedIds.removeAll(deletedIds);
      _pendingIds.removeAll(ids);
      _updateCache(_players);

      if (failedEntries.isEmpty) {
        _error = null;
      } else if (deletedIds.isEmpty) {
        _players = previous;
        _updateCache(previous);
        _error = failedEntries.join('\n');
      } else {
        _error =
            'Deleted ${deletedIds.length} player(s).\n${failedEntries.join('\n')}';
      }
    });

    if (failedEntries.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedIds.length == 1
                ? 'Player deleted'
                : '${deletedIds.length} players deleted',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Players', style: RpcTypography.title(context)),
                    const SizedBox(height: 2),
                    Text(
                      _hasActiveSession
                          ? 'Register or join players to the active session'
                          : 'Register club players (start a session to join)',
                      style: RpcTypography.bodyMuted(context),
                    ),
                  ],
                ),
              ),
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Material(
                  color: c.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: RpcTypography.body(context).copyWith(
                              color: c.danger,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _error = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: RpcSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= RpcBreakpoints.medium;
                  final nameField = TextField(
                    controller: _registerController,
                    decoration: const InputDecoration(
                      labelText: 'Player name',
                      hintText: 'Register new player',
                      isDense: true,
                    ),
                    enabled: !_registering,
                    onSubmitted: (_) => _registerPlayer(
                      joinAfter: _hasActiveSession,
                    ),
                  );
                  final skillDropdown = DropdownButtonFormField<String>(
                    value: _skillLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Skill level',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'beginner',
                        child: Text('Beginner'),
                      ),
                      DropdownMenuItem(
                        value: 'novice',
                        child: Text('Novice'),
                      ),
                      DropdownMenuItem(
                        value: 'intermediate',
                        child: Text('Intermediate'),
                      ),
                      DropdownMenuItem(
                        value: 'advanced',
                        child: Text('Advanced'),
                      ),
                    ],
                    onChanged: _registering
                        ? null
                        : (value) => setState(() => _skillLevel = value),
                  );
                  final genderDropdown = DropdownButtonFormField<String>(
                    value: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text('Female'),
                      ),
                    ],
                    onChanged: _registering
                        ? null
                        : (value) => setState(() => _gender = value),
                  );
                  final registerButton = FilledButton(
                    onPressed: _registering
                        ? null
                        : () => _registerPlayer(joinAfter: false),
                    child: _registering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Register'),
                  );
                  final joinButton = FilledButton(
                    onPressed: _registering
                        ? null
                        : () => _registerPlayer(joinAfter: true),
                    child: const Text('Register & Join'),
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: nameField),
                        const SizedBox(width: 8),
                        SizedBox(width: 160, child: skillDropdown),
                        const SizedBox(width: 8),
                        SizedBox(width: 120, child: genderDropdown),
                        const SizedBox(width: 8),
                        registerButton,
                        if (_hasActiveSession) ...[
                          const SizedBox(width: 8),
                          joinButton,
                        ],
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nameField,
                      const SizedBox(height: RpcSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: skillDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: genderDropdown),
                        ],
                      ),
                      const SizedBox(height: RpcSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          registerButton,
                          if (_hasActiveSession) joinButton,
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search players',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 12),
              if (_players.isNotEmpty) ...[
                RpcSelectionToolbar(
                  leading: [
                    TextButton(
                      onPressed: _allVisibleSelected
                          ? _clearSelection
                          : _selectAllVisible,
                      child: Text(
                        _allVisibleSelected ? 'Clear selection' : 'Select all',
                      ),
                    ),
                    if (_selectedIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedIds.length} selected',
                        style: RpcTypography.bodyMuted(context),
                      ),
                    ],
                  ],
                  action: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty ||
                            _selectedIds.any(_pendingIds.contains)
                        ? null
                        : _confirmBulkDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete selected'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.danger,
                      foregroundColor: RpcPalette.onPrimaryForeground,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _initialLoading
                    ? const _PlayerListSkeleton()
                    : _players.isEmpty
                        ? const RpcDecorEmptyState(
                            title: 'No players found',
                            subtitle: 'Register a new player or adjust your search',
                            icon: Icons.person_search_outlined,
                            compact: true,
                          )
                        : ListView.separated(
                            itemCount: _players.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final player = _players[index];
                              final pending = _pendingIds.contains(player.id);
                              return _PlayerRow(
                                player: player,
                                pending: pending,
                                selected: _selectedIds.contains(player.id),
                                hasActiveSession: _hasActiveSession,
                                onTap: () => PlayerProfileModal.show(
                                  context,
                                  player: player,
                                  api: widget.api,
                                  onDelete: () => _confirmDelete(player),
                                ),
                                onJoin: () => _joinSession(player),
                                onRemove: () => _removeFromSession(player),
                                onSelectionChanged: (selected) =>
                                    _togglePlayerSelection(player.id, selected),
                              );
                            },
                          ),
              ),
            ],
    );

    if (widget.embedded) {
      return content;
    }

    return RpcResponsiveDialog(
      maxWidth: 760,
      child: content,
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.pending,
    required this.selected,
    required this.hasActiveSession,
    required this.onTap,
    required this.onJoin,
    required this.onRemove,
    required this.onSelectionChanged,
  });

  final ClubPlayerInfo player;
  final bool pending;
  final bool selected;
  final bool hasActiveSession;
  final VoidCallback onTap;
  final VoidCallback onJoin;
  final VoidCallback onRemove;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < RpcBreakpoints.compact;
        final trailing = pending
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Wrap(
                spacing: 4,
                children: [
                  if (hasActiveSession && !player.inCurrentSession)
                    TextButton(
                      onPressed: onJoin,
                      child: const Text('Join'),
                    ),
                  if (player.inCurrentSession)
                    TextButton(
                      onPressed: onRemove,
                      child: const Text('Remove'),
                    ),
                ],
              );

        if (compact) {
          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: pending
                            ? null
                            : (value) =>
                                onSelectionChanged(value ?? false),
                      ),
                      Expanded(
                        child: Text(
                          player.name,
                          style: RpcTypography.bodySemibold(context),
                        ),
                      ),
                      if (player.inCurrentSession)
                        const RpcStatusBadge(
                          label: 'In session',
                          tone: RpcBadgeTone.primary,
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      '${MatchModes.skillLabel(player.skillLevel)} · '
                      '${MatchModes.genderLabel(player.gender)} · '
                      '${player.totalWins}W / ${player.totalLosses}L',
                      style: RpcTypography.bodyMuted(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 40, top: 4),
                    child: trailing,
                  ),
                ],
              ),
            ),
          );
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Checkbox(
            value: selected,
            onChanged: pending
                ? null
                : (value) => onSelectionChanged(value ?? false),
          ),
          onTap: onTap,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  style: RpcTypography.bodySemibold(context),
                ),
              ),
              if (player.inCurrentSession)
                const RpcStatusBadge(
                  label: 'In session',
                  tone: RpcBadgeTone.primary,
                ),
            ],
          ),
          subtitle: Text(
            '${MatchModes.skillLabel(player.skillLevel)} · '
            '${MatchModes.genderLabel(player.gender)} · '
            '${player.totalWins}W / ${player.totalLosses}L · '
            '${player.winRate.toStringAsFixed(1)}% all-time',
            style: RpcTypography.bodyMuted(context),
          ),
          trailing: trailing,
        );
      },
    );
  }
}

class _PlayerListSkeleton extends StatelessWidget {
  const _PlayerListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 140, height: 14),
                  SizedBox(height: 8),
                  _SkeletonBar(width: 200, height: 12),
                ],
              ),
            ),
            _SkeletonBar(width: 56, height: 28),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.rpc.surfaceHover,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
