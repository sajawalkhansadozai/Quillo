import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quillo/screens/onboarding/preferences_screen.dart';
import 'package:quillo/services/auth_service.dart';
import 'package:quillo/services/onboarding_router.dart';

void main() {
  group('Onboarding completed flag (§2.1 / §2.2)', () {
    test('true only when explicitly true', () {
      expect(AuthService.isOnboardingCompletedFlag(true), isTrue);
    });

    test('false / null / missing means incomplete → show onboarding', () {
      expect(AuthService.isOnboardingCompletedFlag(false), isFalse);
      expect(AuthService.isOnboardingCompletedFlag(null), isFalse);
      expect(AuthService.isOnboardingCompletedFlag('true'), isFalse);
      expect(AuthService.isOnboardingCompletedFlag(1), isFalse);
    });

    test('acceptance: no prefs row behaves as incomplete', () {
      expect(AuthService.isOnboardingCompletedFlag(null), isFalse);
    });

    test('acceptance: abandoned mid-flow stays incomplete', () {
      expect(AuthService.isOnboardingCompletedFlag(false), isFalse);
    });

    test('acceptance: finished flow is complete', () {
      expect(AuthService.isOnboardingCompletedFlag(true), isTrue);
    });
  });

  group('Do not leak prefs across accounts', () {
    test('leftover local prefs without pendingSave are NOT applied', () {
      expect(
        OnboardingRouter.shouldApplyLocalOnboardingPrefs(
          remoteCompleted: false,
          pendingSave: false,
        ),
        isFalse,
      );
    });

    test('pendingSave from this signup session IS applied', () {
      expect(
        OnboardingRouter.shouldApplyLocalOnboardingPrefs(
          remoteCompleted: false,
          pendingSave: true,
        ),
        isTrue,
      );
    });

    test('already-complete remote account ignores pendingSave', () {
      expect(
        OnboardingRouter.shouldApplyLocalOnboardingPrefs(
          remoteCompleted: true,
          pendingSave: true,
        ),
        isFalse,
      );
    });
  });

  group('Returning-user onboarding copy (§3.2)', () {
    testWidgets('shows finish-setup banner when returningUser is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PreferencesScreen(returningUser: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('finish setting up your preferences'),
        findsOneWidget,
      );
    });

    testWidgets('hides finish-setup banner for fresh onboarding',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PreferencesScreen(returningUser: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('finish setting up your preferences'),
        findsNothing,
      );
    });
  });
}
