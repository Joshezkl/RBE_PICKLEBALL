import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import 'rpc_decor_theme.dart';

/// Court sideline accent — top bar or inset border for active/highlight surfaces.
class RpcCourtAccent extends StatelessWidget {
  const RpcCourtAccent({
    super.key,
    required this.child,
    this.active = false,
    this.highlight = false,
    this.borderRadius,
    this.padding,
  });

  final Widget child;
  final bool active;
  final bool highlight;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final radius = borderRadius ?? BorderRadius.circular(RpcSpacing.cardRadius);
    final showAccent = active || highlight;
    final accentAlpha = RpcDecorOpacity.accentLine(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Border.all(
          color: showAccent
              ? c.primary.withValues(alpha: highlight ? 0.4 : 0.28)
              : c.border,
        ),
        boxShadow: [
          if (showAccent)
            BoxShadow(
              color: c.primary.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 3),
            )
          else
            c.cardShadow,
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAccent)
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.primary.withValues(alpha: accentAlpha * 0.5),
                    c.primary.withValues(alpha: accentAlpha),
                    c.primary.withValues(alpha: accentAlpha * 0.5),
                  ],
                ),
              ),
            ),
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      ),
    );
  }
}
