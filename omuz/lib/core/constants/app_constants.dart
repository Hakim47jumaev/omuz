class AppConstants {
  AppConstants._();

  static const String appName = 'OMuz';
  // Override via: --dart-define=API_BASE_URL=http://<your-ip>:8000/api/v1
  // Physical device cannot reach 127.0.0.1 on your PC.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.71.61.118:8000/api/v1',
  );
}
