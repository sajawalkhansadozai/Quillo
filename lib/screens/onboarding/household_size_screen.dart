import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/onboarding_router.dart';
import '../auth/create_account_screen.dart';
import '../Home/main_shell.dart';

class HouseholdSizeScreen extends StatefulWidget {
  const HouseholdSizeScreen({super.key});

  @override
  State<HouseholdSizeScreen> createState() => _HouseholdSizeScreenState();
}

class _HouseholdSizeScreenState extends State<HouseholdSizeScreen>
    with SingleTickerProviderStateMixin {
  int _selected = 2;
  int _maxCookTime = 45;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final _sizes = const [
    _SizeOption(count: 1, icon: Icons.person_outline, label: 'Just me'),
    _SizeOption(count: 2, icon: Icons.people_outline, label: 'Two of us'),
    _SizeOption(count: 3, icon: Icons.family_restroom_outlined, label: 'Small family'),
    _SizeOption(count: 4, icon: Icons.groups_outlined, label: 'Family of 4'),
    _SizeOption(count: 5, icon: Icons.home_outlined, label: 'Bigger family'),
    _SizeOption(count: 6, icon: Icons.apartment_outlined, label: 'Large family'),
    _SizeOption(count: 7, icon: Icons.celebration_outlined, label: 'Big household'),
    _SizeOption(count: 8, icon: Icons.groups_3_outlined, label: '8 or more'),
  ];

  static const _cookTimes = [15, 20, 30, 45, 60];

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
    await prefs.setInt('onboarding_max_cook_time', _maxCookTime);

    // Already signed in (Google/Apple recovery or late onboarding) → finish here.
    if (AuthService.isSignedIn) {
      await AuthService.completeOnboardingFromLocalPrefs();
      await OnboardingRouter.clearLocalOnboardingPrefs();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
      return;
    }

    // Prefs collected for the account about to be created/confirmed.
    await OnboardingRouter.markPendingSave();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
    );
  }

  void _skip() {
    // Skipping must not mark onboarding complete (§2.4).
    if (AuthService.isSignedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
      return;
    }
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
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
                  const SizedBox(height: 20),

                  // Header (scrolls with grid if short)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 500;
                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                            SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: wide ? 4 : 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: wide ? 1.35 : 1.6,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) {
                                  final size = _sizes[i];
                                  final isSelected = _selected == size.count;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selected = size.count),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
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
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            size.icon,
                                            size: 28,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.primary,
                                          ),
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
                                                  ? Colors.white
                                                      .withValues(alpha: 0.8)
                                                  : AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                childCount: _sizes.length,
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 12)),
                          ],
                        );
                      },
                    ),
                  ),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Max cook time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Never show recipes longer than this.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cookTimes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final t = _cookTimes[i];
                        final sel = t == _maxCookTime;
                        return GestureDetector(
                          onTap: () => setState(() => _maxCookTime = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.chipBorder,
                              ),
                            ),
                            child: Text(
                              '$t min',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.textDark,
                              ),
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
        ),
      ),
    );
  }
}

class _SizeOption {
  final int count;
  final IconData icon;
  final String label;
  const _SizeOption({
    required this.count,
    required this.icon,
    required this.label,
  });
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
