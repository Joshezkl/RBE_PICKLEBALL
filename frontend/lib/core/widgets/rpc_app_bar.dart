import 'package:flutter/material.dart';

import '../theme/rpc_palette.dart';
import '../theme/rpc_typography.dart';
import '../theme/theme_controller.dart';
import 'brand_logo.dart';
import 'theme_toggle_button.dart';

class RpcAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RpcAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.themeController,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final ThemeController? themeController;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return AppBar(
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
      title: Row(
        children: [
          const BrandLogo(height: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: RpcTypography.bodySmallMuted(context),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ...actions,
        if (themeController != null)
          ThemeToggleButton(controller: themeController!),
        const SizedBox(width: 8),
      ],
    );
  }
}
