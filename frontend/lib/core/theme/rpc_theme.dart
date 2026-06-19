import 'package:flutter/material.dart';
import 'rpc_palette.dart';
import 'rpc_spacing.dart';
import 'rpc_typography.dart';

abstract final class RpcTheme {
  static ThemeData get light => _build(RpcPalette.light, Brightness.light);

  static ThemeData get dark => _build(RpcPalette.dark, Brightness.dark);

  static ThemeData _build(RpcPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.primary,
        onPrimary: RpcPalette.onPrimaryForeground,
        primaryContainer: palette.primaryLight,
        onPrimaryContainer: palette.text,
        secondary: palette.primaryHover,
        onSecondary: RpcPalette.onPrimaryForeground,
        error: palette.danger,
        onError: Colors.white,
        surface: palette.surface,
        onSurface: palette.text,
        outline: palette.border,
      ),
    );

    final textTheme = RpcTypography.textTheme(
      text: palette.text,
      textMuted: palette.textMuted,
    );

    return base.copyWith(
      extensions: [palette],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.surface,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        iconTheme: IconThemeData(color: palette.textMuted),
      ),
      cardTheme: CardTheme(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RpcSpacing.cardRadius),
          side: BorderSide(color: palette.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? palette.surfaceHover : palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
          borderSide: BorderSide(
            color: palette.border,
            width: isDark ? 1 : 1.25,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: palette.textMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: RpcPalette.onPrimaryForeground,
          disabledBackgroundColor: palette.primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(
            color: palette.border,
            width: isDark ? 1 : 1.25,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RpcSpacing.buttonRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textMuted,
          hoverColor: palette.surfaceHover,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceHover,
        selectedColor: palette.primaryLight,
        checkmarkColor: palette.text,
        deleteIconColor: palette.textMuted,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(
          color: palette.border,
          width: isDark ? 1 : 1.25,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: isDark ? 1 : 1,
        space: 1,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: palette.elevatedSurface,
        elevation: isDark ? 8 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.elevatedSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.border,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.primary;
          return palette.surfaceHover;
        }),
        checkColor: WidgetStateProperty.all(RpcPalette.onPrimaryForeground),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark ? palette.textMuted : palette.surface;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark
                ? palette.surfaceHover
                : palette.border.withValues(alpha: 0.55);
          }
          if (states.contains(WidgetState.selected)) {
            return palette.primary;
          }
          return isDark
              ? palette.surfaceHover
              : const Color(0xFFE2E8F0);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return palette.border.withValues(alpha: 0.6);
          }
          if (states.contains(WidgetState.selected)) {
            return palette.primaryHover;
          }
          return isDark ? palette.border : const Color(0xFF94A3B8);
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return 1.0;
          return 1.5;
        }),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: palette.primary,
        unselectedLabelColor: palette.textMuted,
        indicatorColor: palette.primary,
        dividerColor: palette.border,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.elevatedSurface),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.elevatedSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.elevatedSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: palette.text),
      ),
    );
  }
}
