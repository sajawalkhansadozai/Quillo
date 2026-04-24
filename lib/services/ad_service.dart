import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdService — Google AdMob initialisation
//
// SETUP REQUIRED (client):
//   iOS:     Replace GADApplicationIdentifier in ios/Runner/Info.plist
//   Android: Replace com.google.android.gms.ads.APPLICATION_ID in
//            android/app/src/main/AndroidManifest.xml
//
//   Then replace the ad unit IDs below with real ones from your AdMob account.
//   For testing, the test IDs below work on any device.
// ─────────────────────────────────────────────────────────────────────────────

class AdService {
  // ── Test IDs (replace with real IDs before publishing) ─────────────────────
  // iOS test banner unit ID
  static const String _iosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  // Android test banner unit ID
  static const String _androidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static bool _initialised = false;

  // ── Initialise AdMob (call once from main.dart) ──────────────────────────────

  static Future<void> initialise() async {
    if (_initialised) return;
    await MobileAds.instance.initialize();
    _initialised = true;
  }

  // ── Create a banner ad ───────────────────────────────────────────────────────

  static BannerAd createBanner({
    required void Function(Ad) onLoaded,
    required void Function(Ad, LoadAdError) onFailed,
  }) {
    // Detect platform at runtime to pick the correct unit ID
    final unitId = _isIOS ? _iosBannerAdUnitId : _androidBannerAdUnitId;
    return BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: onFailed,
      ),
    );
  }

  static bool get _isIOS => Platform.isIOS;
}
