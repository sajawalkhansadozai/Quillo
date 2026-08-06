import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Google AdMob
//
// App IDs use ~   e.g. ca-app-pub-XXXX~YYYY
// Ad unit IDs use /   e.g. ca-app-pub-XXXX/ZZZZ  (create Banner units in AdMob)
//
// Debug builds serve Google's sample units so development never depends on the
// AdMob account being fully approved. Release builds always use the real units.
// ─────────────────────────────────────────────────────────────────────────────

class AdMobConfig {
  AdMobConfig._();

  /// Google's sample publisher id — any unit containing it is a test unit.
  static const String testPublisherId = '3940256099942544';

  static const String _testBannerIOS = 'ca-app-pub-$testPublisherId/2934735716';
  static const String _testBannerAndroid =
      'ca-app-pub-$testPublisherId/6300978111';
  static const String _testInterstitialIOS =
      'ca-app-pub-$testPublisherId/4411468910';
  static const String _testInterstitialAndroid =
      'ca-app-pub-$testPublisherId/1033173712';

  /// Set `--dart-define=ADMOB_FORCE_REAL_ADS=true` to test live units in debug.
  static const bool _forceRealAds =
      bool.fromEnvironment('ADMOB_FORCE_REAL_ADS');

  /// Debug builds use sample units; release always uses the real ones.
  static bool get useTestAds => kDebugMode && !_forceRealAds;

  /// iOS App ID (from AdMob → Apps → Quillo iOS)
  static const String iosAppId = 'ca-app-pub-7601438767779235~3005580086';

  /// Android App ID — add yours from AdMob when the Android app is registered
  static const String androidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
    defaultValue: 'ca-app-pub-$testPublisherId~3347511713',
  );

  /// iOS banner (AdMob → Ad units)
  static const String iosBannerAdUnitId =
      'ca-app-pub-7601438767779235/5350569606';

  static const String androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: _testBannerAndroid,
  );

  /// iOS interstitial — create a unit in AdMob when ready; test ID until then.
  static const String iosInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_ID',
    defaultValue: _testInterstitialIOS,
  );

  static const String androidInterstitialAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
    defaultValue: _testInterstitialAndroid,
  );

  static String bannerAdUnitId({required bool isIOS}) {
    if (useTestAds) return isIOS ? _testBannerIOS : _testBannerAndroid;
    return isIOS ? iosBannerAdUnitId : androidBannerAdUnitId;
  }

  static String interstitialAdUnitId({required bool isIOS}) {
    if (useTestAds) {
      return isIOS ? _testInterstitialIOS : _testInterstitialAndroid;
    }
    return isIOS ? iosInterstitialAdUnitId : androidInterstitialAdUnitId;
  }

  static bool isTestUnit(String adUnitId) => adUnitId.contains(testPublisherId);
}
