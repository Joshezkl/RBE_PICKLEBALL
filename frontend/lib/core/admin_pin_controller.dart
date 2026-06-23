import 'package:flutter/foundation.dart';

import 'admin_pin_storage_stub.dart'
    if (dart.library.js_interop) 'admin_pin_storage_web.dart' as admin_pin_storage;

/// Persists the admin PIN across navigation (and browser refresh on web).
class AdminPinController extends ChangeNotifier {
  AdminPinController() : _pin = admin_pin_storage.readStoredAdminPin() ?? '';

  String _pin;

  String get pin => _pin;

  bool get isSet => _pin.isNotEmpty;

  void setPin(String value) {
    final trimmed = value.trim();
    if (trimmed == _pin) return;
    _pin = trimmed;
    if (_pin.isEmpty) {
      admin_pin_storage.deleteStoredAdminPin();
    } else {
      admin_pin_storage.writeStoredAdminPin(_pin);
    }
    notifyListeners();
  }

  void clearPin() => setPin('');
}

final rpcAdminPinController = AdminPinController();
