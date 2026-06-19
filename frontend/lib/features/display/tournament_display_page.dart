import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/decor/rpc_court_background.dart';
import '../../core/decor/rpc_decor_empty_state.dart';
import '../../core/decor/rpc_decor_theme.dart';
import '../../core/display_url.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/tournament_display_cue_controller.dart';
import '../../core/tournament_models.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/court_match_layout.dart';
import '../../core/widgets/tournament_court_helpers.dart';
import '../../core/widgets/tournament_up_next_strip.dart';
import '../../main.dart' show rpcThemeController;
import 'display_header_controls.dart';
import 'tournament_celebration_overlay.dart';

class TournamentDisplayPage extends StatefulWidget {
  const TournamentDisplayPage({super.key});

  @override
  State<TournamentDisplayPage> createState() => _TournamentDisplayPageState();
}

class _TournamentDisplayPageState extends State<TournamentDisplayPage> {
  late final TournamentDisplayCueController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    rpcThemeController.setMode(ThemeMode.dark);
    _controller = TournamentDisplayCueController(
      announcementsEnabled: tournamentAnnouncementsEnabledFromUri(),
      celebrationsEnabled: tournamentCelebrationsEnabledFromUri(),
      voiceEnabled: tournamentVoiceEnabledFromUri(),
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
    final c = context.rpc;
    final state = _controller.state;

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
                ? Center(
                    child: RpcDecorEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: _controller.loading
                          ? 'Loading tournament…'
                          : 'No live tournament',
                      subtitle: _controller.error ??
                          'Start a tournament from admin to show court assignments here.',
                    ),
                  )
                : _TournamentDisplayBody(
                    state: state,
                    display: state.display,
                    audioEnabled: _controller.audioUnlocked,
                    onAudioChanged: _controller.setAudioEnabled,
                  ),
          ),
          if (_controller.celebration != null)
            TournamentCelebrationOverlay(
              celebration: _controller.celebration!,
              onDismiss: _controller.dismissCelebration,
            ),
        ],
      ),
    );
  }
}

class _TournamentDisplayBody extends StatelessWidget {
  const _TournamentDisplayBody({
    required this.state,
    required this.display,
    required this.audioEnabled,
    required this.onAudioChanged,
  });

  final TournamentState state;
  final TournamentDisplayState? display;
  final bool audioEnabled;
  final ValueChanged<bool> onAudioChanged;

  static double courtCardHeightFor(int slotsPerTeam) =>
      tournamentCourtCardHeightFor(slotsPerTeam);

