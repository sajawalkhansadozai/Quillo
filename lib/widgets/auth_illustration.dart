import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum IllustrationType { createAccount, signIn, resetPassword, allSet }

class AuthIllustration extends StatelessWidget {
  final IllustrationType type;

  const AuthIllustration({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == IllustrationType.signIn) {
      return _buildSignInHeader();
    }
    if (type == IllustrationType.createAccount) {
      return _buildCreateAccountHeader();
    }
    if (type == IllustrationType.resetPassword) {
      return _buildResetPasswordHeader();
    }
    return _buildFallback();
  }

  Widget _buildSignInHeader() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -24,
            left: -36,
            child: _Blob(
              color: const Color(0xFFB3E5FC).withValues(alpha: 0.55),
              size: 170,
            ),
          ),
          Positioned(
            top: -16,
            left: 40,
            child: _Blob(
              color: AppColors.primary.withValues(alpha: 0.12),
              size: 140,
            ),
          ),
          Positioned(
            top: -8,
            right: -28,
            child: _Blob(
              color: AppColors.accent.withValues(alpha: 0.38),
              size: 110,
            ),
          ),
          const Positioned(
            top: 8,
            left: 18,
            child: _FoodDeco(
              asset: 'assets/onboarding/signin_deco_garlic.png',
              size: 44,
            ),
          ),
          const Positioned(
            top: 4,
            right: 18,
            child: _FoodDeco(
              asset: 'assets/onboarding/signin_deco_broccoli.png',
              size: 48,
            ),
          ),
          const Positioned(
            top: 72,
            right: 12,
            child: _FoodDeco(
              asset: 'assets/onboarding/signin_deco_tomato.png',
              size: 40,
            ),
          ),
          Image.asset(
            'assets/onboarding/signin_pan.png',
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/onboarding/signin_illustration.png',
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordHeader() {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -18,
            left: -32,
            child: _Blob(
              color: AppColors.primary.withValues(alpha: 0.16),
              size: 150,
            ),
          ),
          Positioned(
            top: -12,
            right: -24,
            child: _Blob(
              color: AppColors.accent.withValues(alpha: 0.4),
              size: 100,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 24,
            child: _Blob(
              color: const Color(0xFFB3E5FC).withValues(alpha: 0.5),
              size: 80,
            ),
          ),
          const Positioned(
            top: 4,
            right: 20,
            child: _FoodDeco(
              asset: 'assets/onboarding/deco_lemon.png',
              size: 48,
            ),
          ),
          Image.asset(
            'assets/onboarding/reset_email_header.png',
            height: 110,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Text(_getCenterEmoji(), style: const TextStyle(fontSize: 44)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAccountHeader() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -20,
            left: -40,
            child: _Blob(
              color: AppColors.primary.withValues(alpha: 0.14),
              size: 180,
            ),
          ),
          Positioned(
            top: -10,
            right: -30,
            child: _Blob(
              color: AppColors.accent.withValues(alpha: 0.35),
              size: 120,
            ),
          ),
          Positioned(
            bottom: 10,
            left: 20,
            child: _Blob(
              color: const Color(0xFFB3E5FC).withValues(alpha: 0.5),
              size: 90,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 30,
            child: _Blob(
              color: const Color(0xFFE8D5B0).withValues(alpha: 0.45),
              size: 70,
            ),
          ),
          const Positioned(
            top: 6,
            left: 20,
            child: _FoodDeco(
              asset: 'assets/onboarding/deco_lemon.png',
              size: 52,
            ),
          ),
          const Positioned(
            top: 44,
            left: 4,
            child: _FoodDeco(
              asset: 'assets/onboarding/deco_pepper.png',
              size: 46,
            ),
          ),
          const Positioned(
            top: 10,
            right: 16,
            child: _FoodDeco(
              asset: 'assets/onboarding/deco_mint.png',
              size: 44,
            ),
          ),
          Image.asset(
            'assets/onboarding/bowl_image.png',
            height: 130,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Text(_getCenterEmoji(), style: const TextStyle(fontSize: 44)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Large primary blob — left/centre
          Positioned(
            top: -10, left: -30,
            child: _Blob(color: AppColors.primary.withValues(alpha: 0.18), size: 200),
          ),
          // Tan/beige blob — top right
          Positioned(
            top: 0, right: -20,
            child: _Blob(color: const Color(0xFFE8D5B0).withValues(alpha: 0.55), size: 150),
          ),
          // Small green accent blob — bottom left
          Positioned(
            bottom: 0, left: 50,
            child: _Blob(color: const Color(0xFFD5EDDA).withValues(alpha: 0.7), size: 80),
          ),
          // Food/context emojis
          ..._getDecorations(),
          // Centre illustration
          Center(
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(_getCenterEmoji(), style: const TextStyle(fontSize: 44)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCenterEmoji() {
    switch (type) {
      case IllustrationType.createAccount:
        return '🍲';
      case IllustrationType.signIn:
        return '🍳';
      case IllustrationType.resetPassword:
        return '📧';
      case IllustrationType.allSet:
        return '✅';
    }
  }

  List<Widget> _getDecorations() {
    switch (type) {
      case IllustrationType.createAccount:
        return [
          const Positioned(top: 20, left: 20, child: Text('🥦', style: TextStyle(fontSize: 22))),
          const Positioned(top: 10, right: 30, child: Text('🌿', style: TextStyle(fontSize: 18))),
          const Positioned(bottom: 20, right: 20, child: Text('🍎', style: TextStyle(fontSize: 20))),
          const Positioned(bottom: 10, left: 40, child: Text('✨', style: TextStyle(fontSize: 16))),
        ];
      case IllustrationType.signIn:
        return [
          const Positioned(top: 15, left: 18, child: Text('🧅', style: TextStyle(fontSize: 22))),
          const Positioned(top: 8, right: 28, child: Text('🥬', style: TextStyle(fontSize: 20))),
          const Positioned(bottom: 15, right: 22, child: Text('🍅', style: TextStyle(fontSize: 22))),
        ];
      case IllustrationType.resetPassword:
        return [
          const Positioned(top: 18, right: 30, child: Text('🍑', style: TextStyle(fontSize: 22))),
          const Positioned(bottom: 20, left: 30, child: Text('🔒', style: TextStyle(fontSize: 18))),
          const Positioned(top: 30, left: 22, child: Text('✉️', style: TextStyle(fontSize: 16))),
        ];
      case IllustrationType.allSet:
        return [
          const Positioned(top: 15, left: 20, child: Text('🌿', style: TextStyle(fontSize: 22))),
          const Positioned(top: 10, right: 28, child: Text('🍓', style: TextStyle(fontSize: 22))),
          const Positioned(bottom: 15, left: 50, child: Text('🥕', style: TextStyle(fontSize: 18))),
          const Positioned(bottom: 10, right: 40, child: Text('🥦', style: TextStyle(fontSize: 16))),
        ];
    }
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _FoodDeco extends StatelessWidget {
  final String asset;
  final double size;
  const _FoodDeco({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
