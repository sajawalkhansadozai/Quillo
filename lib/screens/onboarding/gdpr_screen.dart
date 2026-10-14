import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/appsflyer_service.dart';
import '../../theme/app_theme.dart';
import 'splash_screen.dart';

class GdprScreen extends StatefulWidget {
  const GdprScreen({super.key});

  @override
  State<GdprScreen> createState() => _GdprScreenState();
}

class _GdprScreenState extends State<GdprScreen>
    with SingleTickerProviderStateMixin {
  bool _analyticsConsent = true;
  bool _personalisedConsent = true;
  bool _isLoading = false;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gdpr_shown', true);
    await prefs.setBool('gdpr_analytics', _analyticsConsent);
    await prefs.setBool('gdpr_personalised', _personalisedConsent);
    await prefs.setString('gdpr_accepted_at', DateTime.now().toIso8601String());
    unawaited(AppsFlyerService.onConsentChanged());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  Future<void> _decline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gdpr_shown', true);
    await prefs.setBool('gdpr_analytics', false);
    await prefs.setBool('gdpr_personalised', false);
    unawaited(AppsFlyerService.onConsentChanged());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: ConstrainedBox(
                // Keep readable width on iPad; full width on phones.
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child:
                                    Text('🔒', style: TextStyle(fontSize: 28)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Your Privacy\nMatters',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                                fontFamily: 'Nunito',
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Before you start cooking with Quillo, we need your permission to collect certain data. You can change these at any time in Settings.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMedium,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _ConsentTile(
                              icon: '📊',
                              title: 'Analytics & Improvement',
                              description:
                                  'Help us improve Quillo by sharing anonymous usage data. No personal information is included.',
                              value: _analyticsConsent,
                              onChanged: (v) =>
                                  setState(() => _analyticsConsent = v),
                            ),
                            const SizedBox(height: 14),
                            _ConsentTile(
                              icon: '🎯',
                              title: 'Personalised Experience',
                              description:
                                  'Allow Quillo to use your preferences and cooking history to personalise recipe suggestions.',
                              value: _personalisedConsent,
                              onChanged: (v) =>
                                  setState(() => _personalisedConsent = v),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Text('ℹ️',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Quillo always processes your receipt scans to provide recipes. This is essential and cannot be disabled.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Always-visible actions (fixes iPad clipping).
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          28, 8, 28, bottomInset > 0 ? 8 : 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoading
                              ? Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  ),
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton(
                                    onPressed: _accept,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Accept & Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading ? null : _decline,
                            child: Text(
                              'Decline optional data collection',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textLight,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConsentTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.chipBorder,
          width: value ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
