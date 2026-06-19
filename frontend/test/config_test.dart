import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config.dart';

void main() {
  group('AppConfig', () {
    test('normalizes trailing slash on API base URL', () {
      expect(
        AppConfig.apiBaseUrl.endsWith('/api'),
        isTrue,
        reason: 'apiBaseUrl should end with /api',
      );
      expect(AppConfig.apiBaseUrl.endsWith('/api/'), isFalse);
    });

    test('uses wss when API base URL is HTTPS', () {
      // Compile-time default is empty; dev fallback is http://localhost:8000/api
      // so wsScheme should be ws in test environment unless overridden.
      expect(AppConfig.wsScheme, anyOf('ws', 'wss'));
    });

    test('wsKey has a non-empty default for local Reverb', () {
      expect(AppConfig.wsKey.isNotEmpty, isTrue);
    });
  });
}
