import 'package:flutter/material.dart';

import '../../core/match_modes.dart';
import '../../core/models.dart';
import '../../core/session_controller.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/decor/rpc_net_divider.dart';
import '../../core/admin_nav.dart';
import '../../core/widgets/collapsible_section.dart';
import '../../core/widgets/next_up_badge.dart';
import '../../core/widgets/check_in_qr_panel.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_error_banner.dart';
import '../../core/widgets/rpc_feature_toggle.dart';
import '../../core/widgets/rpc_inline_stat.dart';
import '../../core/widgets/auto_assign_toggle.dart';
import '../../core/widgets/edit_court_count_dialog.dart';
import '../../core/widgets/rpc_section_header.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/widgets/match_history_grid.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/admin_pin_controller.dart';
import '../../main.dart' show rpcThemeController;
import 'challenge_court_panel.dart';
import 'court_grid.dart';
import 'manual_assign_dialog.dart';
import 'match_mode_selection.dart';
import 'queue_panel.dart';
import 'pending_payments_panel.dart';
import 'score_entry_dialog.dart';
import 'session_report_view.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final SessionController _controller;
  final _pinController = TextEditingController(text: '1234');
  final _sessionNameController = TextEditingController();
  final _sessionFeeController = TextEditingController(text: '30');

  String _selectedMatchMode = MatchModes.defaultMode;
  String _playFormat = 'doubles';
  int _courtCount = 4;
  bool _autoAssignEnabled = false;
  bool _requirePayment = false;
  int _sessionFeePesos = 30;
  late String _autoSessionName;
  bool _sessionNameManuallyEdited = false;
  List<SessionPreset> _presets = [];
  int? _selectedPresetId;
  bool _loadingPresets = false;
  int _mobileTab = 0;

  @override
  void initState() {
    super.initState();
    _autoSessionName = MatchModes.sessionNameFor(_selectedMatchMode);
    _sessionNameController.text = _autoSessionName;
    _controller = SessionController();
    rpcAdminPinController.setPin(_pinController.text);
    _controller.setAdminPin(_pinController.text);
    _controller.initialize();
    _controller.addListener(_onControllerUpdate);
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() => _loadingPresets = true);
    try {
      _presets = await _controller.api.getSessionPresets();
    } catch (_) {
      _presets = [];
    } finally {
      if (mounted) setState(() => _loadingPresets = false);
    }
  }

  void _onMatchModeSelected(String modeId) {
    setState(() {
      _selectedMatchMode = modeId;
      _applyAutoSessionName(modeId);
    });
  }

  void _applyAutoSessionName(String modeId) {
    _autoSessionName = MatchModes.sessionNameFor(modeId);
    if (!_sessionNameManuallyEdited) {
      _sessionNameController.text = _autoSessionName;
    }
  }

  void _onSessionNameChanged(String value) {
    final manuallyEdited = value != _autoSessionName;
    if (manuallyEdited != _sessionNameManuallyEdited) {
      setState(() => _sessionNameManuallyEdited = manuallyEdited);
    }
  }

  void _onControllerUpdate() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _pinController.dispose();
    _sessionNameController.dispose();
    _sessionFeeController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    _controller.setAdminPin(_pinController.text.trim());
    final mode = MatchModes.byId(_selectedMatchMode);
    await _controller.startSession(
      name: _sessionNameController.text.trim(),
      matchMode: mode.id,
      playFormat: mode.forcesSingles ? 'singles' : _playFormat,
      courtCount: _courtCount,
      autoAssignEnabled: _autoAssignEnabled,
      requirePayment: _requirePayment,
      sessionFeeCents: _sessionFeePesos * 100,
    );
  }

  void _applyPreset(SessionPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      _selectedMatchMode = preset.matchMode;
      _playFormat = preset.playFormat;
      _courtCount = preset.courtCount;
      _autoAssignEnabled = preset.autoAssignEnabled;
      _sessionNameManuallyEdited = false;
      _applyAutoSessionName(preset.matchMode);
      _sessionNameController.text = preset.name;
    });
  }

  Future<void> _saveCurrentAsPreset() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _sessionNameController.text.trim());
        return AlertDialog(
          title: const Text('Save Session Preset'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Preset name',
              hintText: 'e.g. Friday Night Open Play',
            ),
            autofocus: true,
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
    if (name == null || name.isEmpty) return;

    final mode = MatchModes.byId(_selectedMatchMode);
    try {
      final preset = await _controller.api.saveSessionPreset(
        name: name,
        matchMode: mode.id,
        playFormat: mode.forcesSingles ? 'singles' : _playFormat,
        courtCount: _courtCount,
        autoAssignEnabled: _autoAssignEnabled,
      );
      await _loadPresets();
      if (mounted) {
        setState(() => _selectedPresetId = preset.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved preset "$name"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preset: $e')),
        );
      }
    }
  }

  Future<void> _assignNextUp(CourtInfo court) async {
    await _controller.assignNextUp(court.id);
  }

  Future<void> _enterScore(MatchInfo match) async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (_) => ScoreEntryDialog(match: match),
    );
    if (result == null) return;
    await _controller.submitScore(match.id, result.$1, result.$2);
  }

  Future<void> _manualAssign(CourtInfo court) async {
    final state = _controller.state;
    if (state == null) return;

    final selected = await showDialog<List<int>>(
      context: context,
      builder: (_) => ManualAssignDialog(
        court: court,
        state: state,
      ),
    );
    if (selected == null) return;
    await _controller.manualAssign(court.id, selected);
  }

  Future<void> _removeFromCourt(CourtInfo court, int playerId) async {
    await _controller.removePlayerFromCourt(court.id, playerId);
  }

  Future<void> _editPlayerName(int playerId, String currentName) async {
    final updated = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: currentName);
        return AlertDialog(
          title: const Text('Edit Player Name'),
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

    final ok = await _controller.updatePlayerName(playerId, updated);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.error ?? 'Could not update name')),
      );
    }
  }

  Future<void> _editCourtCount(SessionState state) async {
    final selected = await showEditCourtCountDialog(
      context,
      currentCount: state.session.courtCount,
    );
    if (selected == null || selected == state.session.courtCount) return;

    final ok = await _controller.updateCourtCount(selected);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_controller.error ?? 'Could not update courts')),
      );
    }
  }

  Future<void> _endSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'This will close the session and generate the final report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _controller.endSession();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    final isActive = state != null && state.session.isActive;

    return RpcShell(
      activeDestination: RpcNavDestination.dashboard,
      pageTitle: isActive ? state.session.name : 'Queue Master',
      pageSubtitle: isActive
          ? '${state.session.matchModeLabel} · ${state.session.playFormat.toUpperCase()} · ${state.session.courtCount} courts'
          : 'Choose a match mode and configure courts before opening play',
      themeController: rpcThemeController,
      adminPin: rpcAdminPinController.pin,
      sessionId: state?.session.id,
      navDestinations: adminNavDestinations,
      maxWidth: 960,
      loading: _controller.loading && state == null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_controller.error != null)
            RpcErrorBanner(
              message: _controller.error!,
              onDismiss: () {
                _controller.error = null;
                setState(() {});
              },
            ),
          if (!isActive) ...[
            _buildStartSessionCard(),
            if (_controller.lastReport != null)
              Padding(
                padding: const EdgeInsets.only(top: RpcSpacing.md),
                child: SessionReportView(report: _controller.lastReport!),
              ),
          ] else
            _buildActiveSessionBody(state),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBody(SessionState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= RpcBreakpoints.wide;

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSessionKpis(state),
              const SizedBox(height: RpcSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCourtsSection(state),
                        const SizedBox(height: RpcSpacing.md),
                        CollapsibleSection(
                          title: 'Match History',
                          subtitle: state.matchHistory.isEmpty
                              ? 'Recently completed matches'
                              : '${state.matchHistory.length} completed',
                          initiallyExpanded: false,
                          child: MatchHistoryGrid(matches: state.matchHistory),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: RpcSpacing.md),
                  SizedBox(
                    width: 360,
                    child: _buildSessionRail(state),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSessionKpis(state),
            const SizedBox(height: RpcSpacing.sm),
            _buildMobileTabs(state),
            const SizedBox(height: RpcSpacing.md),
            if (_mobileTab == 0) ...[
              _buildCourtsSection(state),
              const SizedBox(height: RpcSpacing.lg),
              CollapsibleSection(
                title: 'Match History',
                subtitle: '${state.matchHistory.length} completed',
                initiallyExpanded: false,
                child: MatchHistoryGrid(matches: state.matchHistory),
              ),
            ] else if (_mobileTab == 1) ...[
              PendingPaymentsPanel(
                state: state,
                api: _controller.api,
                sessionController: _controller,
                compact: true,
              ),
              if (state.pendingPayments.isNotEmpty)
                const SizedBox(height: RpcSpacing.sm),
              _buildUpNextSection(state),
              const SizedBox(height: RpcSpacing.sm),
              CollapsibleSection(
                title: 'Queues',
                subtitle: 'Players waiting by group',
                initiallyExpanded: true,
                child: _buildQueueSection(state),
              ),
            ] else ...[
              _buildSessionControls(state),
              const SizedBox(height: RpcSpacing.sm),
              ChallengeCourtPanel(
                state: state,
                controller: _controller,
                compact: true,
              ),
              const SizedBox(height: RpcSpacing.sm),
              _buildCheckInSection(state),
              const SizedBox(height: RpcSpacing.md),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/admin/displays',
                  arguments: rpcAdminPinController.pin,
                ),
                icon: const Icon(Icons.cast_rounded, size: 18),
                label: const Text('Venue Displays'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMobileTabs(SessionState state) {
    final c = context.rpc;
    final tabs = ['Courts', 'Queue', 'Desk'];
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Row(
      children: List.generate(tabs.length, (i) {
        final active = _mobileTab == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? RpcSpacing.xs : 0),
            child: Material(
              color: active ? c.primary : c.surface,
              borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
              child: InkWell(
                onTap: () => setState(() => _mobileTab = i),
                borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: RpcTypography.labelSemibold(context).copyWith(
                      color: active ? onPrimary : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCourtsSection(SessionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RpcSectionHeader(
          title: 'Courts',
          subtitle: 'Active matches and available courts',
          compact: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: _controller.loading ? null : () => _editCourtCount(state),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text('${state.session.courtCount} courts'),
              ),
              TextButton(
                onPressed: _controller.loading ? null : _endSession,
                style: TextButton.styleFrom(foregroundColor: context.rpc.danger),
                child: const Text('End Session'),
              ),
            ],
          ),
        ),
        const SizedBox(height: RpcSpacing.sm),
        CourtGrid(
          courts: state.courts,
          slotsPerTeam: state.session.playFormat == 'singles' ? 1 : 2,
          dense: true,
          challengeCourtIsOpen: state.challengeCourt.isOpen,
          canAssignNextFor: state.canAssignNextForCourt,
          onEnterScore: _enterScore,
          onManualAssign: _manualAssign,
          onAssignNext: _assignNextUp,
          onRemovePlayer: _removeFromCourt,
        ),
      ],
    );
  }

  Widget _buildSessionRail(SessionState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSessionControls(state),
        const SizedBox(height: RpcSpacing.sm),
        ChallengeCourtPanel(
          state: state,
          controller: _controller,
          compact: true,
        ),
        const SizedBox(height: RpcSpacing.sm),
        PendingPaymentsPanel(
          state: state,
          api: _controller.api,
          sessionController: _controller,
          compact: true,
        ),
        if (state.pendingPayments.isNotEmpty)
          const SizedBox(height: RpcSpacing.sm),
        _buildUpNextSection(state),
        const SizedBox(height: RpcSpacing.sm),
        CollapsibleSection(
          title: 'Queues',
          showSideline: true,
          subtitle: 'Players waiting by group',
          initiallyExpanded: false,
          child: _buildQueueSection(state),
        ),
        const SizedBox(height: RpcSpacing.sm),
        _buildCheckInSection(state),
        const SizedBox(height: RpcSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            '/admin/displays',
            arguments: rpcAdminPinController.pin,
          ),
          icon: const Icon(Icons.cast_rounded, size: 18),
          label: const Text('Venue Displays'),
        ),
      ],
    );
  }

  Widget _buildCheckInSection(SessionState state) {
    if (state.session.checkInToken == null) {
      return const SizedBox.shrink();
    }

    return CollapsibleSection(
      title: 'Player Check-In',
      subtitle: 'QR code for tonight\'s roster',
      initiallyExpanded: false,
      child: CheckInQrPanel(
        sessionName: state.session.name,
        checkInToken: state.session.checkInToken!,
      ),
    );
  }

  Widget _buildStartSessionCard() {
    final selectedMode = MatchModes.byId(_selectedMatchMode);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Container(
          decoration: BoxDecoration(
            color: context.rpc.surface,
            borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
            border: Border.all(color: context.rpc.border),
            boxShadow: [context.rpc.cardShadow],
          ),
          padding: const EdgeInsets.all(RpcSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              MatchModeSelection(
                selectedModeId: _selectedMatchMode,
                onModeSelected: _onMatchModeSelected,
                compact: true,
              ),
              const SizedBox(height: RpcSpacing.md),
              _buildSessionSetupSection(selectedMode),
            ],
          ),
        ),
      );
  }

  Widget _buildSessionSetupSection(MatchModeDefinition selectedMode) {
    final c = context.rpc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RpcNetDivider(),
        const SizedBox(height: RpcSpacing.md),
        Container(
          padding: const EdgeInsets.all(RpcSpacing.md),
          decoration: BoxDecoration(
            color: c.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
            border: Border.all(color: c.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Session setup',
                style: RpcTypography.bodySemibold(context),
              ),
              const SizedBox(height: RpcSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: _selectedPresetId,
                      decoration: const InputDecoration(
                        labelText: 'Preset',
                        prefixIcon:
                            Icon(Icons.tune_rounded, size: 20),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Custom setup'),
                        ),
                        ..._presets.map(
                          (preset) => DropdownMenuItem<int?>(
                            value: preset.id,
                            child: Text(preset.name),
                          ),
                        ),
                      ],
                      onChanged: _loadingPresets
                          ? null
                          : (id) {
                              if (id == null) {
                                setState(() => _selectedPresetId = null);
                                return;
                              }
                              final preset =
                                  _presets.firstWhere((p) => p.id == id);
                              _applyPreset(preset);
                            },
                    ),
                  ),
                  const SizedBox(width: RpcSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _saveCurrentAsPreset,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RpcSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > RpcBreakpoints.compact;

                  Widget field(Widget child) =>
                      isWide ? Expanded(child: child) : child;

                  final fields = <Widget>[
                    field(
                      TextField(
                        controller: _pinController,
                        decoration: const InputDecoration(
                          labelText: 'Admin PIN',
                          prefixIcon:
                              Icon(Icons.lock_outline_rounded, size: 20),
                        ),
                        obscureText: true,
                        onChanged: (value) {
                          rpcAdminPinController.setPin(value);
                          _controller.setAdminPin(value);
                        },
                      ),
                    ),
                    field(
                      TextField(
                        controller: _sessionNameController,
                        decoration: const InputDecoration(
                          labelText: 'Session name',
                          hintText: 'Auto-updates with mode',
                          prefixIcon:
                              Icon(Icons.event_note_outlined, size: 20),
                        ),
                        onChanged: _onSessionNameChanged,
                      ),
                    ),
                    if (!selectedMode.forcesSingles)
                      field(
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _playFormat,
                          decoration: const InputDecoration(
                            labelText: 'Format',
                            prefixIcon:
                                Icon(Icons.people_outline_rounded, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'doubles',
                              child: Text('Doubles'),
                            ),
                            DropdownMenuItem(
                              value: 'singles',
                              child: Text('Singles'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _playFormat = v);
                          },
                        ),
                      ),
                    field(
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _courtCount,
                        decoration: const InputDecoration(
                          labelText: 'Courts',
                          prefixIcon:
                              Icon(Icons.sports_tennis_rounded, size: 20),
                        ),
                        items: List.generate(
                          8,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) setState(() => _courtCount = v);
                        },
                      ),
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < fields.length; i++) ...[
                          if (i > 0) const SizedBox(width: RpcSpacing.sm),
                          fields[i],
                        ],
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        if (i > 0) const SizedBox(height: RpcSpacing.sm),
                        fields[i],
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: RpcSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = constraints.maxWidth > 480;
            final autoAssign = AutoAssignToggle.forStartSession(
              value: _autoAssignEnabled,
              onChanged: (value) => setState(() => _autoAssignEnabled = value),
              compact: true,
            );
            final payment = RpcFeatureToggle(
              title: 'Session payment',
              subtitle: 'Collect fee before queue join',
              icon: Icons.payments_outlined,
              activeIcon: Icons.payments_rounded,
              value: _requirePayment,
              onChanged: (value) => setState(() => _requirePayment = value),
              compact: true,
            );

            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: autoAssign),
                  const SizedBox(width: RpcSpacing.sm),
                  Expanded(child: payment),
                ],
              );
            }

            return Column(
              children: [
                autoAssign,
                const SizedBox(height: RpcSpacing.sm),
                payment,
              ],
            );
          },
        ),
        if (_requirePayment) ...[
          const SizedBox(height: RpcSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 160,
              child: TextField(
                controller: _sessionFeeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Session fee (₱)',
                  hintText: '30',
                  prefixIcon: Icon(Icons.payments_outlined, size: 20),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed >= 0) {
                    setState(() => _sessionFeePesos = parsed);
                  }
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: RpcSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildStartSessionButton(selectedMode),
        ),
      ],
    );
  }

  Widget _buildStartSessionButton(MatchModeDefinition selectedMode) {
    final c = context.rpc;
    final isQuickStart = _selectedPresetId != null;
    final label = isQuickStart
        ? 'Quick Start Session'
        : 'Start ${selectedMode.name} Session';

    return FilledButton.icon(
      onPressed: _controller.loading ? null : _startSession,
      icon: _controller.loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.play_arrow_rounded, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: RpcPalette.onPrimaryForeground,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        minimumSize: const Size(0, 44),
        elevation: 2,
        shadowColor: c.primary.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
        ),
      ),
    );
  }

  Widget _buildSessionControls(SessionState state) {
    return AutoAssignToggle.forLiveSession(
      value: state.session.autoAssignEnabled,
      interactive: !_controller.loading,
      onChanged: _controller.loading
          ? null
          : (value) => _controller.setAutoAssignEnabled(value),
    );
  }

  Widget _buildSessionKpis(SessionState state) {
    final c = context.rpc;
    final playingCount = sessionPlayingPlayerCount(state);
    final waitingCount = sessionWaitingPlayerCount(state);
    final checkedInCount = state.rosterPlayerNames.length;
    final matchesDone = state.matchHistory.length;

    return Row(
      children: [
        RpcInlineStat(
          value: '$playingCount',
          label: 'playing',
          color: c.success,
        ),
        const SizedBox(width: RpcSpacing.md),
        RpcInlineStat(
          value: '$waitingCount',
          label: 'waiting',
          color: c.primary,
        ),
        const SizedBox(width: RpcSpacing.md),
        RpcInlineStat(
          value: '$checkedInCount',
          label: 'checked in',
          color: c.accentOrange,
        ),
        if (state.session.requirePayment && state.pendingPayments.isNotEmpty) ...[
          const SizedBox(width: RpcSpacing.md),
          RpcInlineStat(
            value: '${state.pendingPayments.length}',
            label: 'awaiting payment',
            color: c.warning,
          ),
        ],
        const Spacer(),
        Text(
          '$matchesDone match${matchesDone == 1 ? '' : 'es'} done',
          style: RpcTypography.caption(context).copyWith(
            color: c.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildUpNextSection(SessionState state) {
    final primary = state.primaryUpNext;
    final secondary = state.secondaryUpNext;

    if (primary == null && secondary == null) {
      return const SizedBox.shrink();
    }

    return RpcCard.compact(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RpcSectionHeader(
            title: 'Up Next',
            subtitle: 'Suggested groups for the next manual court assignment',
            compact: true,
          ),
          const SizedBox(height: RpcSpacing.sm),
          if (primary != null)
            NextUpGroupHeader(
              queueLabel: '${MatchModes.labelForQueue(primary.queueType)} — Next Up',
              playerNames:
                  primary.players.map((player) => player.name).toList(),
              groupSize: state.groupSize,
              ready: primary.ready,
              accentColor: MatchModes.accentForQueue(context, primary.queueType),
              isPriority: true,
            ),
          if (secondary != null) ...[
            const SizedBox(height: 10),
            NextUpGroupHeader(
              queueLabel:
                  '${MatchModes.labelForQueue(secondary.queueType)} — On Deck',
              playerNames:
                  secondary.players.map((player) => player.name).toList(),
              groupSize: state.groupSize,
              ready: secondary.ready,
              accentColor: MatchModes.accentForQueue(context, secondary.queueType),
              isPriority: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueSection(SessionState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= RpcBreakpoints.medium;
        final compact = constraints.maxWidth < RpcBreakpoints.compact;
        final panels = state.session.queueTypes.map((queueType) {
          return QueuePanel(
            title: MatchModes.labelForQueue(queueType),
            accentColor: MatchModes.accentForQueue(context, queueType),
            players: state.queues[queueType] ?? [],
            groupSize: state.groupSize,
            nextUpPlayerIds: state.nextUpPlayerIds,
            onDeckPlayerIds: state.onDeckPlayerIds,
            isPriorityQueue: _isPriorityQueue(state, queueType),
            onRemove: (id) => _controller.removePlayer(id),
            onEdit: _editPlayerName,
            compact: compact,
          );
        }).toList();

        if (isWide && panels.length > 1) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < panels.length; i++) ...[
                if (i > 0) const SizedBox(width: RpcSpacing.md),
                Expanded(child: panels[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < panels.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              panels[i],
            ],
          ],
        );
      },
    );
  }

  bool _isPriorityQueue(SessionState state, String queueType) {
    if (state.session.queueTypes.contains('winner')) {
      return state.session.nextCourtQueue == queueType;
    }

    return state.primaryUpNext?.queueType == queueType;
  }

}
