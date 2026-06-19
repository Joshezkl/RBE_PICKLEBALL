class AppConfig {
  static const String _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  /// API root URL. Normalizes a common local typo (`/api1` → `/api`).
  static final String apiBaseUrl = _normalizeApiBaseUrl(_rawApiBaseUrl);

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

  static const String wsHost = String.fromEnvironment(
    'WS_HOST',
    defaultValue: 'localhost:8080',
  );

  static const String wsKey = String.fromEnvironment(
    'WS_KEY',
    defaultValue: 'rpc-key',
  );
}
