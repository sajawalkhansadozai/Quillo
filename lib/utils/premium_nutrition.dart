import 'package:flutter/material.dart';
import '../models/generated_recipe.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../screens/paywall_screen.dart';
import '../widgets/recipe_full_nutrition_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Premium gate for "Full info" nutrition breakdown.
// ─────────────────────────────────────────────────────────────────────────────

Future<void> openFullNutritionInfo(
  BuildContext context,
  GeneratedRecipe recipe, {
  int initialServings = 0,
}) async {
  final premium = await SubscriptionService.isPremium();
  if (!context.mounted) return;

  if (!premium) {
    final upgraded = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const PaywallScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        fullscreenDialog: true,
      ),
    );
    if (!context.mounted) return;
    if (upgraded != true && !await SubscriptionService.isPremium()) return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RecipeFullNutritionSheet(
        recipe: recipe,
        initialServings: initialServings,
      ),
    ),
  );
}

/// "Full info" link — shows Pro lock for free users.
class FullNutritionLink extends StatelessWidget {
  final GeneratedRecipe recipe;
  final int initialServings;

  const FullNutritionLink({
    super.key,
    required this.recipe,
    this.initialServings = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService.premiumNotifier,
      builder: (context, isPremium, _) {
        return GestureDetector(
          onTap: () => openFullNutritionInfo(
            context,
            recipe,
            initialServings: initialServings,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isPremium) ...[
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                isPremium ? 'Full info' : 'Full info · Pro',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
