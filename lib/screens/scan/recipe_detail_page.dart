import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeneratedRecipeDetailPage — full-screen detail view matching design reference
// ─────────────────────────────────────────────────────────────────────────────

class GeneratedRecipeDetailPage extends StatefulWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;

  const GeneratedRecipeDetailPage({
    super.key,
    required this.recipe,
    required this.accentColor,
  });

  @override
  State<GeneratedRecipeDetailPage> createState() =>
      _GeneratedRecipeDetailPageState();
}

class _GeneratedRecipeDetailPageState
    extends State<GeneratedRecipeDetailPage> {
  bool _isSaved = false;
  bool _checkingStatus = true;
  int _servings = 2;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
    _initSavedStatus();
  }

  Future<void> _initSavedStatus() async {
    if (widget.recipe.id != null) {
      final saved = await RecipeService.isRecipeSaved(widget.recipe.id!);
      if (mounted) setState(() {
        _isSaved = saved;
        _checkingStatus = false;
      });
    } else {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _toggleSave() async {
    if (widget.recipe.id == null) return;
    setState(() => _isSaved = !_isSaved);
    if (_isSaved) {
      await RecipeService.saveRecipe(widget.recipe);
    } else {
      await RecipeService.unsaveRecipe(widget.recipe.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = widget.accentColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero ──────────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHero(recipe, color)),

              // ── Tags + Title + Meta ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cuisine tags
                      Wrap(
                        spacing: 6,
                        children: _cuisineTags(recipe.title)
                            .map((t) => _TagChip(label: t, color: color))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      // Title
                      Text(recipe.title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                              fontFamily: 'Nunito',
                              height: 1.2)),
                      const SizedBox(height: 8),
                      // Quick meta row
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: AppColors.textMedium),
                          const SizedBox(width: 3),
                          Text('${recipe.cookTimeMinutes} min total',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                          const SizedBox(width: 12),
                          const Icon(Icons.people_outline_rounded,
                              size: 13, color: AppColors.textMedium),
                          const SizedBox(width: 3),
                          Text('${recipe.servings} servings',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                          const SizedBox(width: 12),
                          const Icon(Icons.local_fire_department_outlined,
                              size: 13, color: AppColors.textMedium),
                          const SizedBox(width: 3),
                          Text('${recipe.nutrition.calories} cal',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // AI row
                      _AIRow(color: color),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── 4 Stats ───────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _StatBox(
                          icon: Icons.timer_outlined,
                          value: '${recipe.cookTimeMinutes}',
                          unit: 'min',
                          label: 'Cook Time',
                          color: color),
                      const SizedBox(width: 10),
                      _StatBox(
                          icon: Icons.local_fire_department_outlined,
                          value: '${recipe.nutrition.calories}',
                          unit: 'kcal',
                          label: 'Calories',
                          color: const Color(0xFFFF9800)),
                      const SizedBox(width: 10),
                      _StatBox(
                          icon: Icons.people_outline_rounded,
                          value: '${recipe.servings}',
                          unit: 'srv',
                          label: 'Servings',
                          color: const Color(0xFF4CAF50)),
                      const SizedBox(width: 10),
                      _StatBox(
                          icon: Icons.bar_chart_rounded,
                          value: recipe.difficulty,
                          unit: '',
                          label: 'Difficulty',
                          color: _difficultyColor(recipe.difficulty)),
                    ],
                  ),
                ),
              ),

              // ── Ingredients ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ingredients',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                              fontFamily: 'Nunito')),
                      Row(children: [
                        _CounterBtn(
                            icon: Icons.remove_rounded,
                            onTap: () {
                              if (_servings > 1) {
                                setState(() => _servings--);
                              }
                            }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('$_servings',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark)),
                        ),
                        _CounterBtn(
                            icon: Icons.add_rounded,
                            onTap: () => setState(() => _servings++)),
                      ]),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _IngredientTile(
                      item: recipe.ingredientsUsed[i],
                      servingMultiplier: _servings / recipe.servings,
                    ),
                    childCount: recipe.ingredientsUsed.length,
                  ),
                ),
              ),

              // ── Missing Ingredients ───────────────────────────────────────
              if (recipe.missingIngredients.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _MissingIngredientsCard(
                        items: recipe.missingIngredients, color: color),
                  ),
                ),

              // ── Instructions ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: const Text('Instructions',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontFamily: 'Nunito')),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) =>
                        _StepCard(step: recipe.steps[i], color: color),
                    childCount: recipe.steps.length,
                  ),
                ),
              ),

              // ── Nutrition ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Nutrition',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textDark,
                                  fontFamily: 'Nunito')),
                          const Spacer(),
                          Text('per serving',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        _NutBox(
                            value: '${recipe.nutrition.calories}',
                            unit: 'kcal',
                            label: 'Calories',
                            color: const Color(0xFFFF9800)),
                        const SizedBox(width: 10),
                        _NutBox(
                            value: '${recipe.nutrition.protein}g',
                            unit: '',
                            label: 'Protein',
                            color: const Color(0xFF4CAF50)),
                        const SizedBox(width: 10),
                        _NutBox(
                            value: '${recipe.nutrition.fat}g',
                            unit: '',
                            label: 'Fat',
                            color: const Color(0xFFE91E63)),
                        const SizedBox(width: 10),
                        _NutBox(
                            value: '${recipe.nutrition.carbs}g',
                            unit: '',
                            label: 'Carbs',
                            color: color),
                      ]),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),

          // ── Sticky bottom CTA ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ],
              ),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Happy cooking! 👨‍🍳'),
                      backgroundColor: color,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.75)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('✦',
                            style: TextStyle(
                                fontSize: 14, color: Colors.white)),
                        SizedBox(width: 8),
                        Text('Start Cooking',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFamily: 'Nunito')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero image builder ──────────────────────────────────────────────────────

  Widget _buildHero(GeneratedRecipe recipe, Color color) {
    final emoji = _emojiFor(recipe.title);
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or emoji background
          if (recipe.imageUrl != null)
            Image.network(
              recipe.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: color.withValues(alpha: 0.15),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 90))),
              ),
            )
          else
            Container(
              color: color.withValues(alpha: 0.12),
              child: Center(
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 90))),
            ),
          // Bottom gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // Top action bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _HeroBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop()),
                const Spacer(),
                _HeroBtn(
                    icon: Icons.share_rounded, onTap: () {}),
                const SizedBox(width: 8),
                _HeroBtn(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onTap: _toggleSave,
                  active: _isSaved,
                  activeColor: color,
                ),
              ],
            ),
          ),
          // Bottom match badge
          Positioned(
            bottom: 14,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('AI Generated',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _cuisineTags(String title) {
    final t = title.toLowerCase();
    final tags = <String>[];
    if (t.contains('italian') || t.contains('pasta') ||
        t.contains('pizza') || t.contains('pesto')) {
      tags.add('Italian');
    }
    if (t.contains('thai') || t.contains('pad')) tags.add('Thai');
    if (t.contains('indian') || t.contains('curry') ||
        t.contains('tikka') || t.contains('paneer')) {
      tags.add('Indian');
    }
    if (t.contains('asian') || t.contains('stir') ||
        t.contains('ramen') || t.contains('miso')) {
      tags.add('Asian');
    }
    if (t.contains('chicken') || t.contains('fish') ||
        t.contains('beef') || t.contains('salmon')) {
      tags.add('Non-Veg');
    }
    if (t.contains('salad') || t.contains('vegan') ||
        t.contains('vegetable')) {
      tags.add('Vegetarian');
    }
    if (tags.isEmpty) tags.add('AI Recipe');
    return tags.take(3).toList();
  }

  static String _emojiFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('pasta') || t.contains('spaghetti')) return '🍝';
    if (t.contains('chicken')) return '🍗';
    if (t.contains('beef') || t.contains('steak')) return '🥩';
    if (t.contains('fish') || t.contains('salmon')) return '🐟';
    if (t.contains('salad')) return '🥗';
    if (t.contains('soup') || t.contains('stew')) return '🍲';
    if (t.contains('pizza')) return '🍕';
    if (t.contains('rice')) return '🍚';
    if (t.contains('egg') || t.contains('omelette')) return '🍳';
    if (t.contains('ramen') || t.contains('noodle')) return '🍜';
    if (t.contains('taco') || t.contains('burrito')) return '🌮';
    if (t.contains('curry') || t.contains('indian')) return '🍛';
    if (t.contains('mushroom')) return '🍄';
    if (t.contains('bread') || t.contains('toast')) return '🍞';
    if (t.contains('pancake')) return '🥞';
    if (t.contains('shrimp') || t.contains('prawn')) return '🍤';
    return '🍽️';
  }

  static Color _difficultyColor(String d) {
    switch (d.toLowerCase()) {
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
// Hero action button
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  const _HeroBtn(
      {required this.icon,
      required this.onTap,
      this.active = false,
      this.activeColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
          ],
        ),
        child: Icon(icon,
            size: 17,
            color: active ? (activeColor ?? AppColors.primary) : AppColors.textDark),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI row
// ─────────────────────────────────────────────────────────────────────────────

class _AIRow extends StatelessWidget {
  final Color color;
  const _AIRow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.6)]),
            shape: BoxShape.circle,
          ),
          child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quillo AI',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const Text('AI-Generated Recipe',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMedium)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('Personalised',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat box
