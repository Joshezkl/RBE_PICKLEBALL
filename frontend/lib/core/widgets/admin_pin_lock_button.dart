import 'package:flutter/material.dart';

import '../admin_pin_controller.dart';
import '../theme/rpc_palette.dart';

/// Clears the saved admin PIN (lock admin until PIN is entered again).
class AdminPinLockButton extends StatelessWidget {
  const AdminPinLockButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;

    return ListenableBuilder(
      listenable: rpcAdminPinController,
      builder: (context, _) {
        if (!rpcAdminPinController.isSet) {
          return const SizedBox.shrink();
        }

        return IconButton(
          tooltip: 'Lock admin (clear PIN)',
          onPressed: rpcAdminPinController.clearPin,
          icon: Icon(Icons.lock_open_rounded, color: c.textMuted, size: 22),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }
}
