import 'dart:js_interop';

const _storageKey = 'rpc_admin_pin';

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

@JS('window.localStorage')
external _Storage get _localStorage;

String? readStoredAdminPin() => _localStorage.getItem(_storageKey);

void writeStoredAdminPin(String pin) {
  _localStorage.setItem(_storageKey, pin);
}

void deleteStoredAdminPin() {
  _localStorage.removeItem(_storageKey);
}
