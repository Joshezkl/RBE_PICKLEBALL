import 'package:flutter/material.dart';

@immutable
class RpcPalette extends ThemeExtension<RpcPalette> {
  const RpcPalette({
    required this.primary,
    required this.primaryHover,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.surfaceHover,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.winner,
    required this.loser,
    required this.success,
    required this.warning,
    required this.danger,
    required this.cardShadow,
    required this.elevatedSurface,
    required this.accentOrange,
    required this.accentPurple,
  });

  final Color primary;
  final Color primaryHover;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color surfaceHover;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color winner;
  final Color loser;
  final Color success;
  final Color warning;
  final Color danger;
  final BoxShadow cardShadow;
  final Color elevatedSurface;
  final Color accentOrange;
  final Color accentPurple;

  /// Text/icons on primary-colored surfaces (buttons, active nav).
  static const onPrimaryForeground = Color(0xFFDFDDDD);

  static const light = RpcPalette(
    primary: Color(0xFF0F2F76),
    primaryHover: Color(0xFF0F2F76),
    primaryLight: Color(0xFFE6EAF5),
    background: Color(0xFFF4F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF0F4F8),
    text: Color(0xFF1E293B),
    textMuted: Color(0xFF64748B),
    border: Color(0xFFCBD5E1),
    winner: Color(0xFF0F2F76),
    loser: Color(0xFF94A3B8),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    accentOrange: Color(0xFFF97316),
    accentPurple: Color(0xFF8B5CF6),
    elevatedSurface: Color(0xFFFFFFFF),
    cardShadow: BoxShadow(
      color: Color(0x0D1E293B),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  );

  static const dark = RpcPalette(
    primary: Color(0xFF0D3EA7),
    primaryHover: Color(0xFF0D3EA7),
    primaryLight: Color(0xFF1A2550),
    background: Color(0xFF0C0B16),
    surface: Color(0xFF14132A),
    surfaceHover: Color(0xFF1C1B35),
    text: Color(0xFFF1F5F9),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFF2A2945),
    winner: Color(0xFF0D3EA7),
    loser: Color(0xFF94A3B8),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    accentOrange: Color(0xFFFB923C),
    accentPurple: Color(0xFFA78BFA),
    elevatedSurface: Color(0xFF1C1B35),
    cardShadow: BoxShadow(
      color: Color(0x66000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  );

  @override
  RpcPalette copyWith({
    Color? primary,
    Color? primaryHover,
    Color? primaryLight,
    Color? background,
    Color? surface,
    Color? surfaceHover,
    Color? text,
    Color? textMuted,
    Color? border,
    Color? winner,
    Color? loser,
    Color? success,
    Color? warning,
    Color? danger,
    BoxShadow? cardShadow,
    Color? elevatedSurface,
    Color? accentOrange,
    Color? accentPurple,
  }) {
    return RpcPalette(
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryLight: primaryLight ?? this.primaryLight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      winner: winner ?? this.winner,
      loser: loser ?? this.loser,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      cardShadow: cardShadow ?? this.cardShadow,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      accentOrange: accentOrange ?? this.accentOrange,
      accentPurple: accentPurple ?? this.accentPurple,
    );
  }

  @override
  RpcPalette lerp(ThemeExtension<RpcPalette>? other, double t) {
    if (other is! RpcPalette) return this;
    return RpcPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      winner: Color.lerp(winner, other.winner, t)!,
      loser: Color.lerp(loser, other.loser, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      cardShadow: cardShadow,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
    );
  }
}

extension RpcPaletteContext on BuildContext {
  RpcPalette get rpc =>
      Theme.of(this).extension<RpcPalette>() ?? RpcPalette.light;
}
