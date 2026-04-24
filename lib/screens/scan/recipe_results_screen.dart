import 'package:flutter/material.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecipeResultsScreen
// Displays 3 AI-generated recipe cards. Tap to expand full detail.
// ─────────────────────────────────────────────────────────────────────────────

class RecipeResultsScreen extends StatefulWidget {
  final String scanId;
  final List<GeneratedRecipe> recipes;

  const RecipeResultsScreen({
    super.key,
    required this.scanId,
    required this.recipes,
  });

  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen> {
  final Set<String> _savedIds = {};

  final List<Color> _cardColors = const [
    Color(0xFF6C63FF),
    Color(0xFF00BFA5),
    Color(0xFFFF6D6D),
  ];

  Future<void> _toggleSave(GeneratedRecipe recipe) async {
    if (recipe.id == null) return;
    final isSaved = _savedIds.contains(recipe.id);
    setState(() {
      if (isSaved) {
        _savedIds.remove(recipe.id);
      } else {
        _savedIds.add(recipe.id!);
      }
    });
    if (isSaved) {
      await RecipeService.unsaveRecipe(recipe.id!);
    } else {
      await RecipeService.saveRecipe(recipe);
    }
  }

  void _openDetail(BuildContext context, GeneratedRecipe recipe, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeDetailSheet(
        recipe: recipe,
        color: color,
        isSaved: _savedIds.contains(recipe.id),
        onToggleSave: () => _toggleSave(recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                itemCount: widget.recipes.length,
                itemBuilder: (_, i) {
                  final recipe = widget.recipes[i];
                  final color = _cardColors[i % _cardColors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _RecipeCard(
                      recipe: recipe,
                      color: color,
                      isSaved: _savedIds.contains(recipe.id),
                      onTap: () => _openDetail(context, recipe, color),
                      onSave: () => _toggleSave(recipe),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Recipes ✨',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        fontFamily: 'Nunito')),
                Text('AI-generated just for your ingredients',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.recipes.length} recipes',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: GestureDetector(
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.textDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Scan Another Receipt',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Nunito')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipe card
// ─────────────────────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final Color color;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _RecipeCard({
    required this.recipe,
    required this.color,
    required this.isSaved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color banner with emoji
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      _recipeEmoji(recipe.title),
                      style: const TextStyle(fontSize: 52),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onSave,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8)
                          ],
                        ),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved ? color : AppColors.textLight,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontFamily: 'Nunito')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Badge(
                          icon: Icons.timer_outlined,
                          label: recipe.cookTimeLabel,
                          color: color),
                      const SizedBox(width: 8),
                      _Badge(
                          icon: Icons.bar_chart_rounded,
                          label: recipe.difficultyLabel,
                          color: _difficultyColor(recipe.difficulty)),
                      const SizedBox(width: 8),
                      _Badge(
                          icon: Icons.people_outline_rounded,
                          label: '${recipe.servings} servings',
                          color: const Color(0xFF78909C)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _NutritionChip(
                          label: '${recipe.nutrition.calories} kcal',
                          icon: '🔥'),
                      const SizedBox(width: 8),
                      _NutritionChip(
                          label: '${recipe.nutrition.protein}g protein',
                          icon: '💪'),
                      const SizedBox(width: 8),
                      _NutritionChip(
                          label: '${recipe.nutrition.carbs}g carbs',
                          icon: '🌾'),
                    ],
                  ),
                  if (recipe.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🛒',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            '${recipe.missingIngredients.length} item${recipe.missingIngredients.length == 1 ? '' : 's'} to buy',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              'View Full Recipe',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: color),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _recipeEmoji(String title) {
    final t = title.toLowerCase();
    if (t.contains('chicken') || t.contains('poultry')) return '🍗';
    if (t.contains('pasta') || t.contains('spaghetti')) return '🍝';
    if (t.contains('soup') || t.contains('stew')) return '🥣';
    if (t.contains('salad')) return '🥗';
    if (t.contains('rice')) return '🍚';
    if (t.contains('fish') || t.contains('salmon') || t.contains('tuna')) return '🐟';
    if (t.contains('beef') || t.contains('steak')) return '🥩';
    if (t.contains('pizza')) return '🍕';
    if (t.contains('curry') || t.contains('indian')) return '🍛';
    if (t.contains('egg') || t.contains('omelette')) return '🍳';
    if (t.contains('veggie') || t.contains('vegetable') || t.contains('vegan')) return '🥦';
    if (t.contains('breakfast') || t.contains('pancake')) return '🥞';
    if (t.contains('cake') || t.contains('dessert') || t.contains('sweet')) return '🍰';
    return '🍽️';
  }

  static Color _difficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'hard':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFFF9800);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipe detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RecipeDetailSheet extends StatelessWidget {
  final GeneratedRecipe recipe;
  final Color color;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const _RecipeDetailSheet({
    required this.recipe,
    required this.color,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.chipBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(recipe.title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                                fontFamily: 'Nunito')),
                      ),
                      GestureDetector(
                        onTap: onToggleSave,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSaved
                                ? color.withValues(alpha: 0.1)
                                : AppColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isSaved
                                    ? color.withValues(alpha: 0.4)
                                    : AppColors.chipBorder),
                          ),
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSaved ? color : AppColors.textLight,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                          icon: Icons.timer_outlined,
                          label: recipe.cookTimeLabel,
                          color: color),
                      _Badge(
                          icon: Icons.bar_chart_rounded,
                          label: recipe.difficultyLabel,
                          color: _RecipeCard._difficultyColor(recipe.difficulty)),
                      _Badge(
                          icon: Icons.people_outline_rounded,
                          label: '${recipe.servings} servings',
                          color: const Color(0xFF78909C)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Nutrition
                  _SectionTitle(title: 'Nutrition per serving'),
                  const SizedBox(height: 10),
                  _NutritionPanel(nutrition: recipe.nutrition, color: color),
                  const SizedBox(height: 20),
                  // Ingredients used
                  _SectionTitle(
                      title:
                          'Ingredients Used (${recipe.ingredientsUsed.length})'),
                  const SizedBox(height: 10),
                  ...recipe.ingredientsUsed.map((i) => _ListRow(
                      icon: '✅',
                      title: i.name,
                      subtitle: i.amount)),
                  // Missing ingredients
                  if (recipe.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle(
                        title:
                            '🛒 Shopping List (${recipe.missingIngredients.length} missing)'),
                    const SizedBox(height: 10),
                    ...recipe.missingIngredients.map((i) => _ListRow(
                        icon: '➕',
                        title: i.name,
                        subtitle: i.amount,
                        dimmed: true)),
                  ],
                  const SizedBox(height: 20),
                  // Steps
                  _SectionTitle(
                      title: 'Instructions (${recipe.steps.length} steps)'),
                  const SizedBox(height: 12),
                  ...recipe.steps.map((step) => _StepCard(
                      step: step, color: color)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _NutritionChip extends StatelessWidget {
  final String label;
  final String icon;
  const _NutritionChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontFamily: 'Nunito'));
  }
}

class _NutritionPanel extends StatelessWidget {
  final RecipeNutritionData nutrition;
  final Color color;
  const _NutritionPanel({required this.nutrition, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _NutCol(label: 'Calories', value: '${nutrition.calories}', unit: 'kcal', color: color),
        _NutCol(label: 'Protein', value: '${nutrition.protein}', unit: 'g', color: const Color(0xFF4CAF50)),
        _NutCol(label: 'Carbs', value: '${nutrition.carbs}', unit: 'g', color: const Color(0xFFFF9800)),
        _NutCol(label: 'Fat', value: '${nutrition.fat}', unit: 'g', color: const Color(0xFFE91E63)),
      ]
          .map((w) => Expanded(child: w))
          .toList(),
    );
  }
}

class _NutCol extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _NutCol(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFamily: 'Nunito')),
          Text(unit,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool dimmed;

  const _ListRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dimmed
                        ? AppColors.textMedium
                        : AppColors.textDark)),
          ),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMedium)),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final RecipeStep step;
  final Color color;
  const _StepCard({required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${step.order}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.instruction,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        height: 1.5)),
                if (step.durationMinutes != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text('${step.durationMinutes} min',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
