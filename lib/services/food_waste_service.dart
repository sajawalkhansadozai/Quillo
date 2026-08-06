import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ingredient_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FoodWasteService — tracks estimated food waste avoided (Premium dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class WasteStats {
  final double moneySavedGbp;
  final int itemsRescued;
  final int streak;
  final DateTime? memberSince;

  const WasteStats({
    this.moneySavedGbp = 0,
    this.itemsRescued = 0,
    this.streak = 0,
    this.memberSince,
  });
}

class FoodWasteService {
  static final _client = Supabase.instance.client;

  /// Average retail value per rescued ingredient item (£).
  static const double avgItemValueGbp = 3.50;

  static double estimateMoneySaved(int itemCount) =>
      itemCount * avgItemValueGbp;

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

  static Future<WasteStats> loadStats() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const WasteStats();

    try {
      final row = await _client
          .from('users')
          .select(
            'waste_money_saved, waste_items_rescued, scan_streak, created_at',
          )
          .eq('id', uid)
          .maybeSingle();

      if (row == null) return const WasteStats();

      return WasteStats(
        moneySavedGbp:
            ((row['waste_money_saved'] as num?) ?? 0).toDouble(),
        itemsRescued: (row['waste_items_rescued'] as int?) ?? 0,
        streak: (row['scan_streak'] as int?) ?? 0,
        memberSince: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
      );
    } catch (_) {
      return const WasteStats();
    }
  }
}
