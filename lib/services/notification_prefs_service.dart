import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_notification_service.dart';

/// Balanced Notifications §06 — per-type push toggles + timezone sync.
class NotificationPrefsService {
  NotificationPrefsService._();

  static const expiryKey = 'push_expiry_enabled';
  static const streakKey = 'push_streak_enabled';
  static const milestoneKey = 'push_milestone_enabled';
  static const masterKey = 'push_notifications';

  static final _client = Supabase.instance.client;

  static Future<Map<String, bool>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'master': prefs.getBool(masterKey) ?? true,
      'expiry': prefs.getBool(expiryKey) ?? true,
      'streak': prefs.getBool(streakKey) ?? true,
      'milestone': prefs.getBool(milestoneKey) ?? true,
    };
  }

  static Future<void> setMaster(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(masterKey, enabled);
    await PushNotificationService.applyOptOut(!enabled);
    if (enabled) await syncToSupabase();
  }

  static Future<void> setExpiry(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(expiryKey, enabled);
    await syncToSupabase();
  }

  static Future<void> setStreak(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(streakKey, enabled);
    await syncToSupabase();
  }

  static Future<void> setMilestone(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(milestoneKey, enabled);
    await syncToSupabase();
  }

  static String deviceTimezone() {
    try {
      return DateTime.now().timeZoneName;
    } catch (_) {
      return 'Europe/London';
    }
  }

  /// IANA-ish timezone: prefer locale offset mapping; fall back to London.
  static String ianaTimezone() {
    // Dart doesn't expose IANA IDs reliably; store offset-based label + London default.
    // Server quiet-hours use Europe/London when unknown.
    final name = DateTime.now().timeZoneName;
    if (name.contains('/')) return name;
    // Common UK devices report "GMT" / "BST"
    if (name == 'GMT' || name == 'BST' || name == 'UTC') return 'Europe/London';
    return 'Europe/London';
  }

  static Future<void> syncToSupabase() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _client.rpc('update_notification_prefs', params: {
        'p_expiry': prefs.getBool(expiryKey) ?? true,
        'p_streak': prefs.getBool(streakKey) ?? true,
        'p_milestone': prefs.getBool(milestoneKey) ?? true,
        'p_timezone': ianaTimezone(),
      });
    } catch (e) {
      debugPrint('update_notification_prefs failed: $e');
    }
  }
}
