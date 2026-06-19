import 'package:flutter/material.dart';

import '../theme/rpc_spacing.dart';
import 'rpc_decor_theme.dart';

/// Dashed “net” divider between sections.
class RpcNetDivider extends StatelessWidget {
  const RpcNetDivider({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final color = RpcDecorOpacity.lineColor(
      context,
      alpha: RpcDecorOpacity.grid(context, RpcDecorIntensity.subtle) * 1.6,
    );

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(vertical: RpcSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 2,
        child: CustomPaint(
          painter: _DashedNetPainter(color: color),
        ),
      ),
    );
  }
}

class _DashedNetPainter extends CustomPainter {
  _DashedNetPainter({required this.color});

  final Color color;

  static const _dashWidth = 6.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;

    final paint = Paint()..color = color;
    var x = 0.0;
    while (x < size.width) {
      final dashEnd = (x + _dashWidth).clamp(0.0, size.width);
      final dashW = dashEnd - x;
      if (dashW > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, dashW, size.height),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      x += _dashWidth + _gap;
    }
  }

  @override
  bool shouldRepaint(_DashedNetPainter oldDelegate) => oldDelegate.color != color;
}
