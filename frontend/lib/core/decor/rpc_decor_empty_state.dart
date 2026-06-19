import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import 'pickleball_ball_painter.dart';
import 'rpc_decor_theme.dart';

/// Empty / idle state with subtle ball watermark.
class RpcDecorEmptyState extends StatelessWidget {
  const RpcDecorEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final ballColor = RpcDecorOpacity.lineColor(
      context,
      alpha: RpcDecorOpacity.watermark(context, RpcDecorIntensity.subtle),
    );
    final iconSize = compact ? 40.0 : 52.0;
    final ballSize = compact ? 88.0 : 112.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? RpcSpacing.lg : RpcSpacing.xl,
        horizontal: RpcSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: ballSize,
            height: ballSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(ballSize, ballSize),
                  painter: PickleballBallPainter(color: ballColor),
                ),
                Icon(
                  icon ?? Icons.sports_tennis_rounded,
                  size: iconSize,
                  color: c.primary.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? RpcSpacing.md : RpcSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: compact
                ? RpcTypography.title(context)
                : RpcTypography.headline(context),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: RpcSpacing.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: RpcTypography.bodySmallMuted(context),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: RpcSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
