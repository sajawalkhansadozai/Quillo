import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quillo_button.dart';
import '../auth/create_account_screen.dart';

class SkillLevelScreen extends StatefulWidget {
  const SkillLevelScreen({super.key});

  @override
  State<SkillLevelScreen> createState() => _SkillLevelScreenState();
}

class _SkillLevelScreenState extends State<SkillLevelScreen>
    with SingleTickerProviderStateMixin {
  String _selected = 'Home Cook';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<_SkillOption> _options = const [
    _SkillOption(
      title: 'Beginner',
      subtitle: 'Simple recipes, basic techniques. I\'m just getting started',
      emoji: '🥚',
      color: AppColors.beginnerColor,
    ),
    _SkillOption(
      title: 'Home Cook',
      subtitle: 'Comfortable with everyday meals, learning new dishes',
      emoji: '🍳',
      color: AppColors.homeCookColor,
    ),
    _SkillOption(
      title: 'Confident Cook',
      subtitle: 'At ease with complex recipes, love to experiment',
      emoji: '🔪',
      color: AppColors.confidentColor,
    ),
    _SkillOption(
      title: 'Pro Chef',
      subtitle: 'Professional or advanced, bring on the challenge',
      emoji: '👨‍🍳',
      color: AppColors.proChefColor,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Navigator.of(context).pop()),
                    const Spacer(),
                    _StepPill(label: '✦ Step 5 of 5'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _handleContinue(),
                      child: Text('Skip',
                          style: TextStyle(fontSize: 14, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'ALMOST THERE!',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentDark,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontFamily: 'Nunito'),
                          children: [
                            TextSpan(
                              text: 'Cooking ',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                            TextSpan(
                              text: 'Skill Level',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: ' 🏆',
                              style: TextStyle(fontSize: 26),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We'll match recipes to your experience so every meal feels just right.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ..._options.asMap().entries.map((entry) {
                        final i = entry.key;
                        final option = entry.value;
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + i * 80),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SkillCard(
                              option: option,
                              isSelected: _selected == option.title,
                              onTap: () => setState(() => _selected = option.title),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  children: [
                    QuilloButton(
                      label: '✦  Let\'s Start Cooking!',
                      onTap: _handleContinue,
                      backgroundColor: AppColors.primary,
                      textColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    QuilloButton(
                      label: 'Skip for now',
                      onTap: _handleContinue,
                      backgroundColor: AppColors.textDark,
                      textColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }
}

class _SkillOption {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  const _SkillOption({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
  });
}

class _SkillCard extends StatelessWidget {
  final _SkillOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkillCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? option.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? option.color : AppColors.chipBorder,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(option.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? option.color : AppColors.textDark,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? option.color : AppColors.chipBorder,
                  width: 2,
                ),
                color: isSelected ? option.color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  const _StepPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
