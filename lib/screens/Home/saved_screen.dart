import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../theme/app_theme.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../services/local_db_service.dart';
import '../scan/recipe_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SavedScreen — real saved recipes with offline SQLite cache
// ─────────────────────────────────────────────────────────────────────────────

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _activeFilter = 'All';
  final _filters = ['All', '⏱ Quick 30min', '🔥 Easy'];

  List<GeneratedRecipe> _recipes = [];
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);

    // Check connectivity (v6+ returns List<ConnectivityResult>)
    final connResults = await Connectivity().checkConnectivity();
    final isOnline = connResults.any((r) => r != ConnectivityResult.none);

    if (isOnline) {
      try {
        final online = await RecipeService.loadSavedRecipes();
        // Sync to SQLite cache
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
      } catch (_) {
        // Fall through to offline cache
      }
    }

    // Offline fallback
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
    switch (_activeFilter) {
      case '⏱ Quick 30min':
        return _recipes.where((r) => r.cookTimeMinutes <= 30).toList();
      case '🔥 Easy':
        return _recipes
            .where((r) => r.difficulty.toLowerCase() == 'easy')
            .toList();
      default:
        return _recipes;
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
              // ── Header ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Offline banner ────────────────────────────────────────
              if (_offline)
                SliverToBoxAdapter(
                  child: _OfflineBanner(),
                ),

              // ── Stats ─────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildStats()),

              // ── Filter chips ──────────────────────────────────────────
              SliverToBoxAdapter(child: _buildFilterChips()),

              // ── Loading ───────────────────────────────────────────────
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                )
              // ── Empty state ───────────────────────────────────────────
              else if (recipes.isEmpty)
                SliverToBoxAdapter(child: _buildEmpty())
              // ── Recipe list ───────────────────────────────────────────
              else ...[
                if (recipes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _FeaturedSavedCard(
                        recipe: recipes.first,
                        onTap: () => _openDetail(recipes.first),
                        onUnsave: () => _unsave(recipes.first),
                      ),
                    ),
                  ),
                if (recipes.length > 1)
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _SavedGridCard(
                          recipe: recipes[i + 1],
                          onTap: () => _openDetail(recipes[i + 1]),
                          onUnsave: () => _unsave(recipes[i + 1]),
                        ),
                        childCount: recipes.length - 1,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(GeneratedRecipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          recipes: [recipe],
          scanId: '',
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Saved Recipes',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                fontFamily: 'Nunito'),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 20, color: Color(0xFFFF5252)),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final quickCount =
        _recipes.where((r) => r.cookTimeMinutes <= 30).length;
    final easyCount = _recipes
        .where((r) => r.difficulty.toLowerCase() == 'easy')
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          _StatChip(label: '${_recipes.length} Saved', emoji: '❤️'),
          const SizedBox(width: 8),
          _StatChip(label: '$quickCount Quick', emoji: '⏱'),
          const SizedBox(width: 8),
          _StatChip(label: '$easyCount Easy', emoji: '🔥'),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
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
                color:
                    sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : AppColors.chipBorder),
              ),
              child: Text(f,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: sel
                          ? Colors.white
                          : AppColors.textMedium)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
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
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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

class _StatChip extends StatelessWidget {
  final String label;
  final String emoji;
  const _StatChip({required this.label, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _FeaturedSavedCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onUnsave;
  const _FeaturedSavedCard(
      {required this.recipe,
      required this.onTap,
      required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji(recipe.title);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Stack(
          children: [
            Positioned(
                right: 16,
                top: 16,
                child: Text(emoji,
                    style: const TextStyle(fontSize: 70))),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Saved',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onUnsave,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_rounded,
                      size: 16, color: Color(0xFFFF5252)),
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'Nunito')),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Pill('${recipe.servings} servings'),
                      const SizedBox(width: 8),
                      _Pill(recipe.difficulty),
                      const SizedBox(width: 8),
                      _Pill('${recipe.cookTimeMinutes} min'),
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

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _SavedGridCard extends StatefulWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  final VoidCallback onUnsave;
  const _SavedGridCard(
      {required this.recipe,
      required this.onTap,
      required this.onUnsave});

  @override
  State<_SavedGridCard> createState() => _SavedGridCardState();
}

class _SavedGridCardState extends State<_SavedGridCard> {
  @override
  Widget build(BuildContext context) {
    final emoji = _emoji(widget.recipe.title);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
                child: Stack(
                  children: [
                    Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 48))),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: widget.onUnsave,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.favorite_rounded,
                              size: 14, color: Color(0xFFFF5252)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 11, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Text('${widget.recipe.cookTimeMinutes} min',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textLight)),
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

String _emoji(String title) {
  final t = title.toLowerCase();
  if (t.contains('pasta') || t.contains('spaghetti')) return '🍝';
  if (t.contains('chicken')) return '🍗';
  if (t.contains('beef') || t.contains('steak')) return '🥩';
  if (t.contains('fish') || t.contains('salmon')) return '🐟';
  if (t.contains('salad')) return '🥗';
  if (t.contains('soup')) return '🍲';
  if (t.contains('pizza')) return '🍕';
  if (t.contains('rice')) return '🍚';
  if (t.contains('egg')) return '🍳';
  if (t.contains('bread')) return '🍞';
  return '🍽️';
}
