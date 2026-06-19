import 'package:flutter/material.dart';

import '../../core/decor/rpc_court_accent.dart';
import '../../core/models.dart';
import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_spacing.dart';
import '../../core/theme/rpc_typography.dart';
import '../../core/widgets/challenge_court_closed_placeholder.dart';
import '../../core/widgets/court_match_layout.dart';
import '../../core/widgets/court_timer.dart';
import 'display_cc_badge.dart';

class DisplayCourtCard extends StatelessWidget {
  const DisplayCourtCard({
    super.key,
    required this.court,
    required this.slotsPerTeam,
    this.flashing = false,
    this.compact = false,
    this.hero = false,
    this.venue = false,
    this.challengeCourtIsOpen = true,
    this.onRepeatAnnouncement,
  });

  final CourtInfo court;
  final int slotsPerTeam;
  final bool flashing;
  final bool compact;
  final bool hero;
  final bool venue;
  final bool challengeCourtIsOpen;
  final VoidCallback? onRepeatAnnouncement;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isActive = court.status == 'in_match';
    final accent = _courtAccent(court.courtNumber, c);
    final isChallengeCourt =
        court.isChallengeCourt || (court.match?.isChallengeCourt ?? false);
    final useVenue = venue && !compact;
    final useCompact = compact && !venue;
    final useHero = hero && !compact && !venue;
    final showClosedPlaceholder =
        isChallengeCourt &&
        !challengeCourtIsOpen &&
        court.match == null &&
        court.defendingTeam == null;
    final radius = BorderRadius.circular(
      useHero || useVenue ? 20 : (useCompact ? 12 : 16),
    );
    final pad = EdgeInsets.all(
      useHero ? 24 : (useVenue ? 20 : (useCompact ? 10 : 18)),
    );

    Widget card = RpcCourtAccent(
      active: isActive,
      highlight: flashing,
      borderRadius: radius,
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _CourtBadge(
                number: court.courtNumber,
                accent: accent,
                venue: useVenue,
                compact: useCompact,
              ),
              const SizedBox(width: RpcSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Court ${court.courtNumber}',
                      style: RpcTypography.title(context).copyWith(
                        fontSize: useHero
                            ? 28
                            : (useVenue ? 24 : (useCompact ? 18 : 22)),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!isActive && useVenue && !showClosedPlaceholder)
                      Text(
                        'Ready for next match',
                        style: RpcTypography.caption(context).copyWith(
                          color: c.textMuted,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isChallengeCourt) ...[
                    DisplayCcBadge(
                      compact: useCompact,
                      venue: useVenue,
                    ),
                    SizedBox(width: useCompact ? 4 : 6),
                  ],
                  if (isActive && onRepeatAnnouncement != null) ...[
                    _RepeatPill(
                      accent: accent,
                      compact: useCompact,
                      venue: useVenue,
                      onPressed: onRepeatAnnouncement!,
                    ),
                    SizedBox(width: useCompact ? 4 : 6),
                  ],
                  if (isActive)
                    _LivePill(
                      accent: accent,
                      compact: useCompact,
                      venue: useVenue,
                    )
                  else if (showClosedPlaceholder)
                    _ClosedPill(compact: useCompact, venue: useVenue)
                  else
                    _OpenPill(compact: useCompact, venue: useVenue),
                ],
              ),
            ],
          ),
          if (court.match != null) ...[
            SizedBox(height: useVenue ? 10 : (useCompact ? 6 : RpcSpacing.sm)),
            CourtTimer(
              startedAt: court.match!.startedAt,
              elapsedSeconds: court.match!.elapsedSeconds,
              compact: useCompact && !useVenue,
            ),
          ],
          SizedBox(height: useHero ? 20 : (useVenue ? 16 : (useCompact ? 6 : 14))),
          if (showClosedPlaceholder)
            ChallengeCourtClosedPlaceholder(
              dense: useCompact && !useVenue,
              compact: useCompact,
            )
          else
            CourtMatchLayout(
              match: court.match,
              slotsPerTeam: slotsPerTeam,
              dense: useCompact && !useVenue,
            ),
          if (court.match != null &&
              court.match!.scoreA != null &&
              court.match!.scoreB != null) ...[
            SizedBox(height: useHero ? 16 : (useVenue ? 14 : (useCompact ? 8 : 12))),
            Container(
              padding: EdgeInsets.symmetric(
                vertical: useVenue ? 10 : 8,
                horizontal: useVenue ? 16 : 12,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  '${court.match!.scoreA}  –  ${court.match!.scoreB}',
                  style: RpcTypography.statMedium(context).copyWith(
                    fontSize: useHero ? 36 : (useVenue ? 32 : (useCompact ? 22 : 28)),
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!flashing) return card;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.45),
            blurRadius: useCompact ? 16 : 28,
            spreadRadius: useCompact ? 1 : 3,
          ),
        ],
      ),
      child: card,
    );
  }
}

