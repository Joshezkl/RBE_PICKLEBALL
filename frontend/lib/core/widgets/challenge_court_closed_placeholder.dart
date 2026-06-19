import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';

/// Shown on an available Challenge Court while CC is closed.
class ChallengeCourtClosedPlaceholder extends StatelessWidget {
  const ChallengeCourtClosedPlaceholder({
    super.key,
    this.dense = false,
    this.compact = false,
  });

  final bool dense;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final iconSize = dense ? 28.0 : (compact ? 32.0 : 40.0);
    final verticalPad = dense ? 12.0 : (compact ? 16.0 : 24.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: iconSize,
            color: c.textMuted.withValues(alpha: 0.6),
          ),
          SizedBox(height: dense ? 6 : 10),
          Text(
            'Challenge Court closed',
            textAlign: TextAlign.center,
            style: RpcTypography.bodySemibold(context).copyWith(
              fontSize: dense ? 12 : (compact ? 13 : 14),
              color: c.textMuted,
            ),
          ),
          SizedBox(height: dense ? 2 : 4),
          Text(
            'Open CC from the admin desk to assign matches',
            textAlign: TextAlign.center,
            style: RpcTypography.caption(context).copyWith(
              fontSize: dense ? 10 : 11,
              color: c.textMuted.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
