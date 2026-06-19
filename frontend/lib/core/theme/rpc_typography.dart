import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rpc_palette.dart';

/// Inter-based type scale for consistent hierarchy across the app.
abstract final class RpcTypeScale {
  static const double display = 28;
  static const double headline = 20;
  static const double title = 18;
  static const double subtitle = 15;
  static const double bodyLarge = 16;
  static const double body = 14;
  static const double label = 13;
  static const double caption = 12;
  static const double overline = 11;
  static const double stat = 28;
  static const double statMedium = 22;
}

abstract final class RpcTypography {
  static const double titleSize = RpcTypeScale.title;
  static const double bodySize = RpcTypeScale.body;

  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle display(BuildContext context) => _inter(
        fontSize: RpcTypeScale.display,
        fontWeight: FontWeight.w700,
        color: context.rpc.text,
        height: 1.2,
      );

  static TextStyle headline(BuildContext context) => _inter(
        fontSize: RpcTypeScale.headline,
        fontWeight: FontWeight.w600,
        color: context.rpc.text,
        height: 1.3,
      );

  static TextStyle title(BuildContext context) => _inter(
        fontSize: RpcTypeScale.title,
        fontWeight: FontWeight.w600,
        color: context.rpc.text,
        height: 1.35,
      );

  static TextStyle subtitle(BuildContext context) => _inter(
        fontSize: RpcTypeScale.subtitle,
        fontWeight: FontWeight.w400,
        color: context.rpc.textMuted,
        height: 1.45,
      );

  static TextStyle bodyLarge(BuildContext context) => _inter(
        fontSize: RpcTypeScale.bodyLarge,
        fontWeight: FontWeight.w400,
        color: context.rpc.text,
        height: 1.5,
      );

  static TextStyle body(BuildContext context) => _inter(
        fontSize: RpcTypeScale.body,
        fontWeight: FontWeight.w400,
        color: context.rpc.text,
        height: 1.5,
      );

  static TextStyle bodySemibold(BuildContext context) =>
      body(context).copyWith(fontWeight: FontWeight.w600);

  static TextStyle bodyBold(BuildContext context) =>
      body(context).copyWith(fontWeight: FontWeight.w700);

  static TextStyle bodyMuted(BuildContext context) =>
      body(context).copyWith(color: context.rpc.textMuted);

  static TextStyle bodySmall(BuildContext context) => _inter(
        fontSize: RpcTypeScale.label,
        fontWeight: FontWeight.w400,
        color: context.rpc.text,
        height: 1.45,
      );

  static TextStyle bodySmallMuted(BuildContext context) =>
      bodySmall(context).copyWith(color: context.rpc.textMuted);

  static TextStyle bodyRelaxed(BuildContext context) => body(context);

  static TextStyle bodySemiboldSuccess(BuildContext context) =>
      bodySemibold(context).copyWith(color: context.rpc.success);

  static TextStyle label(BuildContext context) => _inter(
        fontSize: RpcTypeScale.label,
        fontWeight: FontWeight.w500,
        color: context.rpc.textMuted,
        height: 1.4,
      );

  static TextStyle labelSemibold(BuildContext context) =>
      label(context).copyWith(
        fontWeight: FontWeight.w600,
        color: context.rpc.text,
      );

  static TextStyle caption(BuildContext context) => _inter(
        fontSize: RpcTypeScale.caption,
        fontWeight: FontWeight.w400,
        color: context.rpc.textMuted,
        height: 1.4,
      );

  static TextStyle captionSemibold(BuildContext context) =>
      caption(context).copyWith(fontWeight: FontWeight.w600);

  static TextStyle overline(BuildContext context) => _inter(
        fontSize: RpcTypeScale.overline,
        fontWeight: FontWeight.w600,
        color: context.rpc.textMuted,
        letterSpacing: 0.6,
        height: 1.2,
      );

  static TextStyle badge(BuildContext context) => _inter(
        fontSize: RpcTypeScale.caption,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  static TextStyle nav(BuildContext context) => _inter(
        fontSize: RpcTypeScale.label,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );

  static TextStyle stat(BuildContext context) => _inter(
        fontSize: RpcTypeScale.stat,
        fontWeight: FontWeight.w700,
        color: context.rpc.text,
        height: 1.1,
      );

  static TextStyle statMedium(BuildContext context) => _inter(
        fontSize: RpcTypeScale.statMedium,
        fontWeight: FontWeight.w700,
        color: context.rpc.text,
        height: 1.15,
      );

  /// App-wide Material [TextTheme] — always Inter.
  static TextTheme textTheme({
    required Color text,
    required Color textMuted,
  }) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double? height,
      Color? color,
      double? letterSpacing,
    }) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color ?? text,
          height: height,
          letterSpacing: letterSpacing,
        );

    return TextTheme(
      displayLarge: style(32, FontWeight.w700, height: 1.15),
      displayMedium: style(28, FontWeight.w700, height: 1.2),
      displaySmall: style(24, FontWeight.w700, height: 1.25),
      headlineLarge: style(20, FontWeight.w600, height: 1.3),
      headlineMedium: style(18, FontWeight.w600, height: 1.35),
      headlineSmall: style(16, FontWeight.w600, height: 1.4),
      titleLarge: style(16, FontWeight.w600, height: 1.4),
      titleMedium: style(15, FontWeight.w600, height: 1.45),
      titleSmall: style(14, FontWeight.w600, height: 1.45),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(14, FontWeight.w400, height: 1.5),
      bodySmall: style(13, FontWeight.w400, height: 1.45, color: textMuted),
      labelLarge: style(14, FontWeight.w600, height: 1.3),
      labelMedium: style(13, FontWeight.w500, height: 1.35),
      labelSmall: style(12, FontWeight.w500, height: 1.35, color: textMuted),
    );
  }
}