class _CourtBadge extends StatelessWidget {
  const _CourtBadge({
    required this.number,
    required this.accent,
    this.venue = false,
    this.compact = false,
  });

  final int number;
  final Color accent;
  final bool venue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = venue ? 52.0 : (compact ? 32.0 : 44.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(venue ? 14 : 12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: RpcTypography.title(context).copyWith(
          fontSize: venue ? 26 : (compact ? 16 : 22),
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}

class _RepeatPill extends StatelessWidget {
  const _RepeatPill({
    required this.accent,
    required this.onPressed,
    this.compact = false,
    this.venue = false,
  });

  final Color accent;
  final VoidCallback onPressed;
  final bool compact;
  final bool venue;

  @override
  Widget build(BuildContext context) {
    final size = venue ? 30.0 : (compact ? 24.0 : 28.0);
    final iconSize = venue ? 16.0 : (compact ? 14.0 : 16.0);

    return Tooltip(
      message: 'Repeat court announcement',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.replay_rounded,
              size: iconSize,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({
    required this.accent,
    this.compact = false,
    this.venue = false,
  });

  final Color accent;
  final bool compact;
  final bool venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: venue ? 14 : (compact ? 8 : 12),
        vertical: venue ? 6 : (compact ? 3 : 6),
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: venue ? 12 : 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fiber_manual_record_rounded,
            size: venue ? 10 : 8,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: (compact && !venue
                    ? RpcTypography.caption(context)
                    : RpcTypography.labelSemibold(context))
                .copyWith(
              color: accent,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontSize: venue ? 14 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedPill extends StatelessWidget {
  const _ClosedPill({this.compact = false, this.venue = false});

  final bool compact;
  final bool venue;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: venue ? 14 : (compact ? 8 : 12),
        vertical: venue ? 6 : (compact ? 3 : 6),
      ),
      decoration: BoxDecoration(
        color: c.textMuted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.textMuted.withValues(alpha: 0.35)),
      ),
      child: Text(
        'CLOSED',
        style: (compact && !venue
                ? RpcTypography.caption(context)
                : RpcTypography.labelSemibold(context))
            .copyWith(
          color: c.textMuted,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          fontSize: venue ? 14 : null,
        ),
      ),
    );
  }
}

class _OpenPill extends StatelessWidget {
  const _OpenPill({this.compact = false, this.venue = false});

  final bool compact;
  final bool venue;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: venue ? 14 : (compact ? 8 : 12),
        vertical: venue ? 6 : (compact ? 3 : 6),
      ),
      decoration: BoxDecoration(
        color: c.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.success.withValues(alpha: 0.35)),
      ),
      child: Text(
        'OPEN',
        style: (compact && !venue
                ? RpcTypography.caption(context)
                : RpcTypography.labelSemibold(context))
            .copyWith(
          color: c.success,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          fontSize: venue ? 14 : null,
        ),
      ),
    );
  }
}

Color _courtAccent(int courtNumber, RpcPalette c) {
  return switch (courtNumber % 3) {
    1 => c.accentOrange,
    2 => c.primary,
    _ => c.success,
  };
}
