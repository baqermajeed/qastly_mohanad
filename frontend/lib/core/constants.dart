class AppConstants {
  /// غيّره حسب جهازك:
  /// - Windows/Web: http://127.0.0.1:8000
  /// - Android Emulator: http://10.0.2.2:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
