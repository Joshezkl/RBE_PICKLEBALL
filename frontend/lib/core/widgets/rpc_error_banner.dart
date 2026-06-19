import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

class RpcErrorBanner extends StatelessWidget {
  const RpcErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      margin: const EdgeInsets.only(bottom: RpcSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
        border: Border.all(color: c.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c.danger,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '!',
              style: RpcTypography.bodyBold(context).copyWith(
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: RpcTypography.body(context).copyWith(
                color: c.text,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
