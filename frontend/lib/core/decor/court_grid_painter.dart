import 'package:flutter/material.dart';

import 'rpc_decor_theme.dart';

/// Top-down pickleball court outline — net, kitchen lines, outer boundary.
class CourtGridPainter extends CustomPainter {
  CourtGridPainter({
    required this.lineColor,
    this.intensity = RpcDecorIntensity.subtle,
  });

  final Color lineColor;
  final RpcDecorIntensity intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 80 || size.height < 80) return;

    final courtW = size.width * 0.88;
    final courtH = size.height * 0.72;
    final left = (size.width - courtW) / 2;
    final top = (size.height - courtH) / 2;
    final rect = Rect.fromLTWH(left, top, courtW, courtH);
    final radius = Radius.circular(6 * (intensity == RpcDecorIntensity.venue ? 1.2 : 1));

    final stroke = intensity == RpcDecorIntensity.venue ? 1.25 : 1.0;
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);

    final centerX = rect.center.dx;
    final kitchenInset = courtW * 0.18;

    // Net (center vertical line).
    canvas.drawLine(
      Offset(centerX, rect.top),
      Offset(centerX, rect.bottom),
      paint,
    );

    // Kitchen / NVZ lines.
    canvas.drawLine(
      Offset(centerX - kitchenInset, rect.top),
      Offset(centerX - kitchenInset, rect.bottom),
      paint..strokeWidth = stroke * 0.85,
    );
    canvas.drawLine(
      Offset(centerX + kitchenInset, rect.top),
      Offset(centerX + kitchenInset, rect.bottom),
      paint,
    );

    // Center service line (horizontal).
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      paint..strokeWidth = stroke * 0.75,
    );
  }

  @override
  bool shouldRepaint(CourtGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.intensity != intensity;
}
