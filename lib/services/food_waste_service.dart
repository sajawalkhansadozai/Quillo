import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ingredient_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FoodWasteService — tracks estimated food waste avoided (Premium dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class WeeklySaving {
  final DateTime weekStart;
  final double amountGbp;

  const WeeklySaving({required this.weekStart, required this.amountGbp});
}

class WasteMilestone {
  final String label;
  final bool unlocked;

  const WasteMilestone({required this.label, required this.unlocked});
}

class WasteStats {
  final double moneySavedGbp;
  final int itemsRescued;
  final int dayStreak;
  final int weekStreak;
  final int bestWeekStreak;
  final int totalScans;
  final double kgAvoided;
  final double ukComparisonPercent;
  final double monthlyWasteAvoidedGbp;
  final List<WeeklySaving> weeklySavings;
  final List<WasteMilestone> milestones;
  final DateTime? memberSince;

  const WasteStats({
    this.moneySavedGbp = 0,
    this.itemsRescued = 0,
    this.dayStreak = 0,
    this.weekStreak = 0,
    this.bestWeekStreak = 0,
    this.totalScans = 0,
    this.kgAvoided = 0,
    this.ukComparisonPercent = 0,
    this.monthlyWasteAvoidedGbp = 0,
    this.weeklySavings = const [],
    this.milestones = const [],
    this.memberSince,
  });
}

class FoodWasteService {
  static final _client = Supabase.instance.client;

  /// Average retail value per rescued ingredient item (£).
  static const double avgItemValueGbp = 3.50;

  /// ~0.5 kg food waste per £1 saved (WRAP-style estimate).
  static const double kgPerGbpSaved = 0.5;

  /// UK average household food waste spend per week (£).
  static const double ukAverageWeeklyWasteGbp = 13.46;

  static double estimateMoneySaved(int itemCount) =>
      itemCount * avgItemValueGbp;

  static double estimateKgAvoided(double moneyGbp) => moneyGbp * kgPerGbpSaved;

  /// Record waste avoided after a successful scan / recipe generation.
  static Future<void> recordIngredientsRescued(
    List<IngredientItem> ingredients,
  ) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || ingredients.isEmpty) return;

    final items = ingredients.length;
    final money = estimateMoneySaved(items);

    try {
      await _client.rpc('record_food_waste_saved', params: {
        'p_user_id': uid,
        'p_items': items,
        'p_money': money,
      });
    } catch (_) {}
  }

  static DateTime _weekStartUtc(DateTime dt) {
    final d = DateTime.utc(dt.year, dt.month, dt.day);
    final weekday = d.weekday; // Mon=1
    return d.subtract(Duration(days: weekday - 1));
  }

  static int _consecutiveWeeksEndingNow(Set<DateTime> weekStarts) {
    if (weekStarts.isEmpty) return 0;
    final sorted = weekStarts.toList()..sort((a, b) => b.compareTo(a));
    var streak = 0;
    var cursor = _weekStartUtc(DateTime.now().toUtc());
    for (final w in sorted) {
      if (w == cursor) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 7));
      } else if (w.isBefore(cursor)) {
        break;
      }
    }
    return streak;
  }

  static int _bestConsecutiveWeeks(Set<DateTime> weekStarts) {
    if (weekStarts.isEmpty) return 0;
    final sorted = weekStarts.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 7) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  static List<WasteMilestone> _milestones(
    double moneySaved,
    int totalScans,
  ) {
    return [
      WasteMilestone(label: 'First scan', unlocked: totalScans >= 1),
      WasteMilestone(label: '£50 saved', unlocked: moneySaved >= 50),
      WasteMilestone(label: '£100 saved', unlocked: moneySaved >= 100),
      WasteMilestone(label: '£250 saved', unlocked: moneySaved >= 250),
      WasteMilestone(label: '£500 saved', unlocked: moneySaved >= 500),
    ];
  }

  static Future<WasteStats> loadStats() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const WasteStats();

    try {
      final userRow = await _client
          .from('users')
          .select(
            'waste_money_saved, waste_items_rescued, scan_streak, created_at',
          )
          .eq('id', uid)
          .maybeSingle();

      if (userRow == null) return const WasteStats();

      final moneySaved =
          ((userRow['waste_money_saved'] as num?) ?? 0).toDouble();
      final itemsRescued = (userRow['waste_items_rescued'] as int?) ?? 0;
      final dayStreak = (userRow['scan_streak'] as int?) ?? 0;
      final memberSince = userRow['created_at'] != null
          ? DateTime.tryParse(userRow['created_at'] as String)
          : null;

      final scans = await _client
          .from('scans')
          .select('id, scan_date, status')
          .eq('user_id', uid)
          .eq('status', 'complete');

      final scanList = List<Map<String, dynamic>>.from(scans as List);
      final totalScans = scanList.length;

      final scanIds = scanList.map((s) => s['id'] as String).toList();
      final ingredientCounts = <String, int>{};

      if (scanIds.isNotEmpty) {
        final ingredients = await _client
            .from('ingredients')
            .select('scan_id')
            .eq('user_id', uid);
        for (final row in List<Map<String, dynamic>>.from(ingredients as List)) {
          final sid = row['scan_id'] as String?;
          if (sid != null) {
            ingredientCounts[sid] = (ingredientCounts[sid] ?? 0) + 1;
          }
        }
      }

      final now = DateTime.now().toUtc();
      final chartStart = _weekStartUtc(
        now.subtract(const Duration(days: 7 * 7)),
      );

      final weekTotals = <DateTime, double>{};
      final weekStartsWithScans = <DateTime>{};

      for (final scan in scanList) {
        final rawDate = scan['scan_date'] as String?;
        if (rawDate == null) continue;
        final scanDate = DateTime.parse(rawDate).toUtc();
        final week = _weekStartUtc(scanDate);
        weekStartsWithScans.add(week);

        if (week.isBefore(chartStart)) continue;
        final sid = scan['id'] as String;
        final count = ingredientCounts[sid] ?? 0;
        weekTotals[week] =
            (weekTotals[week] ?? 0) + estimateMoneySaved(count);
      }

      final weeklySavings = <WeeklySaving>[];
      var cursor = chartStart;
      final thisWeek = _weekStartUtc(now);
      while (!cursor.isAfter(thisWeek)) {
        weeklySavings.add(
          WeeklySaving(
            weekStart: cursor,
            amountGbp: weekTotals[cursor] ?? 0,
          ),
        );
        cursor = cursor.add(const Duration(days: 7));
      }

      final monthStart = DateTime.utc(now.year, now.month, 1);
      var monthlySaved = 0.0;
      for (final scan in scanList) {
        final rawDate = scan['scan_date'] as String?;
        if (rawDate == null) continue;
        final scanDate = DateTime.parse(rawDate).toUtc();
        if (scanDate.isBefore(monthStart)) continue;
        final sid = scan['id'] as String;
        monthlySaved += estimateMoneySaved(ingredientCounts[sid] ?? 0);
      }

      final weekStreak = _consecutiveWeeksEndingNow(weekStartsWithScans);
      final bestWeekStreak = _bestConsecutiveWeeks(weekStartsWithScans);

      final userWeeklyAvg = weeklySavings.isEmpty
          ? 0.0
          : weeklySavings.map((w) => w.amountGbp).reduce((a, b) => a + b) /
              weeklySavings.length;

      final ukComparisonPercent = ukAverageWeeklyWasteGbp <= 0
          ? 0
          : ((userWeeklyAvg / ukAverageWeeklyWasteGbp) - 1) * 100;

      return WasteStats(
        moneySavedGbp: moneySaved,
        itemsRescued: itemsRescued,
        dayStreak: dayStreak,
        weekStreak: weekStreak,
        bestWeekStreak: bestWeekStreak,
        totalScans: totalScans,
        kgAvoided: estimateKgAvoided(moneySaved),
        ukComparisonPercent: ukComparisonPercent.clamp(0, 999).toDouble(),
        monthlyWasteAvoidedGbp: monthlySaved,
        weeklySavings: weeklySavings,
        milestones: _milestones(moneySaved, totalScans),
        memberSince: memberSince,
      );
    } catch (_) {
      return const WasteStats();
    }
  }
}
