import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return IconButton(
          tooltip: isDark ? 'Light mode' : 'Dark mode',
          onPressed: controller.toggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              key: ValueKey(isDark),
              size: 22,
            ),
          ),
        );
      },
    );
  }
}
