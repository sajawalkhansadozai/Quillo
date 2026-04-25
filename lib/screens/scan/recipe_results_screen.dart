import 'package:flutter/material.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import 'recipe_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecipeResultsScreen — displays AI-generated recipes after a scan
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
  bool _selectAll = false;

  Future<void> _toggleSave(GeneratedRecipe recipe) async {
    if (recipe.id == null) return;
    final isSaved = _savedIds.contains(recipe.id);
    setState(() {
      isSaved ? _savedIds.remove(recipe.id) : _savedIds.add(recipe.id!);
    });
    if (isSaved) {
      await RecipeService.unsaveRecipe(recipe.id!);
    } else {
      await RecipeService.saveRecipe(recipe);
    }
  }

  void _openDetail(GeneratedRecipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GeneratedRecipeDetailPage(recipe: recipe, accentColor: AppColors.primary),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.recipes.length;
    final totalIngredients = widget.recipes
        .expand((r) => r.ingredientsUsed)
        .map((i) => i.name)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterRow(total, totalIngredients),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: widget.recipes.length,
                itemBuilder: (_, i) {
                  final recipe = widget.recipes[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RecipeListCard(
                      recipe: recipe,
                      isSaved: _savedIds.contains(recipe.id),
                      onTap: () => _openDetail(recipe),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Your Recipes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
              ),
              child: const Icon(Icons.ios_share_rounded, size: 18, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(int total, int ingredients) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _FilterChip(label: '$total Recipes total', selected: true),
          const SizedBox(width: 8),
          _FilterChip(label: '$ingredients ingredients'),
          const SizedBox(width: 8),
          _FilterChip(label: 'Sort', icon: Icons.sort_rounded),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Select all ingredients toggle
          GestureDetector(
            onTap: () => setState(() => _selectAll = !_selectAll),
            child: Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _selectAll ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _selectAll ? AppColors.primary : AppColors.chipBorder, width: 1.5),
                  ),
                  child: _selectAll ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 10),
                const Text('Select all ingredients',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Scan another receipt button
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC02),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF1A1A2E), size: 18),
                    SizedBox(width: 10),
                    Text('Scan Another Receipt',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E), fontFamily: 'Nunito')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared recipe list card (reused in AllRecipesScreen too)
// ─────────────────────────────────────────────────────────────────────────────

class RecipeListCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const RecipeListCard({
    super.key,
    required this.recipe,
    required this.isSaved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _badgeLabel(recipe);
    final badgeColor = _badgeColor(recipe);
    final emoji = _emojiFor(recipe.title);
    final ingredientPreview = recipe.ingredientsUsed
        .take(4)
        .map((i) => i.name)
        .join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 185,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Photo or gradient fallback
                    recipe.imageUrl != null
                        ? Image.network(recipe.imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _EmojiBg(emoji: emoji))
                        : _EmojiBg(emoji: emoji),
                    // Bottom gradient
                    Positioned(
                      bottom: 0, left: 0, right: 0, height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Category badge
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
                        child: Text(badge,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ),
                    // Bookmark button
                    Positioned(
                      top: 10, right: 10,
                      child: GestureDetector(
                        onTap: onSave,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)],
                          ),
                          child: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isSaved ? AppColors.primary : AppColors.textLight,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Info ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
                  if (ingredientPreview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(ingredientPreview,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatPill(icon: Icons.timer_outlined, label: '${recipe.cookTimeMinutes} min'),
                      const SizedBox(width: 8),
                      _StatPill(icon: Icons.people_outline_rounded, label: '${recipe.servings} srv'),
                      const SizedBox(width: 8),
                      _StatPill(icon: Icons.bar_chart_rounded, label: recipe.difficulty),
                      const Spacer(),
                      GestureDetector(
                        onTap: onTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Make it',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                          ],
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

  static String _badgeLabel(GeneratedRecipe r) {
    final t = r.title.toLowerCase();
    if (r.cookTimeMinutes <= 20) return 'QUICK';
    if (t.contains('salad') || t.contains('vegan') || t.contains('avocado')) return 'VEGAN';
    if (t.contains('chicken') || t.contains('beef') || t.contains('salmon') || t.contains('steak')) return 'DINNER';
    if (t.contains('egg') || t.contains('pancake') || t.contains('toast') || t.contains('omelette')) return 'BREAKFAST';
    if (t.contains('cake') || t.contains('dessert') || t.contains('sweet') || t.contains('mousse')) return 'DESSERT';
    if (t.contains('soup') || t.contains('stew')) return 'LUNCH';
    return r.difficulty.toUpperCase();
  }

  static Color _badgeColor(GeneratedRecipe r) {
    final label = _badgeLabel(r);
    switch (label) {
      case 'QUICK': return const Color(0xFF4CAF50);
      case 'VEGAN': return const Color(0xFF43A047);
      case 'DINNER': return const Color(0xFF6C63FF);
      case 'BREAKFAST': return const Color(0xFFFF9800);
      case 'DESSERT': return const Color(0xFFE91E63);
      case 'LUNCH': return const Color(0xFF00BCD4);
      default: return AppColors.primary;
    }
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
    if (t.contains('curry')) return '🍛';
    if (t.contains('smoothie') || t.contains('bowl')) return '🥣';
    if (t.contains('bruschetta') || t.contains('toast')) return '🥖';
    if (t.contains('cake') || t.contains('dessert') || t.contains('mousse')) return '🍰';
    return '🍽️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EmojiBg extends StatelessWidget {
  final String emoji;
  const _EmojiBg({required this.emoji});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D2B55), Color(0xFF3D3B66)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 72))),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.textLight),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  const _FilterChip({required this.label, this.selected = false, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : AppColors.chipBorder),
        boxShadow: selected ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: selected ? Colors.white : AppColors.textMedium),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textMedium)),
      ]),
    );
  }
}
