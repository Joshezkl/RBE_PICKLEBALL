import 'package:flutter/material.dart';

import '../admin_pin_controller.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';

bool isAdminPinErrorMessage(String? message) {
  if (message == null || message.isEmpty) return false;
  final lower = message.toLowerCase();
  return lower.contains('admin pin');
}

class AdminPinEntry extends StatelessWidget {
  const AdminPinEntry({
    super.key,
    required this.controller,
    this.onChanged,
    this.compact = false,
    this.message,
    this.onDismiss,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool compact;
  final String? message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return Container(
      margin: const EdgeInsets.only(bottom: RpcSpacing.md),
      padding: EdgeInsets.all(compact ? RpcSpacing.sm : RpcSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
        border: Border.all(color: c.warning.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 20, color: c.warning),
              const SizedBox(width: RpcSpacing.sm),
              Expanded(
                child: Text(
                  message ??
                      'Enter your admin PIN to manage courts, queue, and end the session.',
                  style: RpcTypography.body(context).copyWith(
                    color: c.text,
                    height: 1.4,
                  ),
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: RpcSpacing.xs),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Dismiss',
                ),
              ],
            ],
          ),
          const SizedBox(height: RpcSpacing.sm),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Admin PIN',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              isDense: compact,
            ),
            obscureText: true,
            autofocus: compact,
            onChanged: (value) {
              rpcAdminPinController.setPin(value);
              onChanged?.call(value);
            },
          ),
        ],
      ),
    );
  }
}
