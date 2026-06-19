import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';

class RpcInlineStat extends StatelessWidget {
  const RpcInlineStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: RpcTypography.bodyBold(context).copyWith(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: RpcTypography.caption(context).copyWith(
            color: context.rpc.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

int sessionPlayingPlayerCount(SessionState state) {
  var count = 0;
  for (final court in state.courts) {
    if (court.status != 'in_match' || court.match == null) continue;
    for (final player in [
      court.match!.teamA['player1'],
      court.match!.teamA['player2'],
      court.match!.teamB['player1'],
      court.match!.teamB['player2'],
    ]) {
      if (player != null) count++;
    }
  }
  return count;
}

int sessionWaitingPlayerCount(SessionState state) {
  return state.queues.values.fold<int>(0, (sum, players) => sum + players.length);
}
