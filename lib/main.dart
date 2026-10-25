import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'navigation/app_navigator.dart';
import 'screens/onboarding/gdpr_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/appsflyer_service.dart';
import 'services/crash_reporting_service.dart';
import 'services/push_notification_service.dart';
import 'services/quick_actions_service.dart';
import 'services/deep_link_service.dart';
import 'services/onboarding_router.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';
import 'widgets/offline_banner.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 2.8 — third-party SDKs must never block or crash launch.
  await CrashReportingService.initialise();
  await AnalyticsService.initialise();
  await PushNotificationService.initialise();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e, st) {
    await CrashReportingService.capture(e, stackTrace: st, context: 'supabase_init');
  }

  try {
    await AdService.initialise();
  } catch (e, st) {
    await CrashReportingService.capture(e, stackTrace: st, context: 'admob_init');
  }

  try {
    await SubscriptionService.configure();
    await SubscriptionService.syncOnLaunch();
  } catch (e, st) {
    await CrashReportingService.capture(e, stackTrace: st, context: 'revenuecat_init');
  }

  try {
    await DeepLinkService.initialise();
  } catch (e, st) {
    await CrashReportingService.capture(e, stackTrace: st, context: 'deeplink_init');
  }

  try {
    await AdService.startAdsIfFree();
  } catch (e, st) {
    await CrashReportingService.capture(e, stackTrace: st, context: 'ads_start');
  }

  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      await AnalyticsService.identify(uid);
      await PushNotificationService.login(uid);
    }
  } catch (_) {}

  runApp(const QuilloApp());

  // Attribution never blocks or throws into startup (2.8).
  unawaited(AppsFlyerService.initialise());
}

class QuilloApp extends StatefulWidget {
  const QuilloApp({super.key});

  @override
  State<QuilloApp> createState() => _QuilloAppState();
}

class _QuilloAppState extends State<QuilloApp> with WidgetsBindingObserver {
  bool _trackingRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      QuickActionsService.initialize();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestTrackingPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Another system alert (e.g. the push permission prompt) makes the app
  /// inactive; answering it resumes the app, which is when ATT can show.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) requestTrackingPermission();
  }

  /// iOS silently drops the ATT request while another system alert is on
  /// screen, leaving the status notDetermined. So only ask while the app is
  /// active, and retry until the user has actually answered.
  Future<void> requestTrackingPermission() async {
    if (_trackingRequestInFlight) return;
    _trackingRequestInFlight = true;
    try {
      for (var attempt = 0; attempt < 20; attempt++) {
        // Wait until the UI is ready (critical for iPadOS).
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;

        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status != TrackingStatus.notDetermined) return;

        // Inactive means a system alert is showing; resume will call us again.
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        if (result != TrackingStatus.notDetermined) return;
      }
    } catch (e) {
      debugPrint('ATT request failed (app continues): $e');
    } finally {
      _trackingRequestInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Quillo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: OfflineBanner(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Widget? _destination;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _resolve();
    // Email confirm / OAuth deep links establish a session after cold start.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (!mounted || data.session == null) return;
      final dest = _destination;
      // Only take over pre-auth roots. Auth screens handle their own navigation.
      if (dest == null || dest is SplashScreen || dest is GdprScreen) {
        final next = await OnboardingRouter.destinationAfterAuth();
        if (!mounted) return;
        setState(() => _destination = next);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _resolve() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final next = await OnboardingRouter.destinationAfterAuth();
        if (!mounted) return;
        setState(() => _destination = next);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final gdprShown = prefs.getBool('gdpr_shown') ?? false;

      setState(() {
        _destination = gdprShown ? const SplashScreen() : const GdprScreen();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _destination = const SplashScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F9FF),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    return _destination!;
  }
}
