import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/create_account_screen.dart';

class HouseholdSizeScreen extends StatefulWidget {
  const HouseholdSizeScreen({super.key});

  @override
  State<HouseholdSizeScreen> createState() => _HouseholdSizeScreenState();
}

class _HouseholdSizeScreenState extends State<HouseholdSizeScreen>
    with SingleTickerProviderStateMixin {
  int _selected = 2;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _sizes = [
    _SizeOption(count: 1, emoji: '🧍', label: 'Just me'),
    _SizeOption(count: 2, emoji: '👫', label: 'Two of us'),
    _SizeOption(count: 3, emoji: '👨‍👩‍👦', label: 'Small family'),
    _SizeOption(count: 4, emoji: '👨‍👩‍👧‍👦', label: 'Family of 4'),
    _SizeOption(count: 5, emoji: '🏠', label: 'Bigger family'),
    _SizeOption(count: 6, emoji: '🏘️', label: 'Large family'),
    _SizeOption(count: 7, emoji: '🎉', label: 'Big household'),
    _SizeOption(count: 8, emoji: '🏟️', label: '8 or more'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('onboarding_household_size', _selected);
    if (AuthService.isSignedIn) {
      await AuthService.saveUserProfile(householdSize: _selected);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress + skip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StepDots(total: 5, current: 4),
                      GestureDetector(
                        onTap: _skip,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Header
                  const Text(
                    'How many people\ndo you cook for?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      fontFamily: 'Nunito',
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll adjust recipe servings to match your household.",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Size grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _sizes.length,
                      itemBuilder: (_, i) {
                        final size = _sizes[i];
                        final isSelected = _selected == size.count;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = size.count),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.chipBorder,
                                width: isSelected ? 0 : 1,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                else
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(size.emoji,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 4),
                                Text(
                                  size.count == 8
                                      ? '8+'
                                      : '${size.count} ${size.count == 1 ? 'person' : 'people'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  size.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Continue button
                  GestureDetector(
                    onTap: _continue,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cooking for $_selected${_selected == 8 ? '+' : ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeOption {
  final int count;
  final String emoji;
  final String label;
  const _SizeOption({required this.count, required this.emoji, required this.label});
}

class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 5),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.chipBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
