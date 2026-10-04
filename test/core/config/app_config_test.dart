import 'package:flutter_test/flutter_test.dart';
import 'package:knect_mobile/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('uses the Android host alias for local development', () {
      final config = AppConfig.fromEnvironment();

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUri.host, '10.0.2.2');
      expect(config.apiBaseUri.path, '/api/v1');
    });

    test('requires an explicit API URL outside development', () {
      expect(
        () => AppConfig.fromEnvironment(environmentName: 'production'),
        throwsFormatException,
      );
    });

    test('accepts staging and production HTTPS URLs', () {
      final staging = AppConfig.fromEnvironment(
        environmentName: 'staging',
        apiBaseUrl: 'https://staging-api.example.com/api/v1',
      );
      final production = AppConfig.fromEnvironment(
        environmentName: 'prod',
        apiBaseUrl: 'https://api.example.com/api/v1',
      );

      expect(staging.environment, AppEnvironment.staging);
      expect(production.environment, AppEnvironment.production);
      expect(production.apiBaseUri.host, 'api.example.com');
    });

    test('requires HTTPS outside development', () {
      expect(
        () => AppConfig.fromEnvironment(
          environmentName: 'staging',
          apiBaseUrl: 'http://staging-api.example.com/api/v1',
        ),
        throwsFormatException,
      );
    });

    test('rejects unknown environments', () {
      expect(
        () => AppConfig.fromEnvironment(environmentName: 'qa'),
        throwsFormatException,
      );
    });

    test('rejects relative or non-http API URLs', () {
      expect(
        () => AppConfig.fromEnvironment(apiBaseUrl: '/api/v1'),
        throwsFormatException,
      );
      expect(
        () => AppConfig.fromEnvironment(apiBaseUrl: 'file:///api/v1'),
        throwsFormatException,
      );
    });
  });
}
