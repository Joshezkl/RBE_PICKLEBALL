import 'package:flutter/material.dart';

import '../../core/admin_nav.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/admin_pin_controller.dart';
import '../../main.dart' show rpcThemeController;
import 'player_management_modal.dart';

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key, this.adminPin});

  final String? adminPin;

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  late final SessionController _controller;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    final pin = widget.adminPin ?? rpcAdminPinController.pin;
    _api = ApiClient(adminPin: pin);
    _controller = SessionController(apiClient: _api);
    _controller.setAdminPin(pin);
    _controller.initialize();
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
      activeDestination: RpcNavDestination.players,
      pageTitle: 'Players',
      pageSubtitle: state?.session.isActive == true
          ? 'Registry and session roster for ${state!.session.name}'
          : 'Club registry — start a session to add players to tonight\'s roster',
      themeController: rpcThemeController,
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
      sessionId: state?.session.id,
      navDestinations: adminNavDestinations,
      maxWidth: 960,
      fillViewport: true,
      body: PlayerManagementPanel(
          api: _api,
          sessionController: _controller,
          activeSessionId: state?.session.id,
          rosterPlayerNames: state?.rosterPlayerNames ?? const {},
          matchMode: state?.session.matchMode,
          requirePayment: state?.session.requirePayment ?? false,
          sessionFeeCents: state?.session.sessionFeeCents ?? 0,
        ),
    );
  }
}

/// Reusable player registry UI (page or modal).
class PlayerManagementPanel extends StatelessWidget {
  const PlayerManagementPanel({
    super.key,
    required this.api,
    this.sessionController,
    this.activeSessionId,
    this.rosterPlayerNames = const {},
    this.matchMode,
    this.requirePayment = false,
    this.sessionFeeCents = 0,
  });

  final ApiClient api;
  final SessionController? sessionController;
  final int? activeSessionId;
  final Set<String> rosterPlayerNames;
  final String? matchMode;
  final bool requirePayment;
  final int sessionFeeCents;

  @override
  Widget build(BuildContext context) {
    return PlayerManagementModal(
      api: api,
      sessionController: sessionController,
      activeSessionId: activeSessionId,
      rosterPlayerNames: rosterPlayerNames,
      matchMode: matchMode,
      requirePayment: requirePayment,
      sessionFeeCents: sessionFeeCents,
      embedded: true,
    );
  }
}
