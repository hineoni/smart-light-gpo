class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.smart-light.tech',
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme, path: '/_ws').toString();
  }

  static String get deviceProvisioningBackendUrl => websocketUrl;
}
