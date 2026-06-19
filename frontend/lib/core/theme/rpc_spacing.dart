/// Layout rhythm — aligned with enterprise dashboard spacing.
abstract final class RpcSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard page gutters (horizontal / top / bottom).
  static const double pagePaddingH = 16;
  static const double pagePaddingTop = 12;
  static const double pagePaddingBottom = 20;

  static const double cardRadius = 12;
  static const double buttonRadius = 20;
  static const double inputRadius = 10;
  static const double badgeRadius = 16;

  static const double pageMaxWidth = 1440;
  static const double contentMaxWidth = 1280;
  static const double navHeight = 56;
}

/// Shared responsive breakpoints — use instead of magic numbers in pages.
abstract final class RpcBreakpoints {
  /// Small phones in portrait.
  static const double narrow = 480;

  /// Phones / small tablets in portrait.
  static const double compact = 600;

  /// Tablets and small laptops.
  static const double medium = 900;

  /// Desktops — side-by-side admin layouts.
  static const double wide = 1200;

  /// Large desktops.
  static const double ultra = 1440;
}
