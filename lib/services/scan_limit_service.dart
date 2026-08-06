import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScanLimitService — monthly receipt scan quota for free users
//
// Free users get 2 scans per calendar month.
// Premium users are always allowed through.
// ─────────────────────────────────────────────────────────────────────────────

class ScanLimitService {
  static const int freeMonthlyLimit = 2;

  static const _keyPeriod = 'scan_limit_period';
  static const _keyCount = 'scan_limit_count';

  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Returns scans used this month (resets on the 1st).
  static Future<int> monthlyCount() async {
    await _syncFromServer();
    final prefs = await SharedPreferences.getInstance();
    final period = _currentPeriod();
    if (prefs.getString(_keyPeriod) != period) {
      await prefs.setString(_keyPeriod, period);
      await prefs.setInt(_keyCount, 0);
      return 0;
    }
    return prefs.getInt(_keyCount) ?? 0;
  }

  static Future<int> remainingScans() async {
    if (await SubscriptionService.isPremium()) return freeMonthlyLimit;
    final used = await monthlyCount();
    return (freeMonthlyLimit - used).clamp(0, freeMonthlyLimit);
  }

  /// Returns true if the user may perform another scan.
  static Future<bool> canScan() async {
    if (await SubscriptionService.isPremium()) return true;
    return await monthlyCount() < freeMonthlyLimit;
  }

  /// Call once per completed receipt scan or manual recipe generation.
  static Future<void> recordScan() async {
    if (await SubscriptionService.isPremium()) return;

    final prefs = await SharedPreferences.getInstance();
    final period = _currentPeriod();
    if (prefs.getString(_keyPeriod) != period) {
      await prefs.setString(_keyPeriod, period);
      await prefs.setInt(_keyCount, 1);
    } else {
      final current = prefs.getInt(_keyCount) ?? 0;
      await prefs.setInt(_keyCount, current + 1);
    }
  }

  static Future<void> _syncFromServer() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('monthly_scan_count, monthly_scan_period')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return;

      final serverPeriod = row['monthly_scan_period'] as String?;
      final serverCount = (row['monthly_scan_count'] as int?) ?? 0;
      final period = _currentPeriod();

      if (serverPeriod == period) {
        final prefs = await SharedPreferences.getInstance();
        final local = prefs.getInt(_keyCount) ?? 0;
        if (serverCount > local) {
          await prefs.setString(_keyPeriod, period);
          await prefs.setInt(_keyCount, serverCount);
        }
      }
    } catch (_) {}
  }
}
