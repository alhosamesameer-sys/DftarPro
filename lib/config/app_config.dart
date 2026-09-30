class AppConfig {
  static const environment = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const enableRemoteSync = bool.fromEnvironment('ENABLE_REMOTE_SYNC', defaultValue: false);
}