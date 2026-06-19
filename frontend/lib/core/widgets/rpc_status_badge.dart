import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

enum RpcBadgeTone { primary, success, warning, danger, neutral, purple, orange }

class RpcStatusBadge extends StatelessWidget {
  const RpcStatusBadge({
    super.key,
    required this.label,
    this.tone = RpcBadgeTone.primary,
  });

  final String label;
  final RpcBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RpcSpacing.badgeRadius),
      ),
      child: Text(
        label,
        style: RpcTypography.badge(context).copyWith(color: fg),
      ),
    );
  }

  (Color, Color) _colors(BuildContext context) {
    final c = Theme.of(context).extension<RpcPalette>() ?? RpcPalette.light;
    return switch (tone) {
      RpcBadgeTone.primary => (c.primaryLight, c.primary),
      RpcBadgeTone.success => (c.success.withValues(alpha: 0.15), c.success),
      RpcBadgeTone.warning => (c.warning.withValues(alpha: 0.15), c.warning),
      RpcBadgeTone.danger => (c.danger.withValues(alpha: 0.12), c.danger),
      RpcBadgeTone.neutral => (c.surfaceHover, c.textMuted),
      RpcBadgeTone.purple => (c.accentPurple.withValues(alpha: 0.15), c.accentPurple),
      RpcBadgeTone.orange => (c.accentOrange.withValues(alpha: 0.15), c.accentOrange),
    };
  }
}
