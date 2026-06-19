import 'dart:js_interop';

extension type _RbeConfig(JSObject _) implements JSObject {
  external String? get apiBaseUrl;
  external String? get wsHost;
  external String? get wsScheme;
  external String? get wsKey;
}

@JS('window.__RBE_CONFIG__')
external _RbeConfig? get _rbeConfig;

String? runtimeConfigValue(String key) {
  final config = _rbeConfig;
  if (config == null) return null;

  return switch (key) {
    'apiBaseUrl' => config.apiBaseUrl,
    'wsHost' => config.wsHost,
    'wsScheme' => config.wsScheme,
    'wsKey' => config.wsKey,
    _ => null,
  };
}
