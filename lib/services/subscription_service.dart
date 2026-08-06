import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/iap_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionService — RevenueCat in-app purchases & subscriptions
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionService {
  static final _client = Supabase.instance.client;
  static bool _configured = false;

  /// Global premium flag (checklist `isPremium`). Widgets listen via [premiumNotifier].
  static final ValueNotifier<bool> premiumNotifier = ValueNotifier(false);

  /// Cached `isPremium` — use for sync UI gates; call [isPremium] to refresh from RevenueCat.
  static bool get isPremiumCached => premiumNotifier.value;

  /// Set when [getOfferings] fails or returns no purchasable packages.
  static String? lastOfferingsError;

  static Future<void> configure() async {
    if (kIsWeb) return;

    final apiKey = Platform.isIOS
        ? IapConfig.iosApiKey
        : IapConfig.androidApiKey;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;

    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);

    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      await Purchases.logIn(uid);
    }
  }

  static void _onCustomerInfoUpdated(CustomerInfo info) {
    final isPrem =
        info.entitlements.active.containsKey(IapConfig.premiumEntitlement);
    // Entitlement updates drive instant ad hide/show (4.4 / 4.5).
    _applyPremiumStatus(isPrem);
  }

  /// Call after every successful sign-in / sign-up.
  static Future<void> linkUserAfterAuth() async {
    if (!_configured || kIsWeb) return;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await Purchases.logIn(uid);
      await syncOnLaunch();
    } catch (_) {}
  }

  /// Call on sign-out.
  static Future<void> logOut() async {
    if (!_configured || kIsWeb) return;
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  /// RevenueCat entitlement is the source of truth for ads (4.1 / 4.5).
  /// Supabase is updated only when the entitlement changes.
  static Future<bool> isPremium() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        premiumNotifier.value = false;
        return false;
      }

      if (_configured && !kIsWeb) {
        final info = await Purchases.getCustomerInfo();
        final prem = info.entitlements.active
            .containsKey(IapConfig.premiumEntitlement);
        await _applyPremiumStatus(prem);
        return prem;
      }

      final row = await _client
          .from('users')
          .select('subscription_status')
          .eq('id', uid)
          .maybeSingle();
      final prem = row?['subscription_status'] == 'premium';
      premiumNotifier.value = prem;
      return prem;
    } catch (_) {
      return premiumNotifier.value;
    }
  }

  /// Re-check RevenueCat (call when opening screens — checklist 4.3).
  static Future<bool> refreshPremiumStatus() => isPremium();

  static Future<void> _applyPremiumStatus(bool isPrem) async {
    final changed = premiumNotifier.value != isPrem;
    premiumNotifier.value = isPrem;
    if (changed) {
      await _syncStatusToSupabase(isPrem ? 'premium' : 'free');
    }
  }

  static Future<Offerings?> getOfferings() async {
    lastOfferingsError = null;
    if (!_configured) {
      lastOfferingsError = 'RevenueCat did not initialise. Restart the app.';
      return null;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final offering = _currentOffering(offerings);
      if (offering == null) {
        lastOfferingsError =
            'No offering is marked Current in RevenueCat, or it has no packages.';
        return offerings;
      }
      if (monthlyPackage(offerings) == null && yearlyPackage(offerings) == null) {
        final ids = offering.availablePackages
            .map((p) => p.storeProduct.identifier)
            .join(', ');
        lastOfferingsError = ids.isEmpty
            ? 'App Store did not return subscription products yet. Complete subscription metadata in App Store Connect, link App Store Connect in RevenueCat, and wait up to a few hours after saving.'
            : 'Could not match monthly/yearly packages. Found: $ids. Expected ${IapConfig.monthlyProductId} and ${IapConfig.yearlyProductId}.';
      }
      return offerings;
    } on PlatformException catch (e) {
      lastOfferingsError = _offeringsErrorMessage(e);
      debugPrint('RevenueCat getOfferings failed: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      lastOfferingsError = 'Could not load subscription plans. Please try again.';
      debugPrint('RevenueCat getOfferings failed: $e');
      return null;
    }
  }

  static String _offeringsErrorMessage(PlatformException e) {
    final code = e.code;
    final msg = e.message ?? '';
    if (code == '23' ||
        msg.contains('CONFIGURATION') ||
        msg.contains('could not be fetched from App Store')) {
      return 'App Store products could not be loaded. Check: subscriptions are not '
          '"Missing Metadata" in App Store Connect; RevenueCat is linked to App Store '
          'Connect (API key); product IDs match; Paid Apps agreement is active; test on '
          'a real iPhone with a Sandbox account (or run from Xcode with Quillo.storekit).';
    }
    if (msg.length > 120) return msg.substring(0, 120);
    return msg.isNotEmpty ? msg : 'Could not load subscription plans.';
  }

  static String get offeringsUnavailableMessage =>
      lastOfferingsError ??
      'Subscription plans are not available yet. Check RevenueCat and App Store Connect, then try again.';

  static const String offeringsSnackBarMessage =
      'Plans not loaded — see setup steps on this screen.';

  static Offering? _currentOffering(Offerings? offerings) {
    if (offerings == null) return null;
    final current = offerings.current;
    if (current != null && current.availablePackages.isNotEmpty) {
      return current;
    }
    for (final o in offerings.all.values) {
      if (o.availablePackages.isNotEmpty) return o;
    }
    return current;
  }

  static Package? _packageByProductId(Offering? offering, String productId) {
    if (offering == null) return null;
    for (final pkg in offering.availablePackages) {
      if (pkg.storeProduct.identifier == productId) return pkg;
    }
    return null;
  }

  static Package? monthlyPackage(Offerings? offerings) {
    final offering = _currentOffering(offerings);
    return offering?.monthly ??
        _packageByProductId(offering, IapConfig.monthlyProductId);
  }

  static Package? yearlyPackage(Offerings? offerings) {
    final offering = _currentOffering(offerings);
    return offering?.annual ??
        _packageByProductId(offering, IapConfig.yearlyProductId);
  }

  static Future<PurchaseResult> purchase(Package package) async {
    if (!_configured) {
      return const PurchaseResult(
        success: false,
        error: 'Subscriptions are not configured yet. Add RevenueCat API keys.',
      );
    }
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final isPrem = result.customerInfo.entitlements.active
          .containsKey(IapConfig.premiumEntitlement);
      premiumNotifier.value = isPrem;
      await _syncStatusToSupabase(isPrem ? 'premium' : 'free');
      return PurchaseResult(success: isPrem);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: _friendlyError(code));
    } catch (e) {
      return PurchaseResult(
        success: false,
        error: 'Purchase failed. Please try again.',
      );
    }
  }

  static Future<PurchaseResult> restorePurchases() async {
    if (!_configured) {
      return const PurchaseResult(
        success: false,
        error: 'Subscriptions are not configured yet.',
      );
    }
    try {
      final info = await Purchases.restorePurchases();
      final isPrem =
          info.entitlements.active.containsKey(IapConfig.premiumEntitlement);
      premiumNotifier.value = isPrem;
      await _syncStatusToSupabase(isPrem ? 'premium' : 'free');
      return PurchaseResult(success: isPrem, restored: true);
    } catch (e) {
      return PurchaseResult(
        success: false,
        error: 'Restore failed. Please try again.',
      );
    }
  }

  static Future<void> syncOnLaunch() async {
    if (!_configured) return;
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;

      await Purchases.logIn(uid);
      final info = await Purchases.getCustomerInfo();
      final isPrem =
          info.entitlements.active.containsKey(IapConfig.premiumEntitlement);
      await _syncStatusToSupabase(isPrem ? 'premium' : 'free');
      premiumNotifier.value = isPrem;
    } catch (_) {}
  }

  static Future<void> _syncStatusToSupabase(String status) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;

      await _client
          .from('users')
          .update({'subscription_status': status})
          .eq('id', uid);

      if (status == 'premium') {
        await _client.rpc('set_premium_limit', params: {'p_user_id': uid});
        premiumNotifier.value = true;
      } else {
        premiumNotifier.value = false;
      }
    } catch (_) {}
  }

  static String _friendlyError(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return 'No internet connection. Please try again.';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'This product is not available in your region.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Payment is pending approval.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.configurationError:
        return 'Store is not configured. Check RevenueCat setup.';
      default:
        return 'Purchase failed. Please try again.';
    }
  }
}

class PurchaseResult {
  final bool success;
  final bool cancelled;
  final bool restored;
  final String? error;

  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.restored = false,
    this.error,
  });
}
