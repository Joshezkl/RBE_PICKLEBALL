import 'package:flutter/material.dart';

/// Minimal wiffle-ball silhouette for watermarks and empty states.
class PickleballBallPainter extends CustomPainter {
  PickleballBallPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final fill = Paint()..color = color;
    final hole = Paint()..color = color.withValues(alpha: color.a * 0.35);

    canvas.drawCircle(center, radius, fill);

    final holeR = radius * 0.11;
    final offsets = [
      Offset.zero,
      Offset(radius * 0.38, 0),
      Offset(-radius * 0.38, 0),
      Offset(0, radius * 0.38),
      Offset(0, -radius * 0.38),
      Offset(radius * 0.26, radius * 0.26),
      Offset(-radius * 0.26, -radius * 0.26),
    ];

    for (final delta in offsets) {
      canvas.drawCircle(center + delta, holeR, hole);
    }

    // Outer ring for definition at low opacity.
    final ring = Paint()
      ..color = color.withValues(alpha: (color.a * 1.4).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06;
    canvas.drawCircle(center, radius * 0.92, ring);
  }

  @override
  bool shouldRepaint(PickleballBallPainter oldDelegate) =>
      oldDelegate.color != color;
}
