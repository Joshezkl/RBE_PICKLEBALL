import 'package:flutter/material.dart';

import '../../core/theme/rpc_palette.dart';
import '../../core/theme/rpc_typography.dart';

/// Challenge Court badge for venue / TV displays.
class DisplayCcBadge extends StatelessWidget {
  const DisplayCcBadge({
    super.key,
    this.compact = false,
    this.venue = false,
  });

  final bool compact;
  final bool venue;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final fontSize = venue ? 12.0 : (compact ? 9.0 : 10.0);
    final horizontal = venue ? 10.0 : (compact ? 6.0 : 8.0);
    final vertical = venue ? 4.0 : (compact ? 2.0 : 3.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: c.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.accentOrange.withValues(alpha: 0.45)),
      ),
      child: Text(
        'CC',
        style: RpcTypography.caption(context).copyWith(
          color: c.accentOrange,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
