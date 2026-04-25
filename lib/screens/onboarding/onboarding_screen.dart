import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/sign_in_screen.dart';
import 'preferences_screen.dart';

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
      titleEnd: '\nRecipe',
      subtitle: 'We turn your grocery list into\nsmart, delicious meal ideas',
      features: [
        _Feature('📋', 'Instant scan'),
        _Feature('✦', 'AI-powered'),
        _Feature('🍽️', 'Smart meals'),
      ],
      illustrationAsset: 'assets/onboarding/step1_illustration.png',
      illustrationStyle: _IllustrationStyle.scan,
      illustrationBg: Color(0xFFEDECFF),
    ),
    _OnboardingData(
      step: 'Step 2 of 5',
      title: 'Recipes in\n',
      highlight: 'Seconds',
      titleEnd: ' ✨',
      subtitle: 'Point your camera at any receipt.\nOur AI does the rest instantly',
      features: [
        _Feature('📋', 'Instant scan'),
        _Feature('✦', 'AI-powered'),
        _Feature('🍽️', 'Smart meals'),
      ],
      illustrationAsset: 'assets/onboarding/step2_illustration.png',
      illustrationStyle: _IllustrationStyle.camera,
      illustrationBg: Color(0xFFEDECFF),
    ),
    _OnboardingData(
      step: 'Step 3 of 5',
      title: 'Cook ',
      highlight: 'Smarter',
      titleEnd: '\nEvery Day',
      subtitle: 'Save time, reduce waste,\nand eat better effortlessly',
      features: [],
      stats: [
        _StatItem('🔄', '3.2', 'hrs', 'saved per week'),
        _StatItem('♻️', '42%', '', 'less food waste'),
        _StatItem('🍽️', '14+', '', 'meals per month'),
      ],
      illustrationAsset: 'assets/onboarding/step3_illustration.png',
      illustrationStyle: _IllustrationStyle.stats,
      illustrationBg: Color(0xFFFFF8DC),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // ── Illustration area ─────────────────────────────────────
              Expanded(
                flex: 52,
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

              // ── Step pill ─────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 18),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(page.step,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),

              // ── Text + actions ────────────────────────────────────────
              Expanded(
                flex: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      // Title
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w900,
                            color: AppColors.textDark, fontFamily: 'Nunito', height: 1.15,
                          ),
                          children: [
                            TextSpan(text: page.title),
                            TextSpan(text: page.highlight,
                                style: const TextStyle(color: AppColors.primary)),
                            TextSpan(text: page.titleEnd),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(page.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.6)),
                      const SizedBox(height: 16),
                      // Feature chips or stat cards
                      if (page.features.isNotEmpty)
                        Wrap(
                          spacing: 10, runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: page.features.map((f) => _FeatureChip(f)).toList(),
                        ),
                      if (page.stats.isNotEmpty)
                        Row(
                          children: page.stats
                              .map((s) => Expanded(child: _StatCard(stat: s)))
                              .toList(),
                        ),
                      const Spacer(),
                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Text(
                            isLast ? '⚡  Start Now' : 'Next  →',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
                          ),
                        ),
                      ),
                      // Sign-in link on last page
                      if (isLast) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const SignInScreen()),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: 'Already have an account?  ',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
                              children: [
                                TextSpan(text: 'Sign in',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => _StepDot(active: i == _currentPage),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Illustration area — shows asset image or fallback widget
// ─────────────────────────────────────────────────────────────────────────────

class _IllustrationArea extends StatelessWidget {
  final _OnboardingData data;
  const _IllustrationArea({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: data.illustrationBg,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Subtle blobs inside the coloured zone
          Positioned(
            top: -30, right: -40,
            child: _Blob(size: 180, color: Colors.white.withValues(alpha: 0.25)),
          ),
          Positioned(
            bottom: -20, left: -30,
            child: _Blob(size: 150, color: Colors.white.withValues(alpha: 0.18)),
          ),
          // Illustration: asset first, fallback widget if missing
          Center(
            child: Image.asset(
              data.illustrationAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _FallbackIllustration(style: data.illustrationStyle),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback Flutter-drawn illustrations (shown until real assets are provided)
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
        // Receipt card (tilted left)
        Positioned(
          top: 30, left: 20,
          child: Transform.rotate(
            angle: -0.12,
            child: _ReceiptCard(),
          ),
        ),
        // Recipe card (tilted right)
        Positioned(
          top: 55, right: 20,
          child: Transform.rotate(
            angle: 0.08,
            child: _RecipeCard(),
          ),
        ),
        // Magic circle in center
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16)],
          ),
          child: const Center(child: Text('✦', style: TextStyle(fontSize: 22, color: Colors.white))),
        ),
        // Floating food items
        const Positioned(top: 10, left: 10, child: Text('🌿', style: TextStyle(fontSize: 22))),
        const Positioned(top: 10, right: 20, child: Text('🫑', style: TextStyle(fontSize: 20))),
        const Positioned(bottom: 30, left: 15, child: Text('🍑', style: TextStyle(fontSize: 20))),
        const Positioned(bottom: 35, right: 35, child: Text('🍋', style: TextStyle(fontSize: 18))),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130, height: 155,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
            child: const Text('GROCERY RECEIPT', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 10),
          ...List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Container(height: 6, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(3))),
          )),
          Row(children: [
            Container(width: 30, height: 6, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(3))),
            const Spacer(),
            Container(width: 20, height: 6, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3))),
          ]),
        ]),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 115, height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(5)),
            child: const Text('RECIPE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 8),
          const Text('🥗🍅', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.timer_outlined, size: 11, color: AppColors.textMedium),
            const SizedBox(width: 3),
            const Text('25 min', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
          ]),
        ]),
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
      children: [
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(child: Text('📸', style: TextStyle(fontSize: 68))),
        ),
        Positioned(top: 15, right: 25,
          child: _FloatChip(color: Colors.white, emoji: '⚡')),
        Positioned(bottom: 15, left: 25,
          child: _FloatChip(color: AppColors.primaryLight, emoji: '🤖')),
      ],
    );
  }
}

