import 'package:flutter/material.dart';

import 'package:flutter/services.dart';



import '../../core/display/display_cue_controller.dart';

import '../../core/display_url.dart';

import '../../core/models.dart';

import '../../core/theme/rpc_palette.dart';

import '../../core/theme/rpc_spacing.dart';

import '../../core/theme/rpc_typography.dart';

import '../../core/widgets/brand_logo.dart';

import '../../core/widgets/theme_toggle_button.dart';

import '../../main.dart' show rpcThemeController;

import '../../core/decor/rpc_court_background.dart';

import '../../core/decor/rpc_decor_empty_state.dart';

import '../../core/decor/rpc_decor_theme.dart';

import 'audio_toggle_button.dart';

import 'celebration_overlay.dart';

import 'display_court_card.dart';

import 'display_challenge_court_queue_panel.dart';
import 'display_top_performers_panel.dart';
import 'display_up_next_panel.dart';
import '../../core/widgets/rpc_inline_stat.dart';



/// Fullscreen TV / kiosk board — no nav, large type, auto-refresh, voice cues.

class DisplayPage extends StatefulWidget {

  const DisplayPage({super.key});



  @override

  State<DisplayPage> createState() => _DisplayPageState();

}



class _DisplayPageState extends State<DisplayPage> {

  late final DisplayCueController _controller;



  @override

  void initState() {

    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    rpcThemeController.setMode(ThemeMode.dark);



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

    final c = context.rpc;



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

            child: state == null

                ? _EmptyDisplay(loading: _controller.loading)

                : _DisplayBody(

                    controller: _controller,

                    state: state,

                  ),

          ),

          if (_controller.celebration != null)

            CelebrationOverlay(

              celebration: _controller.celebration!,

              onDismiss: _controller.dismissCelebration,

            ),

        ],

      ),

    );

  }

}



class _DisplayBody extends StatelessWidget {

  const _DisplayBody({

    required this.controller,

    required this.state,

  });



  final DisplayCueController controller;

  final SessionState state;



  @override

  Widget build(BuildContext context) {

    final slotsPerTeam = state.session.playFormat == 'singles' ? 1 : 2;

    final playingCount = sessionPlayingPlayerCount(state);

    final waitingCount = sessionWaitingPlayerCount(state);

    final checkedInCount = state.rosterPlayerNames.length;

    final matchesDone = state.matchHistory.length;

    final courts = [...state.courts]

      ..sort((a, b) {

        final aLive = a.status == 'in_match' ? 0 : 1;

        final bLive = b.status == 'in_match' ? 0 : 1;

        if (aLive != bLive) return aLive.compareTo(bLive);

        return a.courtNumber.compareTo(b.courtNumber);

      });



    return Padding(

      padding: const EdgeInsets.symmetric(

        horizontal: RpcSpacing.lg,

        vertical: RpcSpacing.md,

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          _DisplayHeader(

            state: state,

            playingCount: playingCount,

            waitingCount: waitingCount,

            checkedInCount: checkedInCount,

            matchesDone: matchesDone,

            audioEnabled: controller.audioUnlocked,

            onAudioChanged: controller.setAudioEnabled,

          ),

          const SizedBox(height: RpcSpacing.md),
          _CourtsSectionHeader(
            liveCount: state.courts.where((c) => c.status == 'in_match').length,
            matchesDone: matchesDone,
          ),
          const SizedBox(height: RpcSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final useScroll = courts.length > 4;
              final cardWidth = useScroll
                  ? 240.0
                  : (constraints.maxWidth - gap * (courts.length - 1)) /
                      courts.length;

              final cards = [
                for (final court in courts)
                  SizedBox(
                    width: cardWidth,
                    child: DisplayCourtCard(
                      court: court,
                      slotsPerTeam: slotsPerTeam,
                      compact: true,
                      challengeCourtIsOpen: state.challengeCourt.isOpen,
                      flashing: controller.flashingCourts
                          .contains(court.courtNumber),
                      onRepeatAnnouncement:
                          controller.canRepeatCourtAssignment(
                                court.courtNumber,
                              )
                              ? () {
                                  controller.repeatCourtAssignment(
                                    court.courtNumber,
                                  );
                                }
                              : null,
                    ),
                  ),
              ];

              if (useScroll) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: RpcSpacing.md),
          Expanded(
            child: _BottomPanels(
              state: state,
              slotsPerTeam: slotsPerTeam,
              leaderboard: controller.leaderboard,
            ),
          ),

        ],

      ),

    );

  }

}



