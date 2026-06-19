import 'package:flutter/foundation.dart';

/// Persists the admin PIN across page navigation so calendar and other
/// admin routes always send the correct header.
class AdminPinController extends ChangeNotifier {
  AdminPinController({String initialPin = ''}) : _pin = initialPin;

  String _pin;

  String get pin => _pin;

  void setPin(String value) {
    final trimmed = value.trim();
    if (trimmed == _pin) return;
    _pin = trimmed;
    notifyListeners();
  }
}

final rpcAdminPinController = AdminPinController();
