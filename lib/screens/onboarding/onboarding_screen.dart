import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quillo_button.dart';
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
  late Animation<Offset> _slideAnimation;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      step: 'Step 1 of 5',
      title: 'Scan &\nDiscover\nRecipe',
      titleHighlight: 'Discover',
      subtitle: 'We turn your grocery list into smart, delicious meal ideas',
      features: ['Instant scan', 'AI-powered', 'Smart meals', ''],
      emoji: '🛒',
      illustration: _IllustrationStyle.scan,
    ),
    _OnboardingData(
      step: 'Step 2 of 5',
      title: 'Recipes in\nSeconds ⚡',
      titleHighlight: '',
      subtitle: 'Point your camera at any receipt. Our AI does the rest instantly',
      features: ['Instant scan', 'AI-powered', 'Smart meals', ''],
      emoji: '📸',
      illustration: _IllustrationStyle.camera,
    ),
    _OnboardingData(
      step: 'Step 3 of 5',
      title: 'Cook Smarter\nEvery Day',
      titleHighlight: 'Smarter',
      subtitle: 'Save time, reduce waste, and eat better effortlessly',
      features: [],
      emoji: '📊',
      illustration: _IllustrationStyle.stats,
      stats: [
        _StatItem(value: '3.2', unit: 'hrs', label: 'saved'),
        _StatItem(value: '42%', unit: '', label: 'waste reduction'),
        _StatItem(value: '14+', unit: '', label: 'recipes'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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
        duration: const Duration(milliseconds: 350),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.textDark),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _pages[_currentPage].step,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const PreferencesScreen()),
                      );
                    },
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _animController.reset();
                  _animController.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return SlideTransition(
                    position: _slideAnimation,
                    child: _OnboardingPage(data: _pages[index]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => _StepDot(active: i == _currentPage),
                    ),
                  ),
                  const SizedBox(height: 20),
                  QuilloButton(
                    label: 'Next →',
                    onTap: _nextPage,
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        color: active ? AppColors.primary : AppColors.chipBorder,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

enum _IllustrationStyle { scan, camera, stats }

class _StatItem {
  final String value;
  final String unit;
  final String label;
  const _StatItem({required this.value, required this.unit, required this.label});
}

class _OnboardingData {
  final String step;
  final String title;
  final String titleHighlight;
  final String subtitle;
  final List<String> features;
  final String emoji;
  final _IllustrationStyle illustration;
  final List<_StatItem> stats;

  const _OnboardingData({
    required this.step,
    required this.title,
    required this.titleHighlight,
    required this.subtitle,
    required this.features,
    required this.emoji,
    required this.illustration,
    this.stats = const [],
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              height: 220,
              child: _buildIllustration(),
            ),
          ),
          const SizedBox(height: 28),
          _buildTitle(),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          if (data.features.isNotEmpty)
            _FeatureChips(features: data.features.where((f) => f.isNotEmpty).toList()),
          if (data.stats.isNotEmpty) _StatsRow(stats: data.stats),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    if (data.titleHighlight.isEmpty) {
      return Text(
        data.title,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.textDark,
          height: 1.15,
          fontFamily: 'Nunito',
        ),
      );
    }
    final parts = data.title.split(data.titleHighlight);
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.textDark,
          height: 1.15,
          fontFamily: 'Nunito',
        ),
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: data.titleHighlight,
            style: const TextStyle(color: AppColors.primary),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    switch (data.illustration) {
      case _IllustrationStyle.scan:
        return const _ScanIllustration();
      case _IllustrationStyle.camera:
        return const _CameraIllustration();
      case _IllustrationStyle.stats:
        return const _StatsIllustration();
    }
  }
}

class _FeatureChips extends StatelessWidget {
  final List<String> features;
  const _FeatureChips({required this.features});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: features.map((f) => _FeatureChip(label: f)).toList(),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.chipBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatItem> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.map((s) => Expanded(child: _StatCard(stat: s))).toList(),
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: stat.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
                if (stat.unit.isNotEmpty)
                  TextSpan(
                    text: stat.unit,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                      fontFamily: 'Nunito',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
          top: 10,
          left: 20,
          child: _IllustCard(
            color: AppColors.accent.withValues(alpha: 0.15),
            child: const Text('🛒', style: TextStyle(fontSize: 32)),
          ),
        ),
        Positioned(
          top: 30,
          right: 10,
          child: _IllustCard(
            color: AppColors.primary.withValues(alpha: 0.1),
            child: const Text('📋', style: TextStyle(fontSize: 28)),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 30,
          child: _IllustCard(
            color: AppColors.green.withValues(alpha: 0.1),
            child: const Text('✅', style: TextStyle(fontSize: 24)),
          ),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🍽️', style: TextStyle(fontSize: 52)),
          ),
        ),
      ],
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
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(child: Text('📸', style: TextStyle(fontSize: 64))),
        ),
        Positioned(
          top: 10,
          right: 20,
          child: _IllustCard(
            color: Colors.white,
            child: const Text('⚡', style: TextStyle(fontSize: 20)),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 20,
          child: _IllustCard(
            color: AppColors.primary.withValues(alpha: 0.1),
            child: const Text('🤖', style: TextStyle(fontSize: 20)),
          ),
        ),
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
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(child: Text('📊', style: TextStyle(fontSize: 64))),
        ),
        const Positioned(
            top: 5, right: 15, child: Text('⏱️', style: TextStyle(fontSize: 28))),
        const Positioned(
            bottom: 5,
            left: 15,
            child: Text('♻️', style: TextStyle(fontSize: 28))),
        const Positioned(
            top: 15, left: 15, child: Text('🥗', style: TextStyle(fontSize: 22))),
      ],
    );
  }
}

class _IllustCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const _IllustCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}
