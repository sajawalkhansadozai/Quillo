import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/admob_config.dart';
import '../services/subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdService — Google AdMob (see lib/config/admob_config.dart)
// Premium users never trigger AdMob load/show requests (checklist 4.6).
// ─────────────────────────────────────────────────────────────────────────────

class AdService {
  static bool _initialised = false;
  static bool _listeningPremium = false;
  InterstitialAd? _cachedInterstitial;

  static final AdService instance = AdService._();
  AdService._();

  /// Initialise the Mobile Ads SDK only. Call [startAdsIfFree] after RevenueCat sync.
  static Future<void> initialise() async {
    if (_initialised) return;
    try {
      final status = await MobileAds.instance.initialize();
      _initialised = true;
      debugPrint(
        'AdMob: initialized '
        '(adapters=${status.adapterStatuses.length}, '
        'useTestAds=${AdMobConfig.useTestAds}, '
        'banner=${AdMobConfig.bannerAdUnitId(isIOS: _isIOS)})',
      );
      _listenPremiumChanges();
    } catch (e, st) {
      debugPrint('AdMob: initialize failed: $e\n$st');
    }
  }

  static void _listenPremiumChanges() {
    if (_listeningPremium) return;
    _listeningPremium = true;
    SubscriptionService.premiumNotifier.addListener(() {
      if (SubscriptionService.isPremiumCached) {
        instance._clearInterstitial();
      } else if (_initialised) {
        instance._preloadInterstitial();
      }
    });
  }

  /// Preload interstitial only for free users (call after subscription sync).
  static Future<void> startAdsIfFree() async {
    if (!_initialised || kIsWeb) return;
    if (await SubscriptionService.isPremium()) {
      instance._clearInterstitial();
      return;
    }
    instance._preloadInterstitial();
  }

  void _clearInterstitial() {
    _cachedInterstitial?.dispose();
    _cachedInterstitial = null;
  }

  // ── Create a banner ad ───────────────────────────────────────────────────────

  /// Returns null when the user is premium — no AdMob request is made (4.6).
  static BannerAd? createBanner({
    required void Function(Ad) onLoaded,
    required void Function(Ad, LoadAdError) onFailed,
  }) {
    if (SubscriptionService.isPremiumCached) {
      debugPrint('AdMob: skip banner create — premium user');
      return null;
    }

    final unitId = AdMobConfig.bannerAdUnitId(isIOS: _isIOS);
    debugPrint(
      'AdMob: loading banner unit=$unitId '
      '(test=${AdMobConfig.isTestUnit(unitId)})',
    );
    return BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (SubscriptionService.isPremiumCached) {
            debugPrint('AdMob: discard banner — became premium while loading');
            ad.dispose();
            return;
          }
          debugPrint('AdMob: banner loaded');
          onLoaded(ad);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'AdMob: banner failed code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          onFailed(ad, error);
        },
      ),
    );
  }

  void _preloadInterstitial() {
    if (SubscriptionService.isPremiumCached) {
      debugPrint('AdMob: skip interstitial preload — premium user');
      return;
    }
    final unitId = AdMobConfig.interstitialAdUnitId(isIOS: _isIOS);
    debugPrint(
      'AdMob: loading interstitial unit=$unitId '
      '(test=${AdMobConfig.isTestUnit(unitId)})',
    );
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (SubscriptionService.isPremiumCached) {
            ad.dispose();
            return;
          }
          debugPrint('AdMob: interstitial loaded');
          _cachedInterstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('AdMob: interstitial show failed: $error');
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'AdMob: interstitial failed code=${error.code} '
            'domain=${error.domain} message=${error.message}',
          );
          _cachedInterstitial = null;
        },
      ),
    );
  }

  /// Show an interstitial for free users at natural breakpoints (e.g. after scan).
  static Future<void> showInterstitialIfFree() async {
    if (kIsWeb) return;
    if (await SubscriptionService.isPremium()) return;
    final ad = instance._cachedInterstitial;
    if (ad == null) {
      instance._preloadInterstitial();
      return;
    }
    await ad.show();
    instance._cachedInterstitial = null;
    instance._preloadInterstitial();
  }

  static bool get _isIOS => !kIsWeb && Platform.isIOS;
}
