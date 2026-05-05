import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyLimitService — tracks free-user daily scan/recipe generations
//
// Free users get 3 scans per calendar day.
// Premium users are always allowed through.
// ─────────────────────────────────────────────────────────────────────────────

class DailyLimitService {
  static const int freeLimit = 3;

  static const _keyDate  = 'daily_limit_date';
  static const _keyCount = 'daily_limit_count';

  /// Returns the number of scans used today (resets at midnight).
  static Future<int> todayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if (prefs.getString(_keyDate) != today) {
      // New day — reset
      await prefs.setString(_keyDate, today);
      await prefs.setInt(_keyCount, 0);
      return 0;
    }
    return prefs.getInt(_keyCount) ?? 0;
  }

  /// Returns true if the user may perform another scan.
  /// Premium users are always allowed.
  static Future<bool> canScan() async {
    if (await SubscriptionService.isPremium()) return true;
    return await todayCount() < freeLimit;
  }

  /// Call this AFTER a scan succeeds to record the usage.
  static Future<void> recordScan() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    if (prefs.getString(_keyDate) != today) {
      await prefs.setString(_keyDate, today);
      await prefs.setInt(_keyCount, 1);
    } else {
      final current = prefs.getInt(_keyCount) ?? 0;
      await prefs.setInt(_keyCount, current + 1);
    }
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