class _StatsIllustration extends StatelessWidget {
  const _StatsIllustration();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('📊', style: TextStyle(fontSize: 68))),
        ),
        const Positioned(top: 10, right: 20, child: Text('⏱️', style: TextStyle(fontSize: 28))),
        const Positioned(bottom: 10, left: 20, child: Text('♻️', style: TextStyle(fontSize: 28))),
        const Positioned(top: 20, left: 20, child: Text('🥗', style: TextStyle(fontSize: 24))),
      ],
    );
  }
}

class _FloatChip extends StatelessWidget {
  final Color color;
  final String emoji;
  const _FloatChip({required this.color, required this.emoji});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 10)],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
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
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature chip
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final _Feature feature;
  const _FeatureChip(this.feature);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.chipBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(feature.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(feature.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step dot indicator
// ─────────────────────────────────────────────────────────────────────────────

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
        color: active ? AppColors.primary : AppColors.chipBorder,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card (Step 3)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _StatItem stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(stat.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: stat.value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: AppColors.textDark, fontFamily: 'Nunito'),
                ),
                if (stat.unit.isNotEmpty)
                  TextSpan(
                    text: stat.unit,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMedium, fontFamily: 'Nunito'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(stat.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight, height: 1.3)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum _IllustrationStyle { scan, camera, stats }

class _Feature {
  final String emoji;
  final String label;
  const _Feature(this.emoji, this.label);
}

class _StatItem {
  final String emoji;
  final String value;
  final String unit;
  final String label;
  const _StatItem(this.emoji, this.value, this.unit, this.label);
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
    required this.illustrationBg,
    this.stats = const [],
    this.isLast = false,
  });
}
