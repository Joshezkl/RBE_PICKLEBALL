import 'package:flutter/material.dart';

import '../decor/rpc_decor_theme.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    this.subtitle,
    this.initiallyExpanded = true,
    this.trailing,
    this.showSideline = false,
    this.useMinimizeIcons = false,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final Widget? trailing;
  final bool showSideline;
  final bool useMinimizeIcons;
  final Widget child;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(color: c.border),
        boxShadow: [c.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (widget.showSideline)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      c.primary.withValues(
                        alpha: RpcDecorOpacity.accentLine(context) * 0.4,
                      ),
                      c.primary.withValues(
                        alpha: RpcDecorOpacity.accentLine(context),
                      ),
                      c.primary.withValues(
                        alpha: RpcDecorOpacity.accentLine(context) * 0.4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RpcSpacing.md,
                    vertical: RpcSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: RpcTypography.bodySemibold(context),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.subtitle!,
                                style: RpcTypography.bodySmallMuted(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        widget.trailing!,
                        const SizedBox(width: RpcSpacing.sm),
                      ],
                      Icon(
                        widget.useMinimizeIcons
                            ? (_expanded
                                ? Icons.close_fullscreen_rounded
                                : Icons.open_in_full_rounded)
                            : (_expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded),
                        color: c.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                Divider(height: 1, color: c.border),
                Padding(
                  padding: const EdgeInsets.all(RpcSpacing.md),
                  child: widget.child,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
