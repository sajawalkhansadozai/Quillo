import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/Home/main_shell.dart';
import 'screens/onboarding/gdpr_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'services/ad_service.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialise AdMob SDK
  await AdService.initialise();

  // Configure RevenueCat (non-fatal — only works after real API keys are set)
  try {
    await SubscriptionService.configure();
    await SubscriptionService.syncOnLaunch();
  } catch (_) {}

  runApp(const QuilloApp());
}

class QuilloApp extends StatelessWidget {
  const QuilloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quillo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate
// Decides first screen based on:
//  1. Active Supabase session  → MainShell (skip all onboarding)
//  2. GDPR not yet accepted    → GdprScreen (first-ever launch)
//  3. Otherwise                → SplashScreen (normal onboarding)
// ─────────────────────────────────────────────────────────────────────────────

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    // Already signed in → go straight to home
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      setState(() => _destination = const MainShell());
      return;
    }

    // Check if GDPR was already shown
    final prefs = await SharedPreferences.getInstance();
    final gdprShown = prefs.getBool('gdpr_shown') ?? false;

    setState(() {
      _destination = gdprShown ? const SplashScreen() : const GdprScreen();
    });
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
