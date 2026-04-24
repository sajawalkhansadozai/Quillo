import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StreakService — manages the daily scan streak counter
// ─────────────────────────────────────────────────────────────────────────────

class StreakService {
  static final _client = Supabase.instance.client;

  /// Called immediately after a successful scan.
  /// Compares last_scan_date with today and increments or resets streak.
  static Future<int> recordScan() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;

    try {
      final row = await _client
          .from('users')
          .select('scan_streak, last_scan_date')
          .eq('id', uid)
          .maybeSingle();

      final today = DateTime.now().toUtc();
      final todayDate = DateTime.utc(today.year, today.month, today.day);
      final todayStr = todayDate.toIso8601String().split('T')[0];

      int currentStreak = (row?['scan_streak'] as int?) ?? 0;
      final lastScanStr = row?['last_scan_date'] as String?;

      if (lastScanStr != null) {
        final lastScanDate = DateTime.parse(lastScanStr);
        final diff = todayDate.difference(lastScanDate).inDays;

        if (diff == 0) {
          // Already scanned today — keep streak as-is
          return currentStreak;
        } else if (diff == 1) {
          // Consecutive day — increment
          currentStreak += 1;
        } else {
          // Missed at least one day — reset
          currentStreak = 1;
        }
      } else {
        // First scan ever
        currentStreak = 1;
      }

      await _client.from('users').update({
        'scan_streak': currentStreak,
        'last_scan_date': todayStr,
      }).eq('id', uid);

      return currentStreak;
    } catch (_) {
      return 0;
    }
  }

  /// Loads the current streak without modifying it.
  static Future<int> getCurrentStreak() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final row = await _client
          .from('users')
          .select('scan_streak, last_scan_date')
          .eq('id', uid)
          .maybeSingle();

      final streak = (row?['scan_streak'] as int?) ?? 0;
      final lastScanStr = row?['last_scan_date'] as String?;

      // If last scan was >1 day ago, streak is broken
      if (lastScanStr != null) {
        final lastScan = DateTime.parse(lastScanStr);
        final today = DateTime.now().toUtc();
        final todayDate = DateTime.utc(today.year, today.month, today.day);
        final diff = todayDate.difference(lastScan).inDays;
        if (diff > 1) return 0;
      }

      return streak;
    } catch (_) {
      return 0;
    }
  }
}
