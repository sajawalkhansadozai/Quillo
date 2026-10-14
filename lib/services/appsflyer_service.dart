import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/appsflyer_config.dart';
import 'crash_reporting_service.dart';

/// AppsFlyer install attribution. Never blocks or crashes launch (2.8): it is
/// started after runApp without awaiting, and every SDK call is guarded.
///
/// Sessions are only sent once the user has answered the GDPR screen and
/// allowed analytics. A first-launch session held back for the GDPR screen is
/// sent from [onConsentChanged]. On iOS the first session waits for the ATT
/// prompt so the IDFA can be included.
class AppsFlyerService {
  AppsFlyerService._();

  static bool _initialised = false;
  static bool _startPending = false;

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> initialise() async {
    if (_initialised || !_isSupportedPlatform) return;
    if (AppsFlyerConfig.devKey.trim().isEmpty ||
        (_isIOS && AppsFlyerConfig.iosAppId.trim().isEmpty)) {
      debugPrint('AppsFlyer: skipped — key not set');
      return;
    }

    try {
      final sdk = AppsFlyerSdk.instance;
      await sdk.enableDebug(AppsFlyerConfig.debugLogs);
      await sdk.init(
        devKey: AppsFlyerConfig.devKey,
        appId: _isIOS ? AppsFlyerConfig.iosAppId : null,
      );
      _initialised = true;

      // Registered last: the callback can fire immediately. It runs on every
      // cold start and every return to the foreground.
      await sdk.registerSessionReadyListener(_startIfAllowed);
    } catch (e, st) {
      debugPrint('AppsFlyer init failed (app continues): $e');
      await CrashReportingService.capture(
        e,
        stackTrace: st,
        context: 'appsflyer_init',
      );
    }
  }

  /// Call after the GDPR screen saves the user's choice.
  static Future<void> onConsentChanged() async {
    if (!_initialised || !_startPending) return;
    await _startIfAllowed();
  }

  static Future<void> _startIfAllowed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('gdpr_shown') ?? false)) {
        _startPending = true;
        return;
      }
      _startPending = false;

      final analytics = prefs.getBool('gdpr_analytics') ?? false;
      if (!analytics) return;
      final personalised = prefs.getBool('gdpr_personalised') ?? false;

      if (_isIOS) await _waitForTrackingDecision();

      final sdk = AppsFlyerSdk.instance;
      // Consent is kept in memory only, so it is re-applied before each start.
      await sdk.setConsentData(
        isUserSubjectToGDPR: true,
        hasConsentForDataUsage: analytics,
        hasConsentForAdsPersonalization: personalised,
        hasConsentForAdStorage: personalised,
      );
      await sdk.start();
    } catch (e, st) {
      debugPrint('AppsFlyer start failed (app continues): $e');
      await CrashReportingService.capture(
        e,
        stackTrace: st,
        context: 'appsflyer_start',
      );
    }
  }

  /// QuilloApp asks for ATT shortly after the first frame; give the user up to
  /// a minute to answer before sending the session without the IDFA.
  static Future<void> _waitForTrackingDecision() async {
    for (var i = 0; i < 60; i++) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
}
