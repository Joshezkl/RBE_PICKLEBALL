import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/decor/rpc_court_accent.dart';
import '../../core/decor/rpc_court_background.dart';
import '../../core/decor/rpc_decor_empty_state.dart';
import '../../core/decor/rpc_decor_theme.dart';
import '../../core/display/display_cue_controller.dart';
import '../../core/display_url.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../main.dart' show rpcThemeController;
import 'audio_toggle_button.dart';
import 'display_court_card.dart';

/// Per-court tablet signage: "Court N — Now playing / Up next".
class CourtSignagePage extends StatefulWidget {
  const CourtSignagePage({super.key, this.courtNumber});

  final int? courtNumber;

  @override
  State<CourtSignagePage> createState() => _CourtSignagePageState();
}

class _CourtSignagePageState extends State<CourtSignagePage> {
  late final DisplayCueController _controller;
  late final int? _courtNumber;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    rpcThemeController.setMode(ThemeMode.dark);

    _courtNumber = widget.courtNumber ?? courtNumberFromUri();
    _controller = DisplayCueController(
      announceEnabled: displayAnnounceEnabledFromUri(),
      soundsEnabled: displaySoundsEnabledFromUri(),
    )..addListener(_onUpdate);
    _controller.initialize();
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final courtNumber = _courtNumber;
    final c = context.rpc;

    CourtInfo? court;
    if (state != null && courtNumber != null) {
      for (final c in state.courts) {
        if (c.courtNumber == courtNumber) {
          court = c;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RpcCourtBackground(
            intensity: RpcDecorIntensity.venue,
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: state == null || courtNumber == null
                ? _SignageEmpty(
                    loading: _controller.loading,
                    courtNumber: courtNumber,
                  )
                : court == null
                    ? _SignageEmpty(
                        loading: false,
                        courtNumber: courtNumber,
                        notFound: true,
                      )
                    : _SignageBody(
                        controller: _controller,
                        state: state,
                        court: court,
                        flashing: _controller.flashingCourts
                            .contains(court.courtNumber),
                      ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(RpcSpacing.sm),
                child: Material(
                  color: c.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayAnnounceEnabledFromUri() ||
                          displaySoundsEnabledFromUri())
                        AudioToggleButton(
                          enabled: _controller.audioUnlocked,
                          onChanged: (enabled) {
                            _controller.setAudioEnabled(enabled);
                          },
                        ),
                      ThemeToggleButton(controller: rpcThemeController),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignageBody extends StatelessWidget {
  const _SignageBody({
    required this.controller,
    required this.state,
    required this.court,
    required this.flashing,
  });

  final DisplayCueController controller;
  final SessionState state;
  final CourtInfo court;
  final bool flashing;

  @override
  Widget build(BuildContext context) {
    final slotsPerTeam = state.session.playFormat == 'singles' ? 1 : 2;
    final isActive = court.status == 'in_match';
    final upNextPlayers = _upNextForCourt(state, court);

    return Padding(
      padding: const EdgeInsets.all(RpcSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Court ${court.courtNumber}',
                      style: RpcTypography.display(context).copyWith(fontSize: 48),
                    ),
                    Text(
                      state.session.name,
                      style: RpcTypography.bodyMuted(context).copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              if (isActive &&
                  controller.canRepeatCourtAssignment(court.courtNumber))
                FilledButton.icon(
                  onPressed: () {
                    controller.repeatCourtAssignment(court.courtNumber);
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Repeat'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RpcSpacing.lg,
                      vertical: RpcSpacing.md,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RpcSpacing.xl),
          Text(
            'NOW PLAYING',
            style: RpcTypography.overline(context).copyWith(
              fontSize: 14,
              letterSpacing: 2,
              color: context.rpc.textMuted,
            ),
          ),
          const SizedBox(height: RpcSpacing.md),
          if (isActive && court.match != null) ...[
            DisplayCourtCard(
              court: court,
              slotsPerTeam: slotsPerTeam,
              compact: true,
              flashing: flashing,
              onRepeatAnnouncement:
                  controller.canRepeatCourtAssignment(court.courtNumber)
                      ? () {
                          controller.repeatCourtAssignment(court.courtNumber);
                        }
                      : null,
            ),
          ] else
            RpcCourtAccent(
              active: false,
              highlight: true,
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(RpcSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.sports_tennis_rounded,
                    size: 48,
                    color: context.rpc.success,
                  ),
                  const SizedBox(height: RpcSpacing.md),
                  Text(
                    'Court Open',
                    style: RpcTypography.headline(context).copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: RpcSpacing.sm),
                  Text(
                    'Waiting for next assignment',
                    style: RpcTypography.bodyMuted(context),
                  ),
                ],
              ),
            ),
          const SizedBox(height: RpcSpacing.xl),
          Text(
            'UP NEXT',
            style: RpcTypography.overline(context).copyWith(
              fontSize: 14,
              letterSpacing: 2,
              color: context.rpc.textMuted,
            ),
          ),
          const SizedBox(height: RpcSpacing.md),
          _UpNextStrip(
            players: upNextPlayers,
            ready: state.canAssignNextForCourt(court),
          ),
        ],
      ),
    );
  }

  List<QueuePlayer> _upNextForCourt(SessionState state, CourtInfo court) {
    final groupSize = state.groupSize;
    if (state.session.matchMode == 'skill_courts' && court.skillBracket != null) {
      for (final group in state.upNext) {
        if (group.queueType == court.skillBracket) {
          return group.players.take(groupSize).toList();
        }
      }
      return [];
    }
    return state.primaryUpNext?.players.take(groupSize).toList() ?? [];
  }
}

class _UpNextStrip extends StatelessWidget {
  const _UpNextStrip({
    required this.players,
    required this.ready,
  });

  final List<QueuePlayer> players;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      padding: const EdgeInsets.all(RpcSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ready ? c.success.withValues(alpha: 0.5) : c.border,
          width: ready ? 2 : 1,
        ),
      ),
      child: players.isEmpty
          ? Text(
              'No players queued yet',
              style: RpcTypography.bodyMuted(context).copyWith(fontSize: 18),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ready ? 'Ready to play' : 'Waiting for players',
                  style: RpcTypography.bodyBold(context).copyWith(
                    fontSize: 18,
                    color: ready ? c.success : c.textMuted,
                  ),
                ),
                const SizedBox(height: RpcSpacing.md),
                for (final player in players)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${player.position}',
                            style: RpcTypography.bodyBold(context).copyWith(
                              color: c.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          player.name,
                          style: RpcTypography.title(context).copyWith(
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SignageEmpty extends StatelessWidget {
  const _SignageEmpty({
    required this.loading,
    this.courtNumber,
    this.notFound = false,
  });

  final bool loading;
  final int? courtNumber;
  final bool notFound;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: loading
          ? const CircularProgressIndicator()
          : RpcDecorEmptyState(
              title: courtNumber == null
                  ? 'Court number required'
                  : notFound
                      ? 'Court $courtNumber not found'
                      : 'No active session',
              subtitle: courtNumber == null ? 'Open #/court?n=3' : null,
              icon: Icons.tablet_rounded,
              compact: true,
            ),
    );
  }
}
