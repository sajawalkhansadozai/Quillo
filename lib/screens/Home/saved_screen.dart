import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/recipe_model.dart';
import 'recipe_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _activeFilter = 'All';
  String _activeTab = 'Recipes';

  final _filters = ['All', '❤️ Favourites', 'Made Once', 'Quick 30min'];

  List<RecipeModel> get _filteredRecipes {
    if (_activeFilter == 'Quick 30min') {
      return RecipeModel.savedAll.where((r) => r.time <= 30).toList();
    }
    return RecipeModel.savedAll;
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildStats()),
            SliverToBoxAdapter(child: _buildSearch()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            SliverToBoxAdapter(child: _buildListHeader(recipes.length)),
            if (recipes.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _FeaturedSavedCard(
                    recipe: recipes.first,
                    onTap: () => _openDetail(context, recipes.first),
                  ),
                ),
              ),
            if (recipes.length > 1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _SavedGridCard(
                      recipe: recipes[i + 1],
                      onTap: () => _openDetail(ctx, recipes[i + 1]),
                    ),
                    childCount: recipes.length - 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, RecipeModel recipe) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => RecipeDetailScreen(recipe: recipe),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {},
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'Hi! Let\'s cook',
                  style: TextStyle(fontSize: 11, color: AppColors.textMedium),
                ),
                SizedBox(height: 2),
                Text(
                  'Saved Recipes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
          _CircleButton(
            icon: Icons.tune_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatChip(
            label: '10 Saved',
            isActive: _activeTab == 'Saved',
            activeColor: AppColors.primary,
            onTap: () => setState(() => _activeTab = 'Saved'),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '22 Recipes',
            isActive: _activeTab == 'Recipes',
            activeColor: AppColors.primary,
            onTap: () => setState(() => _activeTab = 'Recipes'),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '4 Created',
            isActive: _activeTab == 'Created',
            activeColor: const Color(0xFF4CAF50),
            onTap: () => setState(() => _activeTab = 'Created'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: AppColors.textLight, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Search your saved recipes',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final isSelected = f == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.chipBorder,
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count recipes saved',
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          GestureDetector(
            onTap: () {},
            child: Row(
              children: [
                const Text(
                  'Recent saved',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured saved card – full width
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedSavedCard extends StatelessWidget {
  final RecipeModel recipe;
  final VoidCallback onTap;
  const _FeaturedSavedCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: recipe.color.withValues(alpha: 0.15),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background emoji large
            Positioned(
              right: -10,
              bottom: -10,
              child: Text(recipe.emoji, style: const TextStyle(fontSize: 120)),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.transparent,
                    recipe.color.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            // Tag chip (top left)
            if (recipe.tag.isNotEmpty)
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recipe.tag,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // Bookmark icon (top right)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 18),
              ),
            ),
            // Info at bottom
            Positioned(
              left: 16,
              right: 80,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.timer_outlined, color: Colors.white70, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.time} min',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.people_outline_rounded, color: Colors.white70, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.servings} serv',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid card
// ─────────────────────────────────────────────────────────────────────────────

class _SavedGridCard extends StatefulWidget {
  final RecipeModel recipe;
  final VoidCallback onTap;
  const _SavedGridCard({required this.recipe, required this.onTap});

  @override
  State<_SavedGridCard> createState() => _SavedGridCardState();
}

class _SavedGridCardState extends State<_SavedGridCard> {
  bool _bookmarked = true;

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: recipe.color.withValues(alpha: 0.13),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Center(
                      child: Text(recipe.emoji, style: const TextStyle(fontSize: 52)),
                    ),
                  ),
                  // Tag chip
                  if (recipe.tag.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: recipe.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recipe.tag,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  // Bookmark button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _bookmarked = !_bookmarked),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 16,
                          color: _bookmarked ? AppColors.primary : AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info area
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.accent, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        recipe.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.timer_outlined, color: AppColors.textLight, size: 11),
                      const SizedBox(width: 2),
                      Text(
                        '${recipe.time}m',
                        style: const TextStyle(fontSize: 11, color: AppColors.textLight),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

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
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  const _StatChip({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : AppColors.chipBorder,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}
