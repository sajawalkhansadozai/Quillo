import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/observability_config.dart';
import '../navigation/app_navigator.dart';
import '../screens/Home/scan_screen.dart';
import '../screens/food_waste/food_waste_dashboard_screen.dart';
import 'notification_prefs_service.dart';

/// BlindSpots 8.x — OneSignal optional; never blocks launch (2.8).
class PushNotificationService {
  PushNotificationService._();

  static bool _ready = false;
  static bool _clickBound = false;
  static const _askedAfterRecipeKey = 'push_permission_asked_after_recipe';

  static Future<void> initialise() async {
    if (kIsWeb || !ObservabilityConfig.oneSignalEnabled) return;
    try {
      await OneSignal.initialize(ObservabilityConfig.oneSignalAppId);
      _ready = true;
      _bindClickListener();

      final prefs = await SharedPreferences.getInstance();
      final optedIn = prefs.getBool('push_notifications') ?? true;
      await applyOptOut(!optedIn);
    } catch (e, st) {
      debugPrint('OneSignal init failed (app continues): $e\n$st');
    }
  }

  static Future<void> login(String userId) async {
    if (!_ready || userId.isEmpty) return;
    try {
      await OneSignal.login(userId);
      await NotificationPrefsService.syncToSupabase();
    } catch (_) {}
  }

  /// 8.4 — Settings toggle must opt the device out of all pushes.
  static Future<void> applyOptOut(bool optedOut) async {
    if (!_ready) return;
    try {
      if (optedOut) {
        await OneSignal.User.pushSubscription.optOut();
      } else {
        await OneSignal.User.pushSubscription.optIn();
      }
    } catch (_) {}
  }

  /// 8.1 — ask only after the user has seen their first recipe. Never twice.
  static Future<void> requestAfterFirstRecipe() async {
    if (!_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedAfterRecipeKey) == true) return;
      if (prefs.getBool('push_notifications') == false) return;
      await prefs.setBool(_askedAfterRecipeKey, true);
      await OneSignal.Notifications.requestPermission(true);
      await NotificationPrefsService.syncToSupabase();
    } catch (_) {}
  }

  static void _bindClickListener() {
    if (_clickBound) return;
    _clickBound = true;
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData ?? {};
      _handleDeepLink(data);
    });
  }

  /// Open scan, waste dashboard, or explore from notification payload.
  static void _handleDeepLink(Map<String, dynamic> data) {
    final nav = appNavigator;
    if (nav == null) return;

    final screen =
        (data['screen'] ?? data['route'] ?? '').toString().toLowerCase();
    final ingredient = (data['ingredient'] ?? '').toString();
    final recipeTitle = (data['recipe_title'] ?? data['title'] ?? '').toString();

    if (screen == 'scan' || screen == 'receipt') {
      nav.push(MaterialPageRoute(builder: (_) => const ScanScreen()));
      return;
    }
    if (screen == 'waste' || screen == 'foodwaste' || screen == 'impact') {
      nav.push(
        MaterialPageRoute(builder: (_) => const FoodWasteDashboardScreen()),
      );
      return;
    }
    if (ingredient.isNotEmpty ||
        recipeTitle.isNotEmpty ||
        screen == 'recipe' ||
        screen == 'explore') {
      nav.pushNamedAndRemoveUntil('/', (_) => false);
      return;
    }
  }
}
