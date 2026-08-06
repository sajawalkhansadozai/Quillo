import 'package:flutter/material.dart';

import '../models/generated_recipe.dart';
import '../services/recipe_rating_service.dart';
import '../theme/app_theme.dart';
import 'recipe_rating_section.dart';

/// Bottom sheet shown after cooking to collect a recipe rating.
Future<RecipeRatingResult?> showRecipeRatingSheet(
  BuildContext context, {
  required GeneratedRecipe recipe,
  required Color accentColor,
  bool isEdit = false,
}) {
  return showModalBottomSheet<RecipeRatingResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecipeRatingSheet(
      recipe: recipe,
      accentColor: accentColor,
      isEdit: isEdit,
    ),
  );
}

class _RecipeRatingSheet extends StatelessWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;
  final bool isEdit;

  const _RecipeRatingSheet({
    required this.recipe,
    required this.accentColor,
    this.isEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.chipBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star_rounded, color: accentColor, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            isEdit ? 'Update your rating' : 'How was this recipe?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            recipe.title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          RecipeRatingSection(
            recipe: recipe,
            accentColor: accentColor,
            compact: true,
            showCommunitySummary: false,
            onRated: (result) {
              Navigator.of(context).pop(result);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.syncedToServer
                        ? 'Thanks! Your rating was saved.'
                        : 'Thanks! Rating saved on this device.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (!isEdit)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Maybe later',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
