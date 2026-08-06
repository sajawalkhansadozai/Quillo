import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdBannerWidget — Google AdMob banner for free users only (checklist 4.2–4.6).
// • Never requests an ad when isPremium is true (4.6)
// • Takes zero space when premium / not loaded (4.2)
// • Re-checks RevenueCat on mount and when app resumes (4.3 / 4.5)
// • Listens to premiumNotifier so upgrade removes ads instantly (4.4)
// ─────────────────────────────────────────────────────────────────────────────

class AdBannerWidget extends StatefulWidget {
  /// When false, skips bottom SafeArea (use when a parent already pads for home indicator).
  final bool safeArea;

  const AdBannerWidget({super.key, this.safeArea = true});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with WidgetsBindingObserver {
  BannerAd? _ad;
  bool _isPremium = false;
  bool _adLoaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SubscriptionService.premiumNotifier.addListener(_onPremiumChanged);
    _isPremium = SubscriptionService.isPremiumCached;
    _refreshAndMaybeLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SubscriptionService.premiumNotifier.removeListener(_onPremiumChanged);
    _disposeAd();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning to foreground (covers cancelled sub after billing end).
    if (state == AppLifecycleState.resumed) {
      _refreshAndMaybeLoad();
    }
  }

  void _onPremiumChanged() {
    final premium = SubscriptionService.isPremiumCached;
    if (premium == _isPremium) return;
    setState(() {
      _isPremium = premium;
      if (premium) {
        _disposeAd();
      } else {
        _loadAd();
      }
    });
  }

  Future<void> _refreshAndMaybeLoad() async {
    final premium = await SubscriptionService.refreshPremiumStatus();
    if (!mounted) return;
    setState(() => _isPremium = premium);
    if (premium) {
      _disposeAd();
    } else if (!_adLoaded && _ad == null) {
      _loadAd();
    }
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _adLoaded = false;
    _loading = false;
  }

  void _loadAd() {
    if (_isPremium || SubscriptionService.isPremiumCached) return;
    if (_loading) return;

    _disposeAd();
    _loading = true;
    final banner = AdService.createBanner(
      onLoaded: (ad) {
        if (!mounted) {
          ad.dispose();
          return;
        }
        if (SubscriptionService.isPremiumCached) {
          ad.dispose();
          setState(() {
            _loading = false;
            _adLoaded = false;
            _ad = null;
            _isPremium = true;
          });
          return;
        }
        setState(() {
          _ad = ad as BannerAd;
          _adLoaded = true;
          _loading = false;
        });
      },
      onFailed: (ad, error) {
        ad.dispose();
        if (!mounted) return;
        setState(() {
          _adLoaded = false;
          _loading = false;
          _ad = null;
        });
      },
    );

    if (banner == null) {
      // Premium — createBanner made no AdMob request (4.6).
      _loading = false;
      setState(() => _isPremium = true);
      return;
    }
    _ad = banner;
    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPremium || !_adLoaded || _ad == null) return const SizedBox.shrink();
    final banner = Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: _ad!.size.height.toDouble(),
      color: Colors.white,
      child: AdWidget(ad: _ad!),
    );
    if (!widget.safeArea) return banner;
    return SafeArea(top: false, child: banner);
  }
}

/// Wraps a screen body with an optional bottom ad banner for free users.
class AdScaffold extends StatelessWidget {
  final Widget body;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool showAd;

  const AdScaffold({
    super.key,
    required this.body,
    this.backgroundColor,
    this.appBar,
    this.bottomNavigationBar,
    this.showAd = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAd) const AdBannerWidget(),
          if (bottomNavigationBar != null) bottomNavigationBar!,
        ],
      ),
    );
  }
}
