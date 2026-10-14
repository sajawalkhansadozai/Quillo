import 'package:flutter_test/flutter_test.dart';
import 'package:quillo/config/iap_config.dart';
import 'package:quillo/services/subscription_service.dart';

void main() {
  group('Premium entitlement after expiry', () {
    test('active Quillo Pro entitlement means premium', () {
      expect(
        SubscriptionService.hasActivePremiumEntitlements(
          [IapConfig.premiumEntitlement],
        ),
        isTrue,
      );
    });

    test('empty entitlements means expired / free', () {
      expect(
        SubscriptionService.hasActivePremiumEntitlements(const []),
        isFalse,
      );
    });

    test('expired Quillo Pro (removed from active) means free', () {
      // Simulates RevenueCat after period ends: entitlement leaves `active`.
      expect(
        SubscriptionService.hasActivePremiumEntitlements(const <String>[]),
        isFalse,
      );
    });

    test('any other active entitlement still counts as premium (single-tier)', () {
      expect(
        SubscriptionService.hasActivePremiumEntitlements(['legacy_pro']),
        isTrue,
      );
    });
  });

  group('premiumNotifier downgrade behaviour', () {
    tearDown(() {
      SubscriptionService.premiumNotifier.value = false;
    });

    test('cached flag can flip from premium to free (UI listeners)', () {
      SubscriptionService.premiumNotifier.value = true;
      expect(SubscriptionService.isPremiumCached, isTrue);

      // What happens when RC reports expiry via listener / syncOnLaunch /
      // isPremium() → _applyPremiumStatus(false).
      SubscriptionService.premiumNotifier.value = false;
      expect(SubscriptionService.isPremiumCached, isFalse);
    });
  });
}
