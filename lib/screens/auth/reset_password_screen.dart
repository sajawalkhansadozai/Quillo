import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_illustration.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/quillo_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _sent = true;
      });
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: AppColors.textDark),
                        const SizedBox(width: 6),
                        Text(
                          'Back to sign in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const AuthIllustration(type: IllustrationType.resetPassword),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(fontFamily: 'Nunito'),
                            children: [
                              TextSpan(
                                text: 'Reset password ',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                ),
                              ),
                              TextSpan(text: '🔑', style: TextStyle(fontSize: 24)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter your email and we'll send a magic link to reset your password.",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _FieldLabel(label: 'EMAIL ADDRESS'),
                        const SizedBox(height: 8),
                        AuthTextField(
                          controller: _emailController,
                          hint: 'you@example.com',
                          prefixIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 24),
                        if (_sent)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF4CAF50), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Reset link sent! Check your inbox.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: const Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _isLoading
                            ? _LoadingButton()
                            : QuilloButton(
                                label: _sent ? '✓ Link Sent!' : 'Send Reset Link',
                                onTap: _sent ? () {} : _handleSend,
                                backgroundColor:
                                    _sent ? const Color(0xFF4CAF50) : AppColors.accent,
                                textColor: _sent ? Colors.white : AppColors.textDark,
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
                                const TextSpan(text: 'Remembered it? '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

class _LoadingButton extends StatelessWidget {
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
          child:
              CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.textDark),
        ),
      ),
    );
  }
}
