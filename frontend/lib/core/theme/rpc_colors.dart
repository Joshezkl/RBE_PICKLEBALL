import 'package:flutter/material.dart';

import 'rpc_palette.dart';

/// Semantic colors — prefer [BuildContext.rpc] in widgets.
abstract final class RpcColors {
  static const primary = Color(0xFF0F2F76);
  static const primaryHover = Color(0xFF0F2F76);
  static const primaryLight = Color(0xFFE6EAF5);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHover = Color(0xFFF1F5F9);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const winner = Color(0xFF0F2F76);
  static const loser = Color(0xFF64748B);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const cardShadow = BoxShadow(
    color: Color(0x0A0F172A),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static RpcPalette of(BuildContext context) => context.rpc;
}
