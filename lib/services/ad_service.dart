import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdService — Google AdMob (see lib/config/admob_config.dart)
// ─────────────────────────────────────────────────────────────────────────────

class AdService {

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
    final unitId = _isIOS
        ? AdMobConfig.iosBannerAdUnitId
        : AdMobConfig.androidBannerAdUnitId;
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