class _BottomPanels extends StatelessWidget {
  const _BottomPanels({
    required this.state,
    required this.slotsPerTeam,
    required this.leaderboard,
  });

  final SessionState state;
  final int slotsPerTeam;
  final List<LeaderboardEntry> leaderboard;

  @override
  Widget build(BuildContext context) {
    final ccOpen = state.challengeCourt.isOpen;
    final gap = ccOpen ? RpcSpacing.sm : RpcSpacing.md;

    if (!ccOpen) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: DisplayUpNextPanel(
              state: state,
              slotsPerTeam: slotsPerTeam,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            flex: 2,
            child: DisplayTopPerformersPanel(entries: leaderboard),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: DisplayUpNextPanel(
            state: state,
            slotsPerTeam: slotsPerTeam,
            title: 'Session Queue',
            compact: true,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 5,
          child: DisplayChallengeCourtQueuePanel(
            state: state,
            slotsPerTeam: slotsPerTeam,
            compact: true,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: 4,
          child: DisplayTopPerformersPanel(
            entries: leaderboard,
            compact: true,
          ),
        ),
      ],
    );
  }
}



class _DisplayHeader extends StatelessWidget {

  const _DisplayHeader({

    required this.state,

    required this.playingCount,

    required this.waitingCount,

    required this.checkedInCount,

    required this.matchesDone,

    required this.audioEnabled,

    required this.onAudioChanged,

  });



  final SessionState state;

  final int playingCount;

  final int waitingCount;

  final int checkedInCount;

  final int matchesDone;

  final bool audioEnabled;

  final ValueChanged<bool> onAudioChanged;



  @override

  Widget build(BuildContext context) {

    final c = context.rpc;



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Row(

          crossAxisAlignment: CrossAxisAlignment.center,

          children: [

            const BrandLogo(height: 56),

            const SizedBox(width: RpcSpacing.md),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    'ROSALES PICKLEBALL CLUB · VENUE DISPLAY',

                    style: RpcTypography.overline(context).copyWith(

                      fontSize: 10,

                      letterSpacing: 1.5,

                      color: c.textMuted,

                    ),

                  ),

                  const SizedBox(height: 2),

                  Text(

                    state.session.name,

                    style: RpcTypography.display(context).copyWith(

                      fontSize: 24,

                      fontWeight: FontWeight.w800,

                    ),

                  ),

                ],

              ),

            ),

            const SizedBox(width: RpcSpacing.sm),

            _DisplayToolbar(
              audioEnabled: audioEnabled,
              onAudioChanged: onAudioChanged,
            ),

            const SizedBox(width: RpcSpacing.sm),

            const _LiveClock(),

          ],

        ),

        const SizedBox(height: RpcSpacing.sm),

        Row(

          children: [

            RpcInlineStat(value: '$playingCount', label: 'playing', color: c.success),

            const SizedBox(width: RpcSpacing.md),

            RpcInlineStat(value: '$waitingCount', label: 'waiting', color: c.primary),

            const SizedBox(width: RpcSpacing.md),

            RpcInlineStat(

              value: '$checkedInCount',

              label: 'checked in',

              color: c.accentOrange,

            ),

            const Spacer(),

            Text(

              '$matchesDone match${matchesDone == 1 ? '' : 'es'} done',

              style: RpcTypography.caption(context).copyWith(

                color: c.textMuted,

                fontSize: 12,

              ),

            ),

          ],

        ),

      ],

    );

  }

}



class _DisplayToolbar extends StatelessWidget {
  const _DisplayToolbar({
    required this.audioEnabled,
    required this.onAudioChanged,
  });

