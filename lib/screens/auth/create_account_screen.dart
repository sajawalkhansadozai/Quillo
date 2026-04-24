import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_illustration.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/quillo_button.dart';
import '../../widgets/sso_button.dart';
import '../../services/auth_service.dart';
import '../Home/main_shell.dart';
import 'sign_in_screen.dart';

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
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    setState(() => _isLoading = true);
    final result = await AuthService.signUp(email: email, password: password);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.needsEmailVerification) {
      await saveOnboardingDataToDb();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AllSetScreen()),
      );
    } else if (result.success) {
      await saveOnboardingDataToDb();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AllSetScreen()),
      );
    } else {
      _showError(result.error ?? 'Sign up failed.');
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      await saveOnboardingDataToDb();
      if (!mounted) return;
      _goHome();
    } else if (result.error != null && !result.error!.contains('cancelled')) {
      _showError(result.error!);
    }
  }

  Future<void> _handleApple() async {
    setState(() => _isLoading = true);
    final result = await AuthService.signInWithApple();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      await saveOnboardingDataToDb();
      if (!mounted) return;
      _goHome();
    } else if (result.error != null && !result.error!.contains('cancelled')) {
      _showError(result.error!);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  /// Reads onboarding selections from SharedPreferences and persists them
  /// to the Supabase users + user_preferences tables.
  static Future<void> saveOnboardingDataToDb() async {
    final prefs = await SharedPreferences.getInstance();
    final gdprConsent = prefs.getBool('gdpr_analytics') ?? false;
    final householdSize = prefs.getInt('onboarding_household_size') ?? 2;
    final dietary = prefs.getStringList('onboarding_dietary') ?? [];
    final cuisines = prefs.getStringList('onboarding_cuisines') ?? [];
    final email = AuthService.currentUser?.email ?? '';

    await AuthService.initUserProfile(
      email: email,
      gdprConsent: gdprConsent,
      householdSize: householdSize,
      preferredCuisines: cuisines,
    );
    if (dietary.isNotEmpty) {
      await AuthService.saveUserPreferences(dietaryLabels: dietary);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
                  const AuthIllustration(type: IllustrationType.createAccount),
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
                        const _FieldLabel(label: 'EMAIL'),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _emailController,
                          hint: 'you@example.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
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
                        _isLoading
                            ? const _LoadingButton()
                            : QuilloButton(
                                label: 'Create Account',
                                onTap: _handleCreate,
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
                                onTap: _handleGoogle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SsoButton(
                                label: 'Apple',
                                icon: const Icon(Icons.apple, size: 20, color: AppColors.textDark),
                                onTap: _handleApple,
                                dark: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
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
        color: AppColors.accent.withValues(alpha: 0.7),
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
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
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
                        onTap: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MainShell()),
                          (_) => false,
                        ),
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