// ─────────────────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final Color color;
  const _StatBox(
      {required this.icon,
      required this.value,
      required this.unit,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'Nunito')),
            if (unit.isNotEmpty)
              Text(unit,
                  style: TextStyle(
                      fontSize: 9, color: color.withValues(alpha: 0.7))),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ingredient tile
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientTile extends StatelessWidget {
  final RecipeIngredientUsed item;
  final double servingMultiplier;
  const _IngredientTile(
      {required this.item, required this.servingMultiplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          Text(_emojiFor(item.name),
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                    overflow: TextOverflow.ellipsis),
                Text(item.amount,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _emojiFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('chicken')) return '🍗';
    if (n.contains('beef') || n.contains('steak')) return '🥩';
    if (n.contains('fish') || n.contains('salmon')) return '🐟';
    if (n.contains('pasta') || n.contains('noodle')) return '🍝';
    if (n.contains('rice')) return '🍚';
    if (n.contains('egg')) return '🥚';
    if (n.contains('milk') || n.contains('cream')) return '🥛';
    if (n.contains('cheese')) return '🧀';
    if (n.contains('butter')) return '🧈';
    if (n.contains('oil') || n.contains('olive')) return '🫙';
    if (n.contains('garlic') || n.contains('onion')) return '🧅';
    if (n.contains('tomato')) return '🍅';
    if (n.contains('lemon') || n.contains('lime')) return '🍋';
    if (n.contains('salt') || n.contains('pepper') || n.contains('spice')) return '🧂';
    if (n.contains('herb') || n.contains('basil') || n.contains('parsley')) return '🌿';
    if (n.contains('mushroom')) return '🍄';
    if (n.contains('spinach') || n.contains('lettuce')) return '🥬';
    if (n.contains('carrot')) return '🥕';
    if (n.contains('potato')) return '🥔';
    if (n.contains('avocado')) return '🥑';
    if (n.contains('bread')) return '🍞';
    if (n.contains('yogurt')) return '🥣';
    if (n.contains('ginger')) return '🫚';
    return '🥄';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Missing ingredients card
// ─────────────────────────────────────────────────────────────────────────────

class _MissingIngredientsCard extends StatelessWidget {
  final List<MissingIngredient> items;
  final Color color;
  const _MissingIngredientsCard(
      {required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Missing Ingredients',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito')),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${items.length} items',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Text('Almost there!',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const Spacer(),
                Text('${items.length} to pick up',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMedium)),
              ]),
              const SizedBox(height: 12),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(_IngredientTile._emojiFor(item.name),
                              style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(item.amount,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                    ]),
                  )),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color:
                            AppColors.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                      child: Text('+ Add to Shopping List',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step card
// ─────────────────────────────────────────────────────────────────────────────

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
                child: Text('${step.order}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900))),
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
                        height: 1.55)),
                if (step.durationMinutes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12, color: color),
                        const SizedBox(width: 4),
                        Text('${step.durationMinutes} min',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Nutrition box
// ─────────────────────────────────────────────────────────────────────────────

class _NutBox extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  const _NutBox(
      {required this.value,
      required this.unit,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'Nunito')),
            if (unit.isNotEmpty)
              Text(unit,
                  style: TextStyle(
                      fontSize: 9, color: color.withValues(alpha: 0.7))),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag chip
// ─────────────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Serving counter button
// ─────────────────────────────────────────────────────────────────────────────

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: AppColors.chipBorder,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }
}