  @override
  Widget build(BuildContext context) {
    final courts = display?.courts ?? [];
    final upNext = display?.upNext ?? [];
    final recent = display?.recentResults ?? [];
    final activeCategory = display?.activeCategory;
    final liveCount = courts.where((court) => court.isActive).length;
    final maxSlotsPerTeam = courts.fold(
      1,
      (max, court) =>
          _slotsPerTeam(court.match) > max ? _slotsPerTeam(court.match) : max,
    );
    final courtCardHeight = courtCardHeightFor(maxSlotsPerTeam);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RpcSpacing.lg,
        vertical: RpcSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TournamentDisplayHeader(
            tournamentName: state.tournament.name,
            activeCategory: activeCategory,
            liveCount: liveCount,
            courtCount: state.tournament.courtCount,
            audioEnabled: audioEnabled,
            onAudioChanged: onAudioChanged,
          ),
          const SizedBox(height: RpcSpacing.sm),
          Text(
            'Courts now playing',
            style: RpcTypography.bodyBold(context).copyWith(fontSize: 14),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: courtCardHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final useScroll = courts.length > 4;
                final cardWidth = useScroll
                    ? 200.0
                    : (constraints.maxWidth - gap * (courts.length - 1)) /
                        courts.length;

                final cards = [
                  for (final court in courts)
                    SizedBox(
                      width: cardWidth,
                      child: _TournamentCourtCard(
                        court: court,
                        slotsPerTeam: _slotsPerTeam(court.match),
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
          const SizedBox(height: RpcSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: TournamentUpNextPanel(
                    matches: upNext,
                    emptyMessage:
                        'All round robin matches are on court or finished',
                  ),
                ),
                const SizedBox(width: RpcSpacing.md),
                Expanded(
                  flex: 2,
                  child: _TournamentRecentResultsPanel(results: recent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _slotsPerTeam(TournamentCourtMatchInfo? match) {
    final fromNames = tournamentSlotsFromTeamNames(match?.teamA, match?.teamB);
    if (fromNames > 0) return fromNames;

    final key = display?.activeCategory?.key ?? '';
    return tournamentSlotsPerTeamForCategoryKey(key);
  }
}

class _TournamentDisplayHeader extends StatelessWidget {
  const _TournamentDisplayHeader({
    required this.tournamentName,
    required this.activeCategory,
    required this.liveCount,
    required this.courtCount,
    required this.audioEnabled,
    required this.onAudioChanged,
  });

  final String tournamentName;
  final TournamentActiveCategoryInfo? activeCategory;
  final int liveCount;
  final int courtCount;
  final bool audioEnabled;
  final ValueChanged<bool> onAudioChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Row(
      children: [
        const BrandLogo(height: 28),
        const SizedBox(width: RpcSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROSALES PICKLEBALL CLUB · TOURNAMENT DISPLAY',
                style: RpcTypography.caption(context).copyWith(
                  color: c.textMuted,
                  letterSpacing: 0.6,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tournamentName,
                style: RpcTypography.title(context).copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  '$liveCount playing',
                  '$courtCount courts',
                  if (activeCategory != null) activeCategory!.label,
                ].join(' · '),
                style: RpcTypography.caption(context).copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                'Venue display only — enter scores in Admin → Tournaments',
                style: RpcTypography.caption(context).copyWith(
                  color: c.textMuted.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: RpcSpacing.sm),
        DisplayToolbar(
          audioEnabled: audioEnabled,
          onAudioChanged: onAudioChanged,
          showAudio: tournamentDisplayShowAudio(),
        ),
        const SizedBox(width: RpcSpacing.sm),
        const DisplayLiveClock(),
      ],
    );
  }
}

class _TournamentCourtCard extends StatelessWidget {
  const _TournamentCourtCard({
    required this.court,
    required this.slotsPerTeam,
  });

  final TournamentCourtInfo court;
  final int slotsPerTeam;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isActive = court.isActive;
    final isAssigned = court.isAssigned;
    final match = court.match;
    final layoutMatch = tournamentCourtMatchForLayout(match, slotsPerTeam);
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

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? c.primary.withValues(alpha: 0.45)
              : isAssigned
                  ? c.accentOrange.withValues(alpha: 0.35)
                  : c.border.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Court ${court.courtNumber}',
                  style: RpcTypography.bodySemibold(context).copyWith(
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                statusLabel,
                style: RpcTypography.caption(context).copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          if (match?.groupLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              match!.groupLabel!,
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
              slotsPerTeam: slotsPerTeam,
              dense: true,
              showTeamLabels: false,
            ),
          ),
          if (match != null &&
              match.scoreA != null &&
              match.scoreB != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.primary.withValues(alpha: 0.22)),
              ),
              child: Text(
                '${match.scoreA}  –  ${match.scoreB}',
                textAlign: TextAlign.center,
                style: RpcTypography.bodySemibold(context).copyWith(
                  color: c.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TournamentRecentResultsPanel extends StatelessWidget {
  const _TournamentRecentResultsPanel({required this.results});

  final List<TournamentRecentResultInfo> results;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, size: 18, color: c.accentOrange),
                const SizedBox(width: 8),
                Text(
                  'Recent results',
                  style: RpcTypography.bodyBold(context).copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      'No results yet',
                      style: RpcTypography.bodyMuted(context),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _TournamentRecentResultCard(
                        result: results[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TournamentRecentResultCard extends StatelessWidget {
  const _TournamentRecentResultCard({required this.result});

  final TournamentRecentResultInfo result;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final scoreA = result.scoreA ?? 0;
    final scoreB = result.scoreB ?? 0;
    final teamAWins = scoreA > scoreB;
    final slotsPerTeam = tournamentSlotsFromTeamNames(result.teamA, result.teamB);
    final effectiveSlots = slotsPerTeam > 0 ? slotsPerTeam : 1;
    final layoutMatch = tournamentCourtMatchForLayout(
      TournamentCourtMatchInfo(
        id: result.id,
        categoryLabel: result.categoryLabel,
        phase: 'finished',
        teamA: result.teamA,
        teamB: result.teamB,
        scoreA: result.scoreA,
        scoreB: result.scoreB,
      ),
      effectiveSlots,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (result.groupLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.groupLabel!,
                    style: RpcTypography.caption(context).copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              const Spacer(),
              Icon(
                Icons.emoji_events_rounded,
                size: 14,
                color: c.accentOrange.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              _ResultSideHighlights(
                teamAWins: teamAWins,
                teamBWins: scoreB > scoreA,
                child: CourtMatchLayout(
                  match: layoutMatch,
                  slotsPerTeam: effectiveSlots,
                  dense: true,
                  showTeamLabels: false,
                ),
              ),
              _ResultScoreBadge(scoreA: scoreA, scoreB: scoreB),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            result.categoryLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RpcTypography.caption(context).copyWith(
              color: c.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSideHighlights extends StatelessWidget {
  const _ResultSideHighlights({
    required this.teamAWins,
    required this.teamBWins,
    required this.child,
  });

  final bool teamAWins;
  final bool teamBWins;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!teamAWins && !teamBWins) return child;

    final c = context.rpc;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            teamAWins ? c.primary.withValues(alpha: 0.12) : Colors.transparent,
            Colors.transparent,
            teamBWins ? c.primary.withValues(alpha: 0.12) : Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class _ResultScoreBadge extends StatelessWidget {
  const _ResultScoreBadge({
    required this.scoreA,
    required this.scoreB,
  });

  final int scoreA;
  final int scoreB;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.text.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$scoreA – $scoreB',
        style: RpcTypography.caption(context).copyWith(
          fontWeight: FontWeight.w800,
          color: c.primary,
          fontSize: 12,
        ),
      ),
    );
  }
}
