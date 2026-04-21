import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_illustration.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/quillo_button.dart';
import '../../widgets/sso_button.dart';
import '../Home/main_shell.dart';
import 'create_account_screen.dart';
import 'reset_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
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
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
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
                  const AuthIllustration(type: IllustrationType.signIn),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(fontFamily: 'Nunito'),
                            children: [
                              TextSpan(
                                text: 'Welcome back ',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              TextSpan(text: '🔍', style: TextStyle(fontSize: 24)),
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
                              const TextSpan(text: 'Sign in to your QUILLO account. '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                                  ),
                                  child: const Text(
                                    'Create one?',
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
                        const _FieldLabel(label: 'EMAIL'),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _emailController,
                          hint: 'you@example.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _FieldLabel(label: 'PASSWORD'),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                              ),
                              child: const Text(
                                'Forgot?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _passwordController,
                          hint: 'Your password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 28),
                        _isLoading
                            ? _LoadingButton(color: AppColors.accent)
                            : QuilloButton(
                                label: 'Sign in',
                                onTap: _handleSignIn,
                                backgroundColor: AppColors.accent,
                                textColor: AppColors.textDark,
                              ),
                        const SizedBox(height: 20),
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
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                                fontFamily: 'Nunito',
                              ),
                              children: [
                                const TextSpan(text: "Don't have an account? "),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
                                    ),
                                    child: const Text(
                                      'Sign up free',
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
  final Color color;
  const _LoadingButton({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textDark),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text('G',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)));
  }
}
