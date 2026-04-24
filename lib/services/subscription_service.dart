import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubscriptionService — RevenueCat integration
//
// SETUP REQUIRED (client):
//   1. Create RevenueCat account at https://app.revenuecat.com
//   2. Add $5.99/month and $49.99/year products in App Store Connect & Google Play
//   3. Replace the API keys below with your real RevenueCat public keys
//   4. Set entitlement identifier to 'premium' in RevenueCat dashboard
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionService {
  // ── Replace these with your RevenueCat public API keys ─────────────────────
  static const String _iosApiKey = 'appl_REPLACE_WITH_YOUR_IOS_KEY';
  static const String _androidApiKey = 'goog_REPLACE_WITH_YOUR_ANDROID_KEY';

  static const String _premiumEntitlement = 'premium';

  static final _client = Supabase.instance.client;

  // ── Configure RevenueCat (call from main.dart) ──────────────────────────────

  static Future<void> configure() async {
    await Purchases.setLogLevel(LogLevel.error);

    final config = Platform.isIOS
        ? PurchasesConfiguration(_iosApiKey)
        : PurchasesConfiguration(_androidApiKey);

    await Purchases.configure(config);

    // Set user ID to match Supabase user
    final uid = _client.auth.currentUser?.id;
    if (uid != null) {
      await Purchases.logIn(uid);
    }
  }

  // ── Check if current user is premium ────────────────────────────────────────

  static Future<bool> isPremium() async {
    // Fast path: check local Supabase cache first
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return false;

      final row = await _client
          .from('users')
          .select('subscription_status')
          .eq('id', uid)
          .maybeSingle();

      if (row?['subscription_status'] == 'premium') return true;

      // Also verify with RevenueCat (authoritative)
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_premiumEntitlement);
    } catch (_) {
      return false;
    }
  }

  // ── Get available offerings ──────────────────────────────────────────────────

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  // ── Purchase a package ───────────────────────────────────────────────────────

  static Future<PurchaseResult> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final info = result.customerInfo;
      final isPrem = info.entitlements.active.containsKey(_premiumEntitlement);
      if (isPrem) {
        await _syncStatusToSupabase('premium');
      }
      return PurchaseResult(success: isPrem);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: _friendlyError(e));
    } catch (e) {
      return PurchaseResult(success: false, error: 'Purchase failed. Please try again.');
    }
  }

  // ── Restore purchases ────────────────────────────────────────────────────────

  static Future<PurchaseResult> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final isPrem = info.entitlements.active.containsKey(_premiumEntitlement);
      if (isPrem) {
        await _syncStatusToSupabase('premium');
      }
      return PurchaseResult(success: isPrem, restored: true);
    } catch (e) {
      return PurchaseResult(success: false, error: 'Restore failed. Please try again.');
    }
  }

  // ── Sync on every app launch ─────────────────────────────────────────────────

  static Future<void> syncOnLaunch() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await Purchases.logIn(uid);
      final info = await Purchases.getCustomerInfo();
      final isPrem = info.entitlements.active.containsKey(_premiumEntitlement);
      await _syncStatusToSupabase(isPrem ? 'premium' : 'free');
    } catch (_) {}
  }

  // ── Sync subscription status to Supabase ────────────────────────────────────

  static Future<void> _syncStatusToSupabase(String status) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await _client
          .from('users')
          .update({'subscription_status': status})
          .eq('id', uid);
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
      default:
        return 'Purchase failed. Please try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
