// ─────────────────────────────────────────────────────────────────────────────
// Google AdMob
//
// App IDs use ~   e.g. ca-app-pub-XXXX~YYYY
// Ad unit IDs use /   e.g. ca-app-pub-XXXX/ZZZZ  (create Banner units in AdMob)
// ─────────────────────────────────────────────────────────────────────────────

class AdMobConfig {
  AdMobConfig._();

  /// iOS App ID (from AdMob → Apps → Quillo iOS)
  static const String iosAppId = 'ca-app-pub-7601438767779235~3005580086';

  /// Android App ID — add yours from AdMob when the Android app is registered
  static const String androidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713',
  );

  /// iOS banner (AdMob → Ad units)
  static const String iosBannerAdUnitId = 'ca-app-pub-7601438767779235/5350569606';

  static const String androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  static bool get usingTestBannerUnits =>
      iosBannerAdUnitId.contains('3940256099942544') ||
      androidBannerAdUnitId.contains('3940256099942544');
}
