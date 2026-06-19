import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode initialMode = ThemeMode.dark})
      : _mode = initialMode;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
