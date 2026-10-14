// AppsFlyer attribution. Defaults are Quillo's values; override per build with
//   --dart-define=APPSFLYER_DEV_KEY=...  --dart-define=APPSFLYER_IOS_APP_ID=...
// Dev key: AppsFlyer dashboard → App settings. iOS App ID: App Store ID, digits
// only. An empty value means the SDK is skipped (2.8).

class AppsFlyerConfig {
  AppsFlyerConfig._();

  static const String devKey = String.fromEnvironment(
    'APPSFLYER_DEV_KEY',
    defaultValue: 'gyLyDuDx2AqsmpQtHxJqe5',
  );

  static const String iosAppId = String.fromEnvironment(
    'APPSFLYER_IOS_APP_ID',
    defaultValue: '6764820627',
  );

  /// Set `--dart-define=APPSFLYER_DEBUG=true` to see native SDK logs.
  static const bool debugLogs = bool.fromEnvironment('APPSFLYER_DEBUG');
}
