import 'package:flutter/material.dart';

import '../decor/rpc_court_accent.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';

class RpcCard extends StatelessWidget {
  const RpcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RpcSpacing.lg),
    this.highlight = false,
  });

  const RpcCard.compact({
    super.key,
    required this.child,
    this.highlight = false,
  }) : padding = const EdgeInsets.all(RpcSpacing.md);

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    if (highlight) {
      return RpcCourtAccent(
        highlight: true,
        padding: padding,
        child: child,
      );
    }

    final c = context.rpc;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(color: c.border),
        boxShadow: [c.cardShadow],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}