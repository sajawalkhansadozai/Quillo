import 'package:flutter/material.dart';
import '../utils/recipe_image_source.dart';

class RecipeImageSourceBadge extends StatelessWidget {
  final String? imageUrl;
  final bool compact;
  final bool onDarkBackground;

  const RecipeImageSourceBadge({
    super.key,
    required this.imageUrl,
    this.compact = false,
    this.onDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final source = recipeImageSource(imageUrl);
    if (source == null) return const SizedBox.shrink();

    final label = recipeImageSourceLabel(source);
    final isGemini = source == RecipeImageSource.gemini;

    final background = onDarkBackground
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.92);
    final foreground = onDarkBackground
        ? Colors.white
        : (isGemini ? const Color(0xFF6A1B9A) : const Color(0xFF546E7A));
    final accent = isGemini ? const Color(0xFFCE93D8) : const Color(0xFF90A4AE);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: onDarkBackground
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGemini ? Icons.auto_awesome_rounded : Icons.link_rounded,
            size: compact ? 9 : 11,
            color: foreground,
          ),
          SizedBox(width: compact ? 2 : 3),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 8 : 9,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
