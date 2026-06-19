import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/widgets/court_card_wrap.dart';

class CourtGrid extends StatelessWidget {
  const CourtGrid({
    super.key,
    required this.courts,
    required this.slotsPerTeam,
    required this.canAssignNextFor,
    required this.onEnterScore,
    required this.onManualAssign,
    required this.onAssignNext,
    this.challengeCourtIsOpen = true,
    this.onRemovePlayer,
    this.dense = false,
  });

  final List<CourtInfo> courts;
  final int slotsPerTeam;
  final bool dense;
  final bool challengeCourtIsOpen;
  final bool Function(CourtInfo court) canAssignNextFor;
  final void Function(MatchInfo match) onEnterScore;
  final void Function(CourtInfo court) onManualAssign;
  final void Function(CourtInfo court) onAssignNext;
  final void Function(CourtInfo court, int playerId)? onRemovePlayer;

  @override
  Widget build(BuildContext context) {
    return CourtCardWrap(
      courts: courts,
      slotsPerTeam: slotsPerTeam,
      dense: dense,
      challengeCourtIsOpen: challengeCourtIsOpen,
      canAssignNextFor: canAssignNextFor,
      onEnterScore: onEnterScore,
      onManualAssign: onManualAssign,
      onAssignNext: onAssignNext,
      onRemovePlayer: onRemovePlayer,
    );
  }
}
