import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/ingredient_visual.dart';

/// Small ingredient image — app illustration or food emoji in a rounded badge.
class IngredientVisualIcon extends StatelessWidget {
  final String ingredientName;
  final double size;
  final Color background;
  final BorderRadiusGeometry? borderRadius;

  const IngredientVisualIcon({
    super.key,
    required this.ingredientName,
    this.size = 34,
    this.background = const Color(0xFFF6F5FB),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final visual = ingredientVisualFor(ingredientName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius ?? BorderRadius.circular(10),
      ),
      child: Center(
        child: visual.hasAsset
            ? Image.asset(
                visual.assetPath!,
                width: size * 0.86,
                height: size * 0.86,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _emoji(visual.emoji),
              )
            : _emoji(visual.emoji),
      ),
    );
  }

  Widget _emoji(String emoji) {
    return Text(
      emoji,
      style: TextStyle(
        fontSize: size * 0.48,
        height: 1,
        color: AppColors.textDark,
      ),
    );
  }
}
