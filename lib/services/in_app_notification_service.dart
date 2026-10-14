import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app banners / overlays for Balanced Notifications §05.
class InAppNotificationService {
  InAppNotificationService._();

  static final _client = Supabase.instance.client;

  /// Ingredient from last complete scan that is 5+ days old and unused in recipes.
  static Future<String?> ageingIngredientName() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final scans = await _client
          .from('scans')
          .select('id, scan_date')
          .eq('user_id', uid)
          .eq('status', 'complete')
          .order('scan_date', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(scans as List);
      if (list.isEmpty) return null;
      final scan = list.first;
      final rawDate = scan['scan_date'] as String?;
      if (rawDate == null) return null;
      final scanned = DateTime.parse(rawDate).toUtc();
      final age = DateTime.now().toUtc().difference(scanned).inDays;
      if (age < 5) return null;

      final scanId = scan['id'] as String;
      final ingredients = await _client
          .from('ingredients')
          .select('normalised_name')
          .eq('scan_id', scanId)
          .limit(20);
      final names = List<Map<String, dynamic>>.from(ingredients as List)
          .map((r) => (r['normalised_name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isEmpty) return null;

      final recipes = await _client
          .from('recipes')
          .select('id')
          .eq('scan_id', scanId)
          .limit(1);
      final hasRecipes =
          List<Map<String, dynamic>>.from(recipes as List).isNotEmpty;
      // Soft rule: if recipes already generated for that scan, skip banner.
      if (hasRecipes) return null;

      final name = names.first;
      return name[0].toUpperCase() + name.substring(1);
    } catch (_) {
      return null;
    }
  }

  /// Returns 4, 8, or 12 when user just hit that week-streak and hasn't celebrated.
  static Future<int?> pendingStreakCelebration(int weekStreak) async {
    if (![4, 8, 12].contains(weekStreak)) return null;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('users')
          .select('celebrated_week_streaks')
          .eq('id', uid)
          .maybeSingle();
      final celebrated = List<int>.from(
        (row?['celebrated_week_streaks'] as List?) ?? const [],
      );
      if (celebrated.contains(weekStreak)) return null;
      return weekStreak;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markStreakCelebrated(int weeks) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('users')
          .select('celebrated_week_streaks')
          .eq('id', uid)
          .maybeSingle();
      final celebrated = List<int>.from(
        (row?['celebrated_week_streaks'] as List?) ?? const [],
      );
      if (celebrated.contains(weeks)) return;
      celebrated.add(weeks);
      await _client
          .from('users')
          .update({'celebrated_week_streaks': celebrated}).eq('id', uid);
    } catch (_) {}
  }

  static Future<int> lastMilestoneSeen() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    try {
      final row = await _client
          .from('users')
          .select('last_milestone_seen')
          .eq('id', uid)
          .maybeSingle();
      return (row?['last_milestone_seen'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markMilestoneSeen(int threshold) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client
          .from('users')
          .update({'last_milestone_seen': threshold}).eq('id', uid);
    } catch (_) {}
  }
}
