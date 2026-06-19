import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';

/// Visual intensity for pickleball-themed decoration layers.
enum RpcDecorIntensity {
  /// Admin / data surfaces — barely visible geometry.
  subtle,

  /// Venue displays and public boards — slightly stronger.
  venue,
}

abstract final class RpcDecorOpacity {
  static double grid(BuildContext context, RpcDecorIntensity intensity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (intensity) {
      RpcDecorIntensity.subtle => isDark ? 0.07 : 0.045,
      RpcDecorIntensity.venue => isDark ? 0.11 : 0.07,
    };
  }

  static double watermark(BuildContext context, RpcDecorIntensity intensity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (intensity) {
      RpcDecorIntensity.subtle => isDark ? 0.08 : 0.055,
      RpcDecorIntensity.venue => isDark ? 0.12 : 0.085,
    };
  }

  /// Large centered logo watermark — visible but stays behind content.
  static double logoWatermark(BuildContext context, RpcDecorIntensity intensity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (intensity) {
      RpcDecorIntensity.subtle => isDark ? 0.08 : 0.06,
      RpcDecorIntensity.venue => isDark ? 0.11 : 0.08,
    };
  }

  static double logoScale(RpcDecorIntensity intensity) {
    return switch (intensity) {
      RpcDecorIntensity.subtle => 0.72,
      RpcDecorIntensity.venue => 0.84,
    };
  }

  static double accentLine(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.55;
  }

  static Color lineColor(BuildContext context, {double? alpha}) {
    final c = Theme.of(context).extension<RpcPalette>() ?? RpcPalette.light;
    final a = alpha ?? grid(context, RpcDecorIntensity.subtle);
    return c.primary.withValues(alpha: a);
  }
}
