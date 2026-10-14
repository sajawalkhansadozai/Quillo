// Crash reporting, analytics, and push — keys via --dart-define so they
// never live in source. Empty values mean the SDK is skipped (2.8).

class ObservabilityConfig {
  ObservabilityConfig._();

  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static const String posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');

  static const String posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// OneSignal App ID is a public client identifier (not the REST API key).
  /// Override with `--dart-define=ONESIGNAL_APP_ID=...` if needed.
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'f92cbfb3-e7b3-44f3-a0b9-98b574ca9019',
  );

  static bool get sentryEnabled => sentryDsn.trim().isNotEmpty;

  static bool get posthogEnabled => posthogApiKey.trim().isNotEmpty;

  static bool get oneSignalEnabled => oneSignalAppId.trim().isNotEmpty;
}
