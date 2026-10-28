import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_service.dart';
import 'pantry_service.dart';
import 'subscription_service.dart';

/// Checklist 05 — pantry upgrade prompts without being invasive.
class PantryUpgradePromptService {
  PantryUpgradePromptService._();

  static const _lastShownKey = 'pantry_upgrade_last_shown';
  static const _lastDismissKey = 'pantry_upgrade_last_dismiss';
  static const _dismissCountKey = 'pantry_upgrade_dismiss_count';

  /// Hard cap: one prompt per fortnight (5.2).
  static const showCooldown = Duration(days: 14);

  /// Base dismiss backoff (5.3); grows with each dismissal.
  static const baseDismissCooldown = Duration(days: 30);

  /// Don't sell an empty pantry (5.4).
  static const minItemsToPrompt = 5;

  static Future<bool> shouldShow({
    required int pantryItemCount,
    required int urgentCount,
  }) async {
    if (await SubscriptionService.isPremium()) return false;
    if (pantryItemCount < minItemsToPrompt) return false;
    // Value moment: prefer when something needs using (5.1).
    if (urgentCount <= 0 && pantryItemCount < 8) return false;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final lastShown = DateTime.tryParse(prefs.getString(_lastShownKey) ?? '');
    if (lastShown != null && now.difference(lastShown) < showCooldown) {
      return false;
    }

    final dismissCount = prefs.getInt(_dismissCountKey) ?? 0;
    final lastDismiss = DateTime.tryParse(prefs.getString(_lastDismissKey) ?? '');
    if (lastDismiss != null) {
      final backoff = baseDismissCooldown * (dismissCount <= 0 ? 1 : dismissCount);
      if (now.difference(lastDismiss) < backoff) return false;
    }
    return true;
  }

  static Future<void> recordShown({
    required int pantryItemCount,
    required int urgentCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastShownKey, DateTime.now().toIso8601String());
    await AnalyticsService.capture(
      AnalyticsService.pantryUpgradePromptShown,
      properties: {
        'pantry_item_count': pantryItemCount,
        'urgent_count': urgentCount,
      },
    );
  }

  static Future<void> recordDismissed({
    required int pantryItemCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_dismissCountKey) ?? 0) + 1;
    await prefs.setInt(_dismissCountKey, count);
    await prefs.setString(_lastDismissKey, DateTime.now().toIso8601String());
    await AnalyticsService.capture(
      AnalyticsService.pantryUpgradePromptDismissed,
      properties: {
        'pantry_item_count': pantryItemCount,
        'dismiss_count': count,
      },
    );
  }

  static Future<void> recordCtaTap({
    required int pantryItemCount,
    required String surface,
  }) async {
    await AnalyticsService.capture(
      AnalyticsService.pantryLockedCtaTapped,
      properties: {
        'pantry_item_count': pantryItemCount,
        'surface': surface,
      },
    );
  }

  static Future<void> recordLockedView({
    required int pantryItemCount,
    required int urgentCount,
  }) async {
    await AnalyticsService.capture(
      AnalyticsService.pantryLockedViewed,
      properties: {
        'pantry_item_count': pantryItemCount,
        'urgent_count': urgentCount,
      },
    );
  }

  static Future<void> recordUpgradeFromPantry({
    required int pantryItemCount,
  }) async {
    await AnalyticsService.capture(
      AnalyticsService.pantryUpgradedFromLocked,
      properties: {'pantry_item_count': pantryItemCount},
    );
  }

  /// Snapshot for home / pantry cards.
  static Future<({int total, int urgent, String? urgentName})?>
      snapshotIfPromptable() async {
    final items = await PantryService.getActive();
    final urgentItems = PantryService.useFirst(items, limit: 1);
    final urgentCount = items.where((i) {
      final d = i.daysUntilExpiry;
      return d != null && d <= 7;
    }).length;
    if (!await shouldShow(
      pantryItemCount: items.length,
      urgentCount: urgentCount,
    )) {
      return null;
    }
    return (
      total: items.length,
      urgent: urgentCount,
      urgentName: urgentItems.isEmpty ? null : urgentItems.first.name,
    );
  }

  static Future<void> clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastShownKey);
    await prefs.remove(_lastDismissKey);
    await prefs.remove(_dismissCountKey);
  }
}
