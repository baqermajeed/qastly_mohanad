class AppConstants {
  /// رابط الباكند على السيرفر.
  /// للتجربة المحلية: --dart-define=API_BASE_URL=http://127.0.0.1:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://qasatly.compassaccuracy.com',
  );
}
