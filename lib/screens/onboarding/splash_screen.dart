import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/sign_in_screen.dart';
import 'onboarding_screen.dart';

// Figma splash tokens
const _splashBg = Color(0xFFF5F6FF);
const _splashYellow = Color(0xFFFFCC00);
const _splashGrey = Color(0xFF6B7280);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: Stack(
        children: [
          // Figma background blobs
          Positioned(
            top: -70,
            left: -90,
            child: _DecorCircle(
              color: AppColors.primary.withValues(alpha: 0.10),
              size: 240,
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: _DecorCircle(
              color: _splashYellow.withValues(alpha: 0.22),
              size: 180,
            ),
          ),
          Positioned(
            top: 120,
            right: -30,
            child: _DecorCircle(
              color: AppColors.primaryLight.withValues(alpha: 0.55),
              size: 90,
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        height: 280,
                        width: double.infinity,
                        child: Image.asset(
                          'assets/onboarding/chef_illustration.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const _ChefIllustrationFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // White pill — yellow dot + QUILLO (Figma)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: _splashYellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'QUILLO',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 1.4,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Happy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        height: 1.05,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Cooking',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            height: 1.05,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset(
                          'assets/onboarding/chef_icon.png',
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Turn your receipts into\ndelicious meals with AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _splashGrey,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const Spacer(flex: 3),
                    _GetStartedButton(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnboardingScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: _splashGrey,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) => _Dot(active: i == 0)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GetStartedButton({required this.onTap});

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) {
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _controller,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _splashYellow,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _splashYellow.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: AppColors.textDark),
              SizedBox(width: 8),
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

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

class _DecorCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _DecorCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ChefIllustrationFallback extends StatelessWidget {
  const _ChefIllustrationFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 20,
          left: 20,
          child: _DecorCircle(
            color: _splashYellow.withValues(alpha: 0.25),
            size: 90,
          ),
        ),
        Positioned(
          bottom: 30,
          right: 10,
          child: _DecorCircle(
            color: AppColors.primary.withValues(alpha: 0.12),
            size: 70,
          ),
        ),
        const Positioned(
          top: 10,
          right: 30,
          child: Text('🥕', style: TextStyle(fontSize: 28)),
        ),
        const Positioned(
          top: 40,
          left: 10,
          child: Text('🍅', style: TextStyle(fontSize: 22)),
        ),
        const Positioned(
          bottom: 40,
          left: 30,
          child: Text('🥦', style: TextStyle(fontSize: 24)),
        ),
        const Positioned(
          bottom: 10,
          right: 50,
          child: Text('🧄', style: TextStyle(fontSize: 20)),
        ),
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              'assets/onboarding/chef_icon.png',
              height: 72,
              width: 72,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
