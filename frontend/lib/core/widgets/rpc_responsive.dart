import 'package:flutter/material.dart';

import '../theme/rpc_spacing.dart';

/// Viewport helpers — prefer [LayoutBuilder] width when inside scrollables.
extension RpcContextLayout on BuildContext {
  Size get viewportSize => MediaQuery.sizeOf(this);

  double get viewportWidth => viewportSize.width;

  double get viewportHeight => viewportSize.height;

  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  bool get isLandscape => viewportWidth > viewportHeight;

  bool get isNarrow => viewportWidth < RpcBreakpoints.narrow;

  bool get isCompact => viewportWidth < RpcBreakpoints.compact;

  bool get isMediumUp => viewportWidth >= RpcBreakpoints.medium;

  bool get isWide => viewportWidth >= RpcBreakpoints.wide;
}

/// Shared responsive layout math and constraints.
abstract final class RpcLayout {
  static bool isNarrow(double width) => width < RpcBreakpoints.narrow;

  static bool isCompact(double width) => width < RpcBreakpoints.compact;

  static bool isMedium(double width) =>
      width >= RpcBreakpoints.compact && width < RpcBreakpoints.medium;

  static bool isWide(double width) => width >= RpcBreakpoints.wide;

  static int columns(
    double width, {
    int narrow = 1,
    int compact = 1,
    int medium = 2,
    int wide = 3,
    int ultra = 4,
  }) {
    if (width >= RpcBreakpoints.ultra) return ultra;
    if (width >= RpcBreakpoints.wide) return wide;
    if (width >= RpcBreakpoints.medium) return medium;
    if (width >= RpcBreakpoints.compact) return compact;
    return narrow;
  }

  static EdgeInsets pagePadding(double width) {
    final horizontal = width < RpcBreakpoints.compact
        ? RpcSpacing.sm + 4
        : width < RpcBreakpoints.medium
            ? RpcSpacing.pagePaddingH
            : RpcSpacing.lg;
    return EdgeInsets.fromLTRB(
      horizontal,
      RpcSpacing.pagePaddingTop,
      horizontal,
      RpcSpacing.pagePaddingBottom,
    );
  }

  static double effectiveMaxWidth(
    double viewportWidth, {
    double preferred = RpcSpacing.pageMaxWidth,
  }) {
    final pad = pagePadding(viewportWidth).horizontal;
    return (viewportWidth - pad).clamp(0, preferred);
  }

  static EdgeInsets dialogInsetPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return EdgeInsets.symmetric(
      horizontal: width < RpcBreakpoints.compact ? 12 : 24,
      vertical: width < RpcBreakpoints.compact ? 12 : 24,
    );
  }

  static BoxConstraints dialogConstraints(
    BuildContext context, {
    double maxWidth = 640,
    double maxHeightFraction = 0.9,
    double minWidth = 280,
  }) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context);
    final hPad = dialogInsetPadding(context).horizontal;
    final vPad = dialogInsetPadding(context).vertical;
    final availableW = size.width - hPad;
    final availableH = size.height - vPad - inset.bottom;
    return BoxConstraints(
      minWidth: minWidth,
      maxWidth: availableW.clamp(minWidth, maxWidth),
      maxHeight: availableH * maxHeightFraction,
    );
  }

  static double dialogContentHeight(
    BuildContext context, {
    double fraction = 0.55,
    double min = 240,
    double max = 520,
  }) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewInsetsOf(context);
    final vPad = dialogInsetPadding(context).vertical;
    final available = size.height - vPad - inset.bottom;
    return (available * fraction).clamp(min, max);
  }

  static double navLogoHeight(double width) {
    if (width < RpcBreakpoints.compact) return 44;
    if (width < RpcBreakpoints.medium) return 56;
    return 72;
  }
}

/// Row on wide viewports, column (or wrap) on narrow ones.
class RpcAdaptiveRow extends StatelessWidget {
  const RpcAdaptiveRow({
    super.key,
    required this.children,
    this.breakpoint = RpcBreakpoints.compact,
    this.spacing = RpcSpacing.sm,
    this.runSpacing = RpcSpacing.sm,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.rowCrossAxisAlignment = CrossAxisAlignment.start,
    this.wrapOnCompact = false,
    this.expandChildren = false,
  });

  final List<Widget> children;
  final double breakpoint;
  final double spacing;
  final double runSpacing;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final bool wrapOnCompact;
  final bool expandChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < breakpoint;
        if (stack) {
          if (wrapOnCompact) {
            return Wrap(
              spacing: spacing,
              runSpacing: runSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children,
            );
          }
          return Column(
            crossAxisAlignment: columnCrossAxisAlignment,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                expandChildren ? Expanded(child: children[i]) : children[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: rowCrossAxisAlignment,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              expandChildren ? Expanded(child: children[i]) : children[i],
            ],
          ],
        );
      },
    );
  }
}

/// Selection toolbar: leading controls stay left; primary action stacks below on narrow screens.
class RpcSelectionToolbar extends StatelessWidget {
  const RpcSelectionToolbar({
    super.key,
    required this.leading,
    required this.action,
    this.breakpoint = RpcBreakpoints.compact,
  });

  final List<Widget> leading;
  final Widget action;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < breakpoint;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: leading),
              const SizedBox(height: RpcSpacing.sm),
              action,
            ],
          );
        }

        return Row(
          children: [
            ...leading,
            const Spacer(),
            action,
          ],
        );
      },
    );
  }
}

/// Dialog shell with viewport-aware insets and max size.
class RpcResponsiveDialog extends StatelessWidget {
  const RpcResponsiveDialog({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding = const EdgeInsets.all(RpcSpacing.lg),
    this.backgroundColor,
    this.shape,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: RpcLayout.dialogInsetPadding(context),
      backgroundColor: backgroundColor,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
          ),
      child: ConstrainedBox(
        constraints: RpcLayout.dialogConstraints(context, maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
