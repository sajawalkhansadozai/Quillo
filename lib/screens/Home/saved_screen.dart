import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../services/local_db_service.dart';
import '../scan/recipe_detail_page.dart' show GeneratedRecipeDetailPage;

// ─────────────────────────────────────────────────────────────────────────────
// SavedScreen
// ─────────────────────────────────────────────────────────────────────────────

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _activeFilter = 'All';
  final _filters = ['All', 'Favourites', 'Under 20min'];

  List<GeneratedRecipe> _recipes = [];
  bool _loading = true;
  bool _offline = false;
  String _search = '';

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);
    final connResults = await Connectivity().checkConnectivity();
    final isOnline = connResults.any((r) => r != ConnectivityResult.none);

    if (isOnline) {
      try {
        final online = await RecipeService.loadSavedRecipes();
        for (final r in online) {
          await LocalDbService.cacheRecipe(r);
        }
        if (mounted) {
          setState(() {
            _recipes = online;
            _offline = false;
            _loading = false;
          });
        }
        return;
      } catch (_) {}
    }

    final cached = await LocalDbService.loadAllRecipes();
    if (mounted) {
      setState(() {
        _recipes = cached;
        _offline = !isOnline;
        _loading = false;
      });
    }
  }

  List<GeneratedRecipe> get _filtered {
    var list = _recipes;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((r) => r.title.toLowerCase().contains(q)).toList();
    }
    switch (_activeFilter) {
      case 'Under 20min':
        return list.where((r) => r.cookTimeMinutes <= 20).toList();
      case 'Favourites':
        return list;
      default:
        return list;
    }
  }

  Future<void> _unsave(GeneratedRecipe recipe) async {
    if (recipe.id == null) return;
    try {
      await RecipeService.unsaveRecipe(recipe.id!);
      await LocalDbService.removeRecipe(recipe.id!);
      setState(() => _recipes.removeWhere((r) => r.id == recipe.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove recipe')),
        );
      }
    }
  }

  void _openDetail(GeneratedRecipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => GeneratedRecipeDetailPage(
                recipe: recipe,
                accentColor: AppColors.primary,
              )),
    );
  }

  int get _avgMin {
    if (_recipes.isEmpty) return 0;
    return (_recipes.map((r) => r.cookTimeMinutes).reduce((a, b) => a + b) /
            _recipes.length)
        .round();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecipes,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildStats()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildFilterChips()),
              if (_offline)
                SliverToBoxAdapter(child: _OfflineBanner()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (recipes.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              else ...[
                SliverToBoxAdapter(child: _buildCountRow(recipes.length)),
                // Featured first card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: _FeaturedCard(
                      recipe: recipes.first,
                      onTap: () => _openDetail(recipes.first),
                      onUnsave: () => _unsave(recipes.first),
                    ),
                  ),
                ),
                // 2-col grid for the rest
                if (recipes.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _GridCard(
                          recipe: recipes[i + 1],
                          onTap: () => _openDetail(recipes[i + 1]),
                          onUnsave: () => _unsave(recipes[i + 1]),
                        ),
                        childCount: recipes.length - 1,
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          _CircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'MY COLLECTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Saved Recipes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
          _CircleBtn(
            icon: Icons.tune_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ── Stats ───────────────────────────────────────────────────────────────────

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _StatBadge(
            label: '${_recipes.length} Saved',
            bg: const Color(0xFFEDE9FF),
            fg: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _StatBadge(
            label: '$_avgMin Avg min',
            bg: const Color(0xFFFFF8E1),
            fg: const Color(0xFFFF8F00),
          ),
          const SizedBox(width: 10),
          _StatBadge(
            label: '${_recipes.where((r) => r.difficulty.toLowerCase() == "easy").length} Cooked',
            bg: const Color(0xFFE8F5E9),
            fg: const Color(0xFF2E7D32),
          ),
        ],
      ),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Search your saved recipes',
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textLight),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 20, color: AppColors.textLight),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (ctx, i) {
          final f = _filters[i];
          final sel = f == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        sel ? AppColors.primary : AppColors.chipBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (f == 'Favourites')
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(Icons.favorite_rounded,
                          size: 12,
                          color: sel
                              ? Colors.white
                              : const Color(0xFFFF5252)),
                    ),
                  Text(f,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              sel ? Colors.white : AppColors.textMedium)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Count + sort row ────────────────────────────────────────────────────────

  Widget _buildCountRow(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Text(
            '$count recipe${count == 1 ? "" : "s"} saved',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const Icon(Icons.access_time_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          const Text(
            'Recently saved',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ── Empty ───────────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      child: Column(
        children: [
          const Text('📚', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          const Text('No saved recipes yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito')),
          const SizedBox(height: 8),
          const Text(
            'Scan a receipt, generate recipes and save the ones you love!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textMedium, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

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
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatBadge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300)),
      ),
      child: const Row(
        children: [
          Text('📵', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline — showing cached recipes",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF856404)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Featured full-width card ─────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onUnsave;
  const _FeaturedCard(
      {required this.recipe, required this.onTap, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2C2C3E),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                Image.network(
                  recipe.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _FallbackBg(title: recipe.title),
                )
              else
                _FallbackBg(title: recipe.title),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // FEATURED badge top-left
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5),
                  ),
                ),
              ),
              // Bookmark top-right
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onUnsave,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.bookmark_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
              // Bottom info
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'Nunito',
                          height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.cookTimeMinutes} min',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.people_outline_rounded,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings} serving${recipe.servings == 1 ? "" : "s"}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        _Stars(rating: 4.5),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2-column grid card ───────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onUnsave;
  const _GridCard(
      {required this.recipe, required this.onTap, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final category = _category(recipe.title);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                      Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _FallbackBg(title: recipe.title),
                      )
                    else
                      _FallbackBg(title: recipe.title),
                    // Category badge top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: category.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.label,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3),
                        ),
                      ),
                    ),
                    // Bookmark top-right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onUnsave,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 4)
                              ]),
                          child: const Icon(Icons.bookmark_rounded,
                              size: 14, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info section
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          height: 1.3),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: AppColors.textLight),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.cookTimeMinutes} min',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textLight),
                        ),
                        const Spacer(),
                        _Stars(rating: 4.0, size: 9),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Star rating ───────────────────────────────────────────────────────────────