  final bool audioEnabled;
  final ValueChanged<bool> onAudioChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final showAudio = displayAnnounceEnabledFromUri() ||
        displaySoundsEnabledFromUri();

    return Material(
      color: c.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAudio)
            AudioToggleButton(
              enabled: audioEnabled,
              onChanged: onAudioChanged,
              compact: true,
            ),
          ThemeToggleButton(controller: rpcThemeController),
        ],
      ),
    );
  }
}



class _CourtsSectionHeader extends StatelessWidget {

  const _CourtsSectionHeader({

    required this.liveCount,

    required this.matchesDone,

  });



  final int liveCount;

  final int matchesDone;



  @override

  Widget build(BuildContext context) {

    final c = context.rpc;

    return Row(

      children: [

        Icon(Icons.sports_tennis_rounded, size: 18, color: c.primary),

        const SizedBox(width: 8),

        Text(

          'Courts now playing',

          style: RpcTypography.bodyBold(context).copyWith(fontSize: 15),

        ),

        if (liveCount > 0) ...[

          const SizedBox(width: 8),

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

            decoration: BoxDecoration(

              color: c.success.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(8),

            ),

            child: Text(

              '$liveCount live',

              style: RpcTypography.caption(context).copyWith(

                color: c.success,

                fontWeight: FontWeight.w600,

                fontSize: 10,

              ),

            ),

          ),

        ],

        const Spacer(),

        if (matchesDone > 0)

          Text(

            '$matchesDone completed',

            style: RpcTypography.caption(context).copyWith(color: c.textMuted),

          ),

      ],

    );

  }

}



class _LiveClock extends StatefulWidget {

  const _LiveClock();



  @override

  State<_LiveClock> createState() => _LiveClockState();

}



class _LiveClockState extends State<_LiveClock>

    with SingleTickerProviderStateMixin {

  late DateTime _now;

  late AnimationController _pulse;



  @override

  void initState() {

    super.initState();

    _now = DateTime.now();

    _pulse = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 1400),

    )..repeat(reverse: true);

    Future.doWhile(() async {

      await Future.delayed(const Duration(seconds: 30));

      if (!mounted) return false;

      setState(() => _now = DateTime.now());

      return true;

    });

  }



  @override

  void dispose() {

    _pulse.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final hour = _now.hour > 12

        ? _now.hour - 12

        : (_now.hour == 0 ? 12 : _now.hour);

    final period = _now.hour >= 12 ? 'PM' : 'AM';

    final minute = _now.minute.toString().padLeft(2, '0');

    final c = context.rpc;



    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        Container(

          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

          decoration: BoxDecoration(

            color: c.success.withValues(alpha: 0.12),

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: c.success.withValues(alpha: 0.35)),

          ),

          child: Row(

            mainAxisSize: MainAxisSize.min,

            children: [

              FadeTransition(

                opacity: Tween<double>(begin: 0.35, end: 1).animate(

                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),

                ),

                child: Icon(

                  Icons.fiber_manual_record_rounded,

                  size: 8,

                  color: c.success,

                ),

              ),

              const SizedBox(width: 6),

              Text(

                'LIVE',

                style: RpcTypography.labelSemibold(context).copyWith(

                  color: c.success,

                  letterSpacing: 1.2,

                  fontSize: 11,

                ),

              ),

            ],

          ),

        ),

        const SizedBox(width: 10),

        Icon(Icons.schedule_outlined, size: 14, color: c.textMuted),

        const SizedBox(width: 4),

        Text(

          '$hour:$minute $period',

          style: RpcTypography.bodySemibold(context).copyWith(

            fontSize: 13,

            color: c.textMuted,

          ),

        ),

      ],

    );

  }

}



class _EmptyDisplay extends StatelessWidget {

  const _EmptyDisplay({required this.loading});



  final bool loading;



  @override

  Widget build(BuildContext context) {

    return Center(

      child: loading

          ? const CircularProgressIndicator()

          : RpcDecorEmptyState(

              title: 'Waiting for Session',

              subtitle: 'Start a session from the admin dashboard',

              icon: Icons.tv_outlined,

            ),

    );

  }

}


