import 'runtime_config_stub.dart'
    if (dart.library.js_interop) 'runtime_config_web.dart' as runtime_config;

class AppConfig {
  static const String _compileTimeApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _compileTimeWsHost = String.fromEnvironment(
    'WS_HOST',
    defaultValue: '',
  );

  static const String _compileTimeWsScheme = String.fromEnvironment(
    'WS_SCHEME',
    defaultValue: '',
  );

  static const String _compileTimeWsKey = String.fromEnvironment(
    'WS_KEY',
    defaultValue: '',
  );

  /// API root URL. Normalizes a common local typo (`/api1` → `/api`).
  static final String apiBaseUrl = _normalizeApiBaseUrl(
    runtime_config.applyDeploymentApiBaseUrl(
      _resolveValue(
        runtimeKey: 'apiBaseUrl',
        compileTime: _compileTimeApiBaseUrl,
        devFallback: 'http://localhost:8000/api',
      ),
    ),
  );

  static final String wsHost = _resolveValue(
    runtimeKey: 'wsHost',
    compileTime: _compileTimeWsHost,
    devFallback: 'localhost:8080',
  );

  static final String wsKey = _resolveValue(
    runtimeKey: 'wsKey',
    compileTime: _compileTimeWsKey,
    devFallback: 'rpc-key',
  );

  /// `ws` for local HTTP, `wss` for HTTPS production pages.
  static String get wsScheme {
    final fromRuntime = _trim(runtime_config.runtimeConfigValue('wsScheme'));
    if (fromRuntime.isNotEmpty) return fromRuntime;

    final compileTime = _trim(_compileTimeWsScheme);
    if (compileTime.isNotEmpty) return compileTime;

    if (apiBaseUrl.startsWith('https://')) return 'wss';
    if (apiBaseUrl.startsWith('/')) return 'wss';
    return 'ws';
  }

  /// True when the app is served from Vercel or uses a same-origin /api path.
  static bool get isDeployed {
    final page = Uri.base;
    if (page.host.endsWith('.vercel.app')) return true;
    return apiBaseUrl.startsWith('/');
  }

  /// WebSocket live updates are only useful when a Reverb host is configured.
  /// Avoid connecting to localhost:8080 on production deployments.
  static bool get liveUpdatesEnabled {
    final host = wsHost.trim().toLowerCase();
    if (host.isEmpty) return false;

    final isLocalHost = host.startsWith('localhost') ||
        host.startsWith('127.0.0.1') ||
        host.startsWith('[::1]');

    if (!isLocalHost) return true;

    final pageHost = Uri.base.host.toLowerCase();
    return pageHost == 'localhost' || pageHost == '127.0.0.1';
  }

  static Duration get pollForegroundInterval =>
      Duration(seconds: isDeployed ? 12 : 8);

  static Duration get pollBackgroundInterval =>
      Duration(seconds: isDeployed ? 30 : 20);

  static Duration get pollLiveInterval =>
      Duration(seconds: isDeployed ? 45 : 30);

  /// How long screen navigation may reuse in-memory API/session data before
  /// refetching. Keeps admin tab switches instant while polling stays fresh.
  static const Duration screenCacheTtl = Duration(seconds: 60);

  static String _resolveValue({
    required String runtimeKey,
    required String compileTime,
    required String devFallback,
  }) {
    final fromRuntime = _trim(runtime_config.runtimeConfigValue(runtimeKey));
    if (fromRuntime.isNotEmpty) return fromRuntime;

    final compiled = _trim(compileTime);
    if (compiled.isNotEmpty) return compiled;

    return devFallback;
  }

  static String _trim(String? value) => value?.trim() ?? '';

  static String _normalizeApiBaseUrl(String url) {
    var normalized = url.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (normalized.endsWith('/api1')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