class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  const _Stars({required this.rating, this.size = 11});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half
              ? Icons.star_half_rounded
              : filled
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFFFB300),
        );
      }),
    );
  }
}

// ── Fallback background ───────────────────────────────────────────────────────

class _FallbackBg extends StatelessWidget {
  final String title;
  const _FallbackBg({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      child: Center(
        child: Text(_emoji(title), style: const TextStyle(fontSize: 52)),
      ),
    );
  }
}

// ── Category helper ───────────────────────────────────────────────────────────

class _CategoryInfo {
  final String label;
  final Color color;
  const _CategoryInfo(this.label, this.color);
}

_CategoryInfo _category(String title) {
  final t = title.toLowerCase();
  if (t.contains('pasta') || t.contains('italian') || t.contains('risotto') ||
      t.contains('pizza') || t.contains('lasagna'))
    return const _CategoryInfo('ITALIAN', Color(0xFFE65100));
  if (t.contains('vegan') || t.contains('salad') || t.contains('buddha') ||
      t.contains('green') || t.contains('tofu'))
    return const _CategoryInfo('VEGAN', Color(0xFF2E7D32));
  if (t.contains('chicken') || t.contains('beef') || t.contains('steak') ||
      t.contains('tikka') || t.contains('masala'))
    return const _CategoryInfo('MEAT', Color(0xFFC62828));
  if (t.contains('soup') || t.contains('stew'))
    return const _CategoryInfo('SOUP', Color(0xFF1565C0));
  if (t.contains('dessert') || t.contains('cake') || t.contains('mousse') ||
      t.contains('tart') || t.contains('pancake'))
    return const _CategoryInfo('DESSERT', Color(0xFF6A1B9A));
  if (t.contains('ramen') || t.contains('japanese') || t.contains('sushi'))
    return const _CategoryInfo('JAPANESE', Color(0xFF0277BD));
  return const _CategoryInfo('RECIPE', Color(0xFF546E7A));
}

String _emoji(String title) {
  final t = title.toLowerCase();
  if (t.contains('pasta') || t.contains('spaghetti')) return '🍝';
  if (t.contains('chicken')) return '🍗';
  if (t.contains('beef') || t.contains('steak')) return '🥩';
  if (t.contains('fish') || t.contains('salmon')) return '🐟';
  if (t.contains('salad')) return '🥗';
  if (t.contains('soup')) return '🍲';
  if (t.contains('pizza')) return '🍕';
  if (t.contains('rice') || t.contains('ramen')) return '🍜';
  if (t.contains('egg')) return '🍳';
  if (t.contains('bread')) return '🍞';
  if (t.contains('cake') || t.contains('dessert')) return '🍰';
  return '🍽️';
}
