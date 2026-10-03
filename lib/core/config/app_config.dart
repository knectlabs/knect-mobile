enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'development' || 'dev' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' || 'prod' => AppEnvironment.production,
      _ => throw FormatException('Unsupported APP_ENV: $value'),
    };
  }
}

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUri});

  static const _developmentApiUrl = 'http://10.0.2.2:3000/api/v1';

  final AppEnvironment environment;
  final Uri apiBaseUri;

  factory AppConfig.fromEnvironment({
    String environmentName = const String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
    String apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
  }) {
    final environment = AppEnvironment.parse(environmentName);
    final configuredUrl = apiBaseUrl.trim();

    if (configuredUrl.isEmpty && environment != AppEnvironment.development) {
      throw const FormatException(
        'API_BASE_URL is required outside the development environment.',
      );
    }

    final uri = Uri.tryParse(
      configuredUrl.isEmpty ? _developmentApiUrl : configuredUrl,
    );
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('API_BASE_URL must be an absolute HTTP URL.');
    }
    if (environment != AppEnvironment.development && uri.scheme != 'https') {
      throw const FormatException(
        'API_BASE_URL must use HTTPS outside the development environment.',
      );
    }

    return AppConfig(environment: environment, apiBaseUri: uri);
  }
}
