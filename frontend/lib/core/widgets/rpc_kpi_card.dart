import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

class RpcKpiCard extends StatelessWidget {
  const RpcKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trend,
    this.trendPositive,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final String? trend;
  final bool? trendPositive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final accent = iconColor ?? c.primary;
    final padding = compact ? RpcSpacing.sm : RpcSpacing.md;
    final iconSize = compact ? 32.0 : 40.0;
    final iconGlyph = compact ? 16.0 : 20.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(
          compact ? RpcSpacing.inputRadius : RpcSpacing.cardRadius,
        ),
        border: Border.all(color: c.border),
        boxShadow: [c.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: compact
                      ? RpcTypography.caption(context)
                      : RpcTypography.label(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: iconGlyph, color: accent),
                ),
            ],
          ),
          SizedBox(height: compact ? RpcSpacing.xs : RpcSpacing.sm),
          Text(
            value,
            style: compact
                ? RpcTypography.statMedium(context)
                : RpcTypography.stat(context),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: RpcSpacing.xs),
            Text(
              subtitle!,
              style: RpcTypography.label(context),
            ),
          ],
          if (trend != null) ...[
            const SizedBox(height: RpcSpacing.sm),
            Row(
              children: [
                Icon(
                  trendPositive == true
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 16,
                  color: trendPositive == true ? c.success : c.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  trend!,
                  style: RpcTypography.caption(context).copyWith(
                    color: trendPositive == true ? c.success : c.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
