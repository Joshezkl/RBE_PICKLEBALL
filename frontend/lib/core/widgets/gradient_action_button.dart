import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';

class GradientActionButton extends StatefulWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool compact;

  @override
  State<GradientActionButton> createState() => _GradientActionButtonState();
}

class _GradientActionButtonState extends State<GradientActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    final enabled = widget.onPressed != null;

    if (widget.outlined) {
      return _OutlinedHoverButton(
        label: widget.label,
        icon: widget.icon,
        onPressed: widget.onPressed,
        compact: widget.compact,
      );
    }

    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: enabled ? (_) => setState(() => _hovered = false) : null,
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: widget.compact ? 34 : 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.compact ? 8 : 10),
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _hovered
                        ? [const Color(0xFF60A5FA), c.primary]
                        : [c.primary, c.primaryHover],
                  )
                : null,
            color: enabled ? null : c.border,
            boxShadow: enabled && _hovered
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : enabled
                    ? [
                        BoxShadow(
                          color: c.primary.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.compact ? 16 : 18,
                  color: Colors.white,
                ),
                SizedBox(width: widget.compact ? 6 : 8),
              ],
              Text(
                widget.label,
                style: (widget.compact
                        ? RpcTypography.bodySemibold(context)
                        : RpcTypography.labelSemibold(context))
                    .copyWith(
                  color: enabled ? Colors.white : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedHoverButton extends StatefulWidget {
  const _OutlinedHoverButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  State<_OutlinedHoverButton> createState() => _OutlinedHoverButtonState();
}

class _OutlinedHoverButtonState extends State<_OutlinedHoverButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.compact ? 34 : 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.compact ? 8 : 10),
            color: _hovered ? c.primaryLight : c.surface,
            border: Border.all(
              color: _hovered ? c.primary : c.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.compact ? 16 : 18,
                  color: _hovered ? c.primary : c.textMuted,
                ),
                SizedBox(width: widget.compact ? 6 : 8),
              ],
              Text(
                widget.label,
                style: (widget.compact
                        ? RpcTypography.bodySemibold(context)
                        : RpcTypography.labelSemibold(context))
                    .copyWith(
                  color: _hovered ? c.primary : c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
