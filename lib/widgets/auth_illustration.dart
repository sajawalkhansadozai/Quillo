import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum IllustrationType { createAccount, signIn, resetPassword, allSet }

class AuthIllustration extends StatelessWidget {
  final IllustrationType type;

  const AuthIllustration({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    // Use a dedicated asset for sign-in; fallback to Flutter-drawn blobs for others
    if (type == IllustrationType.signIn) {
      return SizedBox(
        height: 210,
        width: double.infinity,
        child: Image.asset(
          'assets/onboarding/signin_illustration.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
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
