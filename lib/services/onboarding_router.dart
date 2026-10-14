import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/Home/main_shell.dart';
import '../screens/onboarding/preferences_screen.dart';
import 'auth_service.dart';

/// Post-auth navigation — identical for email, Google, and Apple (§2.2 / §2.3).
class OnboardingRouter {
  OnboardingRouter._();

  static const _returningKey = 'onboarding_returning_user';
  /// Set only when THIS device just finished the pref screens and is about to
  /// create/confirm an account — never reuse another user's leftover prefs.
  static const pendingSaveKey = 'onboarding_pending_save';

  static const _localPrefKeys = [
    'onboarding_household_size',
    'onboarding_max_cook_time',
    'onboarding_dietary',
    'onboarding_cuisines',
    'onboarding_skill_level',
    pendingSaveKey,
    _returningKey,
  ];

  /// Pure helper — never apply leftover local prefs unless pendingSave is set.
  static bool shouldApplyLocalOnboardingPrefs({
    required bool remoteCompleted,
    required bool pendingSave,
  }) =>
      !remoteCompleted && pendingSave;

  /// Call after any successful authentication (or on cold start with a session).
  static Future<Widget> destinationAfterAuth() async {
    var completed = await AuthService.hasCompletedOnboarding();
    if (!completed) {
      final prefs = await SharedPreferences.getInstance();
      final pendingSave = prefs.getBool(pendingSaveKey) == true;
      if (shouldApplyLocalOnboardingPrefs(
        remoteCompleted: completed,
        pendingSave: pendingSave,
      )) {
        await AuthService.completeOnboardingFromLocalPrefs();
        await clearLocalOnboardingPrefs();
        completed = true;
      }
    }
    if (completed) {
      await clearReturningFlag();
      return const MainShell();
    }
    final prefs = await SharedPreferences.getInstance();
    // New Google/Apple account must not inherit a previous user's local prefs.
    await clearLocalOnboardingPrefs();
    await prefs.setBool(_returningKey, true);
    return const PreferencesScreen(returningUser: true);
  }

  static Future<void> navigateAfterAuth(BuildContext context) async {
    final dest = await destinationAfterAuth();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dest),
      (_) => false,
    );
  }

  /// Mark that local SharedPreferences prefs belong to the upcoming signup.
  static Future<void> markPendingSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pendingSaveKey, true);
  }

  static Future<bool> isReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_returningKey) ?? false;
  }

  static Future<void> clearReturningFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_returningKey);
  }

  /// Clear device onboarding draft — call on sign-out and before recovery flow.
  static Future<void> clearLocalOnboardingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _localPrefKeys) {
      await prefs.remove(key);
    }
  }
}
