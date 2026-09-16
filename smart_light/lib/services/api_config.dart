class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.104:3000',
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme, path: '/_ws').toString();
  }

  static String get deviceProvisioningBackendUrl => websocketUrl;
}
