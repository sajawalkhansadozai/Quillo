import 'package:flutter/material.dart';
import 'package:quillo/screens/auth/sign_in_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/quillo_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/sso_button.dart';
import '../widgets/auth_illustration.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AllSetScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Illustration header
                  const AuthIllustration(type: IllustrationType.createAccount),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        // Title
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(fontFamily: 'Nunito'),
                            children: [
                              TextSpan(
                                text: 'Create account ',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              TextSpan(text: '👋', style: TextStyle(fontSize: 24)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                              fontFamily: 'Nunito',
                            ),
                            children: [
                              const TextSpan(text: 'Join QUILLO already cooking? '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                                  ),
                                  child: const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Nunito',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email
                        const _FieldLabel(label: 'EMAIL'),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _emailController,
                          hint: 'you@example.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        const _FieldLabel(label: 'PASSWORD'),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _passwordController,
                          hint: 'Min. 8 characters',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 16),

                        // Confirm password
                        const _FieldLabel(label: 'CONFIRM PASSWORD'),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _confirmController,
                          hint: 'Repeat your password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          suffixIcon: _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        const SizedBox(height: 28),

                        // Create button
                        _isLoading
                            ? const _LoadingButton()
                            : QuilloButton(
                                label: 'Create Account',
                                onTap: _handleCreate,
                                backgroundColor: AppColors.accent,
                                textColor: AppColors.textDark,
                              ),
                        const SizedBox(height: 20),

                        // Or continue with
                        const _OrDivider(),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: SsoButton(
                                label: 'Google',
                                icon: _GoogleIcon(),
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SsoButton(
                                label: 'Apple',
                                icon: const Icon(Icons.apple, size: 20, color: AppColors.textDark),
                                onTap: () {},
                                dark: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Terms
                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                                fontFamily: 'Nunito',
                              ),
                              children: [
                                const TextSpan(text: 'By signing up you agree to our '),
                                TextSpan(
                                  text: 'Terms',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: ' &\n'),
                                TextSpan(
                                  text: 'Conditions',
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
                      ],
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMedium,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.chipBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ),
        Expanded(child: Divider(color: AppColors.chipBorder, thickness: 1)),
      ],
    );
  }
}

class _LoadingButton extends StatelessWidget {
  const _LoadingButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text('G', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)));
  }
}

// ─── All Set screen (success) ───────────────────────────────────────────────

class AllSetScreen extends StatefulWidget {
  const AllSetScreen({super.key});

  @override
  State<AllSetScreen> createState() => _AllSetScreenState();
}

class _AllSetScreenState extends State<AllSetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Illustration
              const AuthIllustration(type: IllustrationType.allSet),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50), size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "You're all set!",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your QUILLO account is ready\nTime to turn receipts into delicious meals.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMedium,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 36),
                      QuilloButton(
                        label: 'Go to Home',
                        onTap: () {},
                        backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                      ),
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
