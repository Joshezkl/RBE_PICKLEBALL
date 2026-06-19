import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/admin_nav.dart';
import '../../core/api_client.dart';
import '../../core/session_controller.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/check_in_qr_panel.dart';
import '../../core/widgets/rpc_card.dart';
import '../../core/widgets/rpc_shell.dart';
import '../../core/admin_pin_controller.dart';
import '../../main.dart' show rpcThemeController;

class DisplaysHubPage extends StatefulWidget {
  const DisplaysHubPage({super.key, this.adminPin});

  final String? adminPin;

  @override
  State<DisplaysHubPage> createState() => _DisplaysHubPageState();
}

class _DisplaysHubPageState extends State<DisplaysHubPage> {
  late final SessionController _controller;
  final _api = ApiClient();
  String? _checkInToken;
  int? _sessionId;
  int _courtCount = 4;
  String? _liveTournamentName;
  int _tournamentCourtCount = 4;

  @override
  void initState() {
    super.initState();
    _controller = SessionController();
    _controller.setAdminPin(widget.adminPin ?? rpcAdminPinController.pin);
    _controller.initialize(readOnly: true).then((_) {
      if (!mounted) return;
      final state = _controller.state;
      setState(() {
        _checkInToken = state?.session.checkInToken;
        _sessionId = state?.session.id;
        _courtCount = state?.session.courtCount ?? 4;
      });
    });
    _loadLiveTournament();
  }

  Future<void> _loadLiveTournament() async {
    try {
      final state = await _api.getActiveTournament();
      if (!mounted) return;
      setState(() {
        _liveTournamentName = state?.tournament.name;
        _tournamentCourtCount = state?.tournament.courtCount ?? 4;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveTournamentName = null;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _origin {
    final base = Uri.base;
    final port = base.hasPort ? ':${base.port}' : '';
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return '${base.scheme}://${base.host}$port$path';
  }

  void _openRoute(String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionName = _controller.state?.session.name;

    return RpcShell(
      activeDestination: RpcNavDestination.displays,
      pageTitle: 'Venue Displays',
      pageSubtitle: sessionName != null
          ? '$sessionName · open on TVs and court tablets'
          : 'Links for wall displays and court-end tablets',
      themeController: rpcThemeController,
      adminPin: widget.adminPin ?? rpcAdminPinController.pin,
      sessionId: _sessionId,
      navDestinations: adminNavDestinations,
      maxWidth: 960,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= RpcBreakpoints.compact;
              final cards = [
                _DisplayLinkCard(
                  title: 'TV Mode',
                  subtitle: 'Fullscreen kiosk with voice announcements and match celebrations',
                  icon: Icons.cast_rounded,
                  accent: context.rpc.accentOrange,
                  onOpen: () => _openRoute('/display'),
                  onCopy: () => _copyLink('$_origin#/display'),
                ),
                _DisplayLinkCard(
                  title: 'Public Board',
                  subtitle: 'Lighter overview with nav — good for a secondary screen',
                  icon: Icons.tv_outlined,
                  accent: context.rpc.primary,
                  onOpen: () => _openRoute('/board'),
                  onCopy: () => _copyLink('$_origin#/board'),
                ),
              ];

              if (twoCol) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: RpcSpacing.md),
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: RpcSpacing.md),
                  cards[1],
                ],
              );
            },
          ),
          const SizedBox(height: RpcSpacing.lg),
          RpcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tournament display', style: RpcTypography.title(context)),
                const SizedBox(height: RpcSpacing.sm),
                Text(
                  _liveTournamentName != null
                      ? '$_liveTournamentName · auto court assignments for $_tournamentCourtCount courts'
                      : 'Fullscreen court board for the live tournament — opens when a tournament is in progress.',
                  style: RpcTypography.bodyMuted(context),
                ),
                const SizedBox(height: RpcSpacing.md),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => _openRoute('/tournament-display'),
                      child: const Text('Open'),
                    ),
                    const SizedBox(width: RpcSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _copyLink('$_origin#/tournament-display'),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Copy link'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: RpcSpacing.lg),
          RpcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Per-court tablets', style: RpcTypography.title(context)),
                const SizedBox(height: RpcSpacing.sm),
                Text(
                  'Pin a tablet at each court end — shows now playing and up next for that court.',
                  style: RpcTypography.bodyMuted(context),
                ),
                const SizedBox(height: RpcSpacing.md),
                Wrap(
                  spacing: RpcSpacing.sm,
                  runSpacing: RpcSpacing.sm,
                  children: List.generate(_courtCount, (i) {
                    final n = i + 1;
                    final url = '$_origin#/court?n=$n';
                    return OutlinedButton.icon(
                      onPressed: () => _copyLink(url),
                      icon: const Icon(Icons.tablet_rounded, size: 18),
                      label: Text('Court $n'),
                    );
                  }),
                ),
              ],
            ),
          ),
          if (_checkInToken != null && sessionName != null) ...[
            const SizedBox(height: RpcSpacing.lg),
            CheckInQrPanel(
              sessionName: sessionName,
              checkInToken: _checkInToken!,
            ),
          ],
        ],
      ),
    );
  }
}

class _DisplayLinkCard extends StatelessWidget {
  const _DisplayLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onOpen,
    required this.onCopy,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return RpcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: RpcSpacing.md),
              Expanded(
                child: Text(title, style: RpcTypography.title(context)),
              ),
            ],
          ),
          const SizedBox(height: RpcSpacing.sm),
          Text(subtitle, style: RpcTypography.bodyMuted(context)),
          const SizedBox(height: RpcSpacing.md),
          Row(
            children: [
              FilledButton(
                onPressed: onOpen,
                child: const Text('Open'),
              ),
              const SizedBox(width: RpcSpacing.sm),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Copy link'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
