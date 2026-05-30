// ─────────────────────────────────────────────────────────────────────────────
// In-app purchases (RevenueCat)
//
// Test Store key (test_…) works on iOS + Android for development.
// For release, pass platform keys at build time (do not commit production keys):
//   flutter build ipa \
//     --dart-define=REVENUECAT_IOS_KEY=appl_xxx \
//     --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
// ─────────────────────────────────────────────────────────────────────────────

class IapConfig {
  IapConfig._();

  /// Must match the entitlement ID in RevenueCat dashboard.
  static const String premiumEntitlement = 'premium';

  /// Must match App Store Connect / Google Play product IDs exactly.
  static const String monthlyProductId = 'quillo.premium.monthly';
  static const String yearlyProductId = 'quillo.premium.yearly';

  static const String _testApiKey = 'test_AvZxqiXTdgpkslvnfRspgAkIyNc';

  static const String iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: 'appl_UGlHSFbMYSyltSNXPSBmesdVhOs',
  );

  static const String androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: _testApiKey,
  );

  static bool get isTestStoreKey =>
      iosApiKey.startsWith('test_') || androidApiKey.startsWith('test_');

  static bool get hasValidKeys =>
      iosApiKey.isNotEmpty &&
      androidApiKey.isNotEmpty &&
      !iosApiKey.contains('REPLACE') &&
      !androidApiKey.contains('REPLACE');
}
