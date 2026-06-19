import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'court_grid_painter.dart';
import 'rpc_decor_theme.dart';

/// Faint court grid behind page content — stays under cards and text.
class RpcCourtBackground extends StatelessWidget {
  const RpcCourtBackground({
    super.key,
    required this.child,
    this.intensity = RpcDecorIntensity.subtle,
    this.showLogoWatermark = true,
  });

  final Widget child;
  final RpcDecorIntensity intensity;
  final bool showLogoWatermark;

  @override
  Widget build(BuildContext context) {
    final lineColor = RpcDecorOpacity.lineColor(
      context,
      alpha: RpcDecorOpacity.grid(context, intensity),
    );
    final logoOpacity = RpcDecorOpacity.logoWatermark(context, intensity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 800.0;
        final height =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
        final logoSize =
            (width < height ? width : height) * RpcDecorOpacity.logoScale(intensity);
        final logoWidth = logoSize * 1.15;
        final logoHeight = logoSize * 1.35;

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: CourtGridPainter(
                  lineColor: lineColor,
                  intensity: intensity,
                ),
              ),
            ),
            if (showLogoWatermark)
              Center(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: logoOpacity,
                    child: Image.asset(
                      BrandLogo.assetPath,
                      width: logoWidth,
                      height: logoHeight,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            child,
          ],
        );
      },
    );
  }
}
