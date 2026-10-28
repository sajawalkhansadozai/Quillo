import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/observability_config.dart';

/// BlindSpots 9.2 — six required events. No-ops if the key is missing (2.8).
class AnalyticsService {
  AnalyticsService._();

  static bool _ready = false;

  static const signedUp = 'signed up';
  static const scannedReceipt = 'scanned receipt';
  static const viewedRecipe = 'viewed recipe';
  static const addedToShoppingList = 'added to shopping list';
  static const upgradedToPremium = 'upgraded to premium';
  static const cancelledPremium = 'cancelled premium';

  // Smart Pantry checklist 06
  static const pantryLockedViewed = 'pantry locked viewed';
  static const pantryLockedCtaTapped = 'pantry locked cta tapped';
  static const pantryUpgradePromptShown = 'pantry upgrade prompt shown';
  static const pantryUpgradePromptDismissed = 'pantry upgrade prompt dismissed';
  static const pantryUpgradedFromLocked = 'pantry upgraded from locked';

  static Future<void> initialise() async {
    if (!ObservabilityConfig.posthogEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('gdpr_analytics') == false) return;

      final config = PostHogConfig(ObservabilityConfig.posthogApiKey)
        ..host = ObservabilityConfig.posthogHost
        ..captureApplicationLifecycleEvents = true
        ..debug = kDebugMode;
      await Posthog().setup(config);
      _ready = true;
    } catch (e, st) {
      debugPrint('PostHog init failed (app continues): $e\n$st');
    }
  }

  static Future<void> identify(String userId) async {
    if (!_ready || userId.isEmpty) return;
    try {
      await Posthog().identify(userId: userId);
    } catch (_) {}
  }

  static Future<void> reset() async {
    if (!_ready) return;
    try {
      await Posthog().reset();
    } catch (_) {}
  }

  static Future<void> capture(
    String event, {
    Map<String, Object>? properties,
  }) async {
    if (!_ready) return;
    try {
      await Posthog().capture(eventName: event, properties: properties);
    } catch (_) {}
  }
}
