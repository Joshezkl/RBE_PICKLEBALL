import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import 'rpc_status_badge.dart';

class RpcFeatureToggle extends StatelessWidget {
  const RpcFeatureToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.activeIcon,
    this.interactive = true,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData? activeIcon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool interactive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final borderColor = value
        ? c.primary.withValues(alpha: isLight ? 0.65 : 0.5)
        : (isLight ? const Color(0xFF94A3B8) : c.border);
    final backgroundColor = value
        ? c.primaryLight.withValues(alpha: isLight ? 0.55 : 0.35)
        : (isLight ? c.surface : c.surfaceHover.withValues(alpha: 0.35));

    if (compact) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: value
                    ? c.primary.withValues(alpha: 0.14)
                    : c.surfaceHover,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                value ? (activeIcon ?? icon) : icon,
                size: 15,
                color: value ? c.primary : c.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: RpcTypography.caption(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: RpcTypography.caption(context).copyWith(
                      color: c.textMuted,
                      fontSize: 10,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: value,
                onChanged: interactive ? onChanged : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value
                    ? c.primary.withValues(alpha: isLight ? 0.14 : 0.2)
                    : c.surfaceHover,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: value
                      ? c.primary.withValues(alpha: 0.35)
                      : borderColor.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(
                value ? (activeIcon ?? icon) : icon,
                size: 20,
                color: value ? c.primary : c.textMuted,
              ),
            ),
            const SizedBox(width: RpcSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: RpcTypography.bodySemibold(context),
                        ),
                      ),
                      RpcStatusBadge(
                        label: value ? 'ON' : 'OFF',
                        tone: value
                            ? RpcBadgeTone.success
                            : RpcBadgeTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: RpcTypography.bodySmallMuted(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RpcSpacing.xs),
            Switch(
              value: value,
              onChanged: interactive ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
