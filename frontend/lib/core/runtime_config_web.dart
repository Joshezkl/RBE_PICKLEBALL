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

bool _isExternalApiHost(String configured, Uri page) {
  if (configured.isEmpty) return true;
  if (configured.startsWith('/')) return true;

  final lower = configured.toLowerCase();
  if (lower.contains('railway.app') ||
      lower.contains('your-real-api-host') ||
      lower.contains('yourdomain.com') ||
      lower.contains('localhost')) {
    return true;
  }

  try {
    final api = Uri.parse(configured);
    return api.host.isNotEmpty && api.host != page.host;
  } catch (_) {
    return true;
  }
}

/// On Vercel deployments, always call the API on the same origin (/api).
String applyDeploymentApiBaseUrl(String configured) {
  final page = Uri.base;
  if (!page.host.endsWith('.vercel.app')) return configured;

  final sameOrigin = '${page.origin}/api';
  if (_isExternalApiHost(configured, page)) {
    return sameOrigin;
  }
  return configured;
}
