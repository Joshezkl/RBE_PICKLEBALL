import 'package:flutter/foundation.dart';

/// Tracks whether the app tab/window is in the foreground.
class PageVisibilityController extends ChangeNotifier {
  bool _isVisible = true;

  bool get isVisible => _isVisible;

  void setVisible(bool value) {
    if (_isVisible == value) {
      return;
    }
    _isVisible = value;
    notifyListeners();
  }
}

final rpcPageVisibility = PageVisibilityController();
