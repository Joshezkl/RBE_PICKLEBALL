import 'package:flutter/material.dart';

import '../models.dart';
import 'match_court_card.dart';
import 'rpc_responsive.dart';

/// Responsive wrap layout — cards size to content (no forced empty height).
class CourtCardWrap extends StatelessWidget {
  const CourtCardWrap({
    super.key,
    required this.courts,
    required this.slotsPerTeam,
    this.dense = false,
    this.maxColumns,
    this.challengeCourtIsOpen = true,
    this.canAssignNextFor,
    this.onEnterScore,
    this.onManualAssign,
    this.onAssignNext,
    this.onRemovePlayer,
  });

  final List<CourtInfo> courts;
  final int slotsPerTeam;
  final bool dense;
  final int? maxColumns;
  final bool challengeCourtIsOpen;
  final bool Function(CourtInfo court)? canAssignNextFor;
  final void Function(MatchInfo match)? onEnterScore;
  final void Function(CourtInfo court)? onManualAssign;
  final void Function(CourtInfo court)? onAssignNext;
  final void Function(CourtInfo court, int playerId)? onRemovePlayer;

  int _columns(double width) {
    var cols = RpcLayout.columns(
      width,
      compact: 1,
      medium: 2,
      wide: 3,
    );
    if (maxColumns != null && cols > maxColumns!) return maxColumns!;
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = dense ? 10.0 : 14.0;
        final cols = _columns(constraints.maxWidth);
        final cardWidth =
            (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: courts.map((court) {
            return SizedBox(
              width: cardWidth,
              child: MatchCourtCard(
                court: court,
                slotsPerTeam: slotsPerTeam,
                dense: dense,
                canAssignNext: canAssignNextFor?.call(court) ?? false,
                challengeCourtIsOpen: challengeCourtIsOpen,
                onEnterScore: onEnterScore,
                onManualAssign: onManualAssign,
                onAssignNext: onAssignNext,
                onRemovePlayer: onRemovePlayer,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
