import 'package:flutter/material.dart';

import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

class RpcSectionHeader extends StatelessWidget {
  const RpcSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: compact
                    ? RpcTypography.bodySemibold(context)
                    : RpcTypography.title(context),
              ),
              if (subtitle != null) ...[
                SizedBox(height: compact ? 2 : RpcSpacing.xs),
                Text(
                  subtitle!,
                  style: compact
                      ? RpcTypography.caption(context)
                      : RpcTypography.bodySmallMuted(context),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
