import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/sign_in_screen.dart';
import 'preferences_screen.dart';

const _onboardingBg = Color(0xFFF5F6FF);
const _onboardingGrey = Color(0xFF6B7280);
const _boltIconAsset = 'assets/onboarding/bolt_icon.png';

const _onboardingFeatures = [
  _Feature('assets/onboarding/feature_instant_scan.png', 'Instant scan'),
  _Feature('assets/onboarding/feature_ai_powered.png', 'AI-powered'),
  _Feature('assets/onboarding/feature_smart_meals.png', 'Smart meals'),
];

const _onboardingStats = [
  _StatItem(
    iconAsset: 'assets/onboarding/stat_time_saved.png',
    value: '3.2',
    unit: ' hrs',
    label: 'saved per week',
  ),
  _StatItem(
    iconAsset: 'assets/onboarding/stat_less_waste.png',
    value: '42%',
    unit: '',
    label: 'less food waste',
  ),
  _StatItem(
    iconAsset: 'assets/onboarding/stat_meals.png',
    value: '14+',
    unit: '',
    label: 'meals per month',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      step: 'Step 1 of 5',
      title: 'Scan & ',
      highlight: 'Discover',
      titleEnd: ' Recipe',
      subtitle:
          'We turn your grocery list into smart, delicious meal ideas',
      features: _onboardingFeatures,
      triangleFeatures: true,
      illustrationAsset: 'assets/onboarding/step1_illustration.png',
      illustrationStyle: _IllustrationStyle.scan,
      figmaIllustration: true,
    ),
    _OnboardingData(
      step: 'Step 2 of 5',
      title: 'Recipes in',
      highlight: 'Seconds',
      titleEnd: '',
      titleSparkles: true,
      subtitle:
          'Point your camera at any receipt. Quillo does the rest instantly.',
      features: _onboardingFeatures,
      triangleFeatures: true,
      illustrationAsset: 'assets/onboarding/step2_illustration.png',
      illustrationStyle: _IllustrationStyle.camera,
      figmaIllustration: true,
    ),
    _OnboardingData(
      step: 'Step 3 of 5',
      title: 'Cook ',
      highlight: 'Smarter',
      titleEnd: '\nEvery Day',
      subtitle:
          'Save time, reduce waste, and eat better effortlessly',
      features: [],
      stats: _onboardingStats,
      illustrationAsset: 'assets/onboarding/step3_illustration.png',
      illustrationStyle: _IllustrationStyle.stats,
      figmaIllustration: true,
      filledStepPill: true,
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PreferencesScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = page.isLast;

    return Scaffold(
      backgroundColor: _onboardingBg,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -70,
            child: _Blob(
              size: 200,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 80,
            right: -40,
            child: _Blob(
              size: 120,
              color: AppColors.primaryLight.withValues(alpha: 0.7),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  Expanded(
                    flex: 48,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) {
                        setState(() => _currentPage = i);
                        _animController.reset();
                        _animController.forward();
                      },
                      itemCount: _pages.length,
                      itemBuilder: (_, i) => _IllustrationArea(data: _pages[i]),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: page.filledStepPill
                          ? AppColors.primary
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '• ${page.step}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: page.filledStepPill
                            ? Colors.white
                            : AppColors.primary,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          _OnboardingTitle(data: page),
                          const SizedBox(height: 12),
                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: _onboardingGrey,
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (page.features.isNotEmpty)
                            page.triangleFeatures
                                ? _FeatureTriangle(features: page.features)
                                : Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: page.features
                                        .map((f) => _FeatureChip(f))
                                        .toList(),
                                  ),
                          if (page.stats.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                children: page.stats
                                    .map(
                                      (s) =>
                                          Expanded(child: _StatCard(stat: s)),
                                    )
                                    .toList(),
                              ),
                            ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: isLast
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          _boltIconAsset,
                                          width: 20,
                                          height: 20,
                                          color: Colors.white,
                                          colorBlendMode: BlendMode.srcIn,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Start Now',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Nunito',
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Next  →',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Nunito',
                                      ),
                                    ),
                            ),
                          ),
                          if (isLast) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const SignInScreen(),
                                ),
                              ),
                              child: RichText(
                                text: const TextSpan(
                                  text: 'Already have an account?  ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _onboardingGrey,
                                    fontFamily: 'Nunito',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Sign in',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _pages.length,
                              (i) => _StepDot(active: i == _currentPage),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Title block
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingTitle extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingTitle({required this.data});

  static const _titleStyle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: AppColors.textDark,
    fontFamily: 'Nunito',
    height: 1.15,
  );

  @override
  Widget build(BuildContext context) {
    if (data.titleSparkles) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.title, textAlign: TextAlign.center, style: _titleStyle),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                data.highlight,
                style: _titleStyle.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.auto_awesome,
                size: 22,
                color: AppColors.textDark,
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.auto_awesome,
                size: 22,
                color: AppColors.textDark,
              ),
            ],
          ),
        ],
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: _titleStyle,
        children: [
          TextSpan(text: data.title),
          TextSpan(
            text: data.highlight,
            style: const TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: data.titleEnd),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration area
// ─────────────────────────────────────────────────────────────────────────────

class _IllustrationArea extends StatelessWidget {
  final _OnboardingData data;
  const _IllustrationArea({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.figmaIllustration) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 20,
              left: 30,
              child: _Blob(
                size: 140,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 20,
              child: _Blob(
                size: 100,
                color: AppColors.primaryLight.withValues(alpha: 0.5),
              ),
            ),
            Image.asset(
              data.illustrationAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _FallbackIllustration(style: data.illustrationStyle),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: data.illustrationBg,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -40,
            child: _Blob(
              size: 180,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: _Blob(
              size: 150,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          Center(
            child: Image.asset(
              data.illustrationAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _FallbackIllustration(style: data.illustrationStyle),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature chips — Figma triangle layout (step 1)
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureTriangle extends StatelessWidget {
  final List<_Feature> features;
  const _FeatureTriangle({required this.features});

  @override
  Widget build(BuildContext context) {
    if (features.length < 3) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: features.map((f) => _FeatureChip(f)).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Center(child: _FeatureChip(features[0]))),
            const SizedBox(width: 12),
            Expanded(child: Center(child: _FeatureChip(features[1]))),
          ],
        ),
        const SizedBox(height: 12),
        Center(child: _FeatureChip(features[2])),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final _Feature feature;
  const _FeatureChip(this.feature);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            feature.iconAsset,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            feature.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback illustrations
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackIllustration extends StatelessWidget {
  final _IllustrationStyle style;
  const _FallbackIllustration({required this.style});

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case _IllustrationStyle.scan:
        return const _ScanIllustration();
      case _IllustrationStyle.camera:
        return const _CameraIllustration();
      case _IllustrationStyle.stats:
        return const _StatsIllustration();
    }
  }
}

class _ScanIllustration extends StatelessWidget {
  const _ScanIllustration();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 30,
          left: 20,
          child: Transform.rotate(
            angle: -0.12,
            child: const _ReceiptCard(),
          ),
        ),
        Positioned(
          top: 55,
          right: 20,
          child: Transform.rotate(
            angle: 0.08,
            child: const _RecipeCard(),
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20),
              Text(
                'Quillo MAGIC',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          top: 10,
          left: 10,
          child: Text('🌿', style: TextStyle(fontSize: 22)),
        ),
        const Positioned(
          top: 10,
          right: 20,
          child: Text('🫑', style: TextStyle(fontSize: 20)),
        ),
        const Positioned(
          bottom: 30,
          left: 15,
          child: Text('🧅', style: TextStyle(fontSize: 20)),
        ),
        const Positioned(
          bottom: 35,
          right: 35,
          child: Text('🍋', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 155,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'GROCERY RECEIPT',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 115,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'RECIPE',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('🥗🍅', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.timer_outlined, size: 11, color: AppColors.textMedium),
                SizedBox(width: 3),
                Text(
                  '25 min',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraIllustration extends StatelessWidget {
  const _CameraIllustration();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Phone frame
        Container(
          width: 150,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.chipBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECIPE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('🥗', style: TextStyle(fontSize: 32)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          top: 20,
          left: 0,
          child: _StatFloatCard(
            title: 'TIME SAVED',
            value: '3.2 hrs',
            subtitle: 'per week',
            emoji: '⏰',
          ),
        ),
        const Positioned(
          top: 40,
          right: 0,
          child: _StatFloatCard(
            title: 'MEALS PLANNED',
            value: '14+',
            subtitle: 'this month',
            emoji: '🍽️',
          ),
        ),
        const Positioned(top: 0, left: 50, child: Text('🌽', style: TextStyle(fontSize: 22))),
        const Positioned(bottom: 20, left: 30, child: Text('🥑', style: TextStyle(fontSize: 22))),
        const Positioned(top: 10, right: 40, child: Text('🍓', style: TextStyle(fontSize: 20))),
        const Positioned(bottom: 30, right: 25, child: Text('🫐', style: TextStyle(fontSize: 20))),
      ],
    );
  }
}

class _StatFloatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String emoji;
  final Color tint;
  const _StatFloatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.emoji,
    this.tint = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}

class _StatsIllustration extends StatelessWidget {
  const _StatsIllustration();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 148,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.chipBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECIPE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('🥗', style: TextStyle(fontSize: 28)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          top: 8,
          left: 4,
          child: _StatFloatCard(
            title: 'TIME SAVED',
            value: '3.2 hrs',
            subtitle: 'per week',
            emoji: '⏰',
            tint: Color(0xFFE3F2FD),
          ),
        ),
        const Positioned(
          bottom: 24,
          left: 0,
          child: _StatFloatCard(
            title: 'LESS WASTE',
            value: '42%',
            subtitle: 'food saved',
            emoji: '♻️',
            tint: Color(0xFFE8F5E9),
          ),
        ),
        const Positioned(
          top: 28,
          right: 0,
          child: _StatFloatCard(
            title: 'MEALS PLANNED',
            value: '14+',
            subtitle: 'this month',
            emoji: '🍽️',
            tint: Color(0xFFEDE7F6),
          ),
        ),
        const Positioned(
          bottom: 8,
          right: 8,
          child: _StatFloatCard(
            title: 'CALORIES',
            value: '1840',
            subtitle: 'avg / day',
            emoji: '💪',
            tint: Color(0xFFFCE4EC),
          ),
        ),
        const Positioned(top: 0, left: 55, child: Text('🌽', style: TextStyle(fontSize: 20))),
        const Positioned(top: 16, right: 50, child: Text('🍓', style: TextStyle(fontSize: 18))),
        const Positioned(bottom: 50, left: 40, child: Text('🥑', style: TextStyle(fontSize: 20))),
        const Positioned(bottom: 40, right: 45, child: Text('🫐', style: TextStyle(fontSize: 18))),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  const _StepDot({required this.active});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stat.iconAsset != null)
            Image.asset(
              stat.iconAsset!,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            )
          else if (stat.icon != null)
            Icon(stat.icon, size: 24, color: AppColors.textDark),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: stat.value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
                if (stat.unit.isNotEmpty)
                  TextSpan(
                    text: stat.unit,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      fontFamily: 'Nunito',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: _onboardingGrey,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum _IllustrationStyle { scan, camera, stats }

class _Feature {
  final String iconAsset;
  final String label;
  const _Feature(this.iconAsset, this.label);
}

class _StatItem {
  final String? iconAsset;
  final IconData? icon;
  final String value;
  final String unit;
  final String label;

  const _StatItem({
    this.iconAsset,
    this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });
}

class _OnboardingData {
  final String step;
  final String title;
  final String highlight;
  final String titleEnd;
  final String subtitle;
  final List<_Feature> features;
  final List<_StatItem> stats;
  final String illustrationAsset;
  final _IllustrationStyle illustrationStyle;
  final Color illustrationBg;
  final bool triangleFeatures;
  final bool figmaIllustration;
  final bool titleSparkles;
  final bool filledStepPill;
  final bool isLast;

  const _OnboardingData({
    required this.step,
    required this.title,
    required this.highlight,
    required this.titleEnd,
    required this.subtitle,
    required this.features,
    required this.illustrationAsset,
    required this.illustrationStyle,
    this.stats = const [],
    this.illustrationBg = _onboardingBg,
    this.triangleFeatures = false,
    this.figmaIllustration = false,
    this.titleSparkles = false,
    this.filledStepPill = false,
    this.isLast = false,
  });
}
