import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/onboarding/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
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
      home: const SplashScreen(),
    );
  }
}
