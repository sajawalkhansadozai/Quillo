import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdBannerWidget — shows a Google AdMob banner for free users only.
// Hidden automatically when user upgrades to premium.
// ─────────────────────────────────────────────────────────────────────────────

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  bool _isPremium = false;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final premium = await SubscriptionService.isPremium();
    if (!mounted) return;
    setState(() => _isPremium = premium);
    if (!premium) _loadAd();
  }

  void _loadAd() {
    _ad = AdService.createBanner(
      onLoaded: (ad) {
        if (!mounted) return;
        setState(() {
          _ad = ad as BannerAd;
          _adLoaded = true;
        });
      },
      onFailed: (ad, error) {
        ad.dispose();
        if (!mounted) return;
        setState(() => _adLoaded = false);
      },
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPremium || !_adLoaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: _ad!.size.height.toDouble(),
        color: Colors.white,
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
