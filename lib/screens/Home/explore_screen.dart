import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../scan/recipe_detail_page.dart';
import '../explore/collection_detail_screen.dart';
import '../shopping/shopping_lists_screen.dart';
import 'all_recipes_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExploreScreen — real recipes from Supabase with search + category filter
// ─────────────────────────────────────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _selectedCategory = 'All';
  static const _baseCategories = ['All', 'Easy', 'Medium', 'Hard', 'Quick'];

  List<GeneratedRecipe> _allRecipes = [];
  List<GeneratedRecipe> _searchResults = [];
  List<GeneratedRecipe> _filteredRecipes = [];
  bool _loading = true;
  bool _searchLoading = false;

  // User preferences for personalisation
  List<String> _userDietary = [];
  List<String> _userCuisines = [];

  List<String> get _categories {
    // Append saved cuisines as extra filter chips
    final extras = _userCuisines
        .where((c) => !_baseCategories.any(
            (b) => b.toLowerCase() == c.toLowerCase()))
        .toList();
    return [..._baseCategories, ...extras];
  }

  // ── Curated collections with keyword filters ───────────────────────────────
  static const _collections = [
    _CollectionData(
      title: 'Italian Classics',
      emoji: '🍝',
      color: Color(0xFFE53935),
      keywords: ['pasta', 'pizza', 'risotto', 'carbonara', 'lasagna',
                 'bruschetta', 'pesto', 'gnocchi', 'italian', 'parmesan'],
    ),
    _CollectionData(
      title: 'Street Food',
      emoji: '🌮',
      color: Color(0xFFFF9800),
      keywords: ['taco', 'burger', 'wrap', 'kebab', 'sandwich',
                 'hotdog', 'shawarma', 'falafel', 'street', 'noodle'],
    ),
    _CollectionData(
      title: 'Plant Based',
      emoji: '🌱',
      color: Color(0xFF4CAF50),
      keywords: ['salad', 'vegetable', 'tofu', 'lentil', 'vegan',
                 'mushroom', 'spinach', 'chickpea', 'avocado', 'bean'],
    ),
    _CollectionData(
      title: 'Quick Bites',
      emoji: '⚡',
      color: Color(0xFF5C6BC0),
      keywords: [],
      quickOnly: true,
    ),
    _CollectionData(
      title: 'Asian Flavours',
      emoji: '🍜',
      color: Color(0xFFE91E63),
      keywords: ['ramen', 'sushi', 'stir fry', 'curry', 'fried rice',
                 'pad thai', 'dim sum', 'teriyaki', 'miso', 'asian',
                 'thai', 'chinese', 'japanese', 'korean', 'tikka'],
    ),
    _CollectionData(
      title: 'Comfort Food',
      emoji: '🥘',
      color: Color(0xFF795548),
      keywords: ['soup', 'stew', 'casserole', 'roast', 'mashed',
                 'bake', 'gratin', 'chowder', 'pot', 'comfort'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      _applyFilters();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSearchFromSupabase(q);
    });
  }

  Future<void> _fetchSearchFromSupabase(String query) async {
    setState(() => _searchLoading = true);
    try {
      final results =
          await RecipeService.searchPublicRecipes(query: query, limit: 100);
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
      _applyFilters();
    } catch (_) {
      if (mounted) {
        setState(() => _searchLoading = false);
        _applyFilters();
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _fadeCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = _client.auth.currentUser?.id;
    try {
      final recipesFuture = RecipeService.listPublicRecipes(limit: 100);
      final prefsFuture = uid != null
          ? _client
              .from('user_preferences')
              .select('dietary_labels')
              .eq('user_id', uid)
              .maybeSingle()
          : Future<Map<String, dynamic>?>.value(null);
      final userFuture = uid != null
          ? _client
              .from('users')
              .select('preferred_cuisine')
              .eq('id', uid)
              .maybeSingle()
          : Future<Map<String, dynamic>?>.value(null);

      final results = await Future.wait([
        recipesFuture,
        prefsFuture,
        userFuture,
      ]);

      final recipes = results[0] as List<GeneratedRecipe>;
      final prefsRow = results[1];
      final userRow = results[2];

      if (mounted) {
        setState(() {
          _allRecipes = recipes;
          _userDietary = List<String>.from((prefsRow as Map?)?['dietary_labels'] ?? []);
          _userCuisines = List<String>.from((userRow as Map?)?['preferred_cuisine'] ?? []);
          _loading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('ExploreScreen error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final isSearching = _searchController.text.trim().isNotEmpty;
    final featuredId = _featured?.id;
    final source = isSearching ? _searchResults : _allRecipes;
    setState(() {
      _filteredRecipes = source.where((r) {
        if (!isSearching && r.id != null && r.id == featuredId) return false;
        final cat = _selectedCategory;
        final matchesCategory = cat == 'All' ||
            (cat == 'Quick' && r.cookTimeMinutes <= 20) ||
            r.difficulty.toLowerCase() == cat.toLowerCase() ||
            r.title.toLowerCase().contains(cat.toLowerCase());
        return matchesCategory;
      }).toList();
      _filteredRecipes.sort(GeneratedRecipe.compareByIngredientMatch);
    });
  }

  /// Recipes that match the user's dietary labels or cuisine preferences.
  List<GeneratedRecipe> get _forYouRecipes {
    if (_userDietary.isEmpty && _userCuisines.isEmpty) return [];
    final keywords = [
      ..._userDietary.map((d) => d.toLowerCase()),
      ..._userCuisines.map((c) => c.toLowerCase()),
    ];
    return _allRecipes.where((r) {
      final t = r.title.toLowerCase();
      return keywords.any((k) => t.contains(k));
    }).toList();
  }

  void _selectCategory(String cat) {
    setState(() => _selectedCategory = cat);
    _applyFilters();
  }

  List<GeneratedRecipe> get _quickRecipes =>
      _allRecipes.where((r) => r.cookTimeMinutes <= 20).toList();

  /// Count how many of the loaded recipes belong to a given collection.
  int _countForCollection(_CollectionData col) {
    if (col.quickOnly) {
      return _allRecipes.where((r) => r.cookTimeMinutes <= 20).length;
    }
    if (col.keywords.isEmpty) return 0;
    return _allRecipes.where((r) {
      final t = r.title.toLowerCase();
      return col.keywords.any((k) => t.contains(k.toLowerCase()));
    }).length;
  }

  /// Rotates daily — different recipe each day of the month.
  GeneratedRecipe? get _featured {
    if (_allRecipes.isEmpty) return null;
    final dayIndex = DateTime.now().day % _allRecipes.length;
    return _allRecipes[dayIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ── Header ───────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeader()),

                // ── Search bar ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _SearchBar(controller: _searchController),
                  ),
                ),

                // ── Category chips ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: _CategoryRow(
                    categories: _categories,
                    selected: _selectedCategory,
                    onSelect: _selectCategory,
                  ),
                ),

                // ── Search results (when typing) ──────────────────────────
                if (_searchController.text.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 18, 20, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _searchLoading
                                ? 'Searching…'
                                : '${_filteredRecipes.length} recipe${_filteredRecipes.length == 1 ? '' : 's'} for "${_searchController.text}"',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark),
                          ),
                          if (_filteredRecipes.isNotEmpty)
                            const Text(
                              'Tap a recipe to see what ingredients you need',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textMedium),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_searchLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      ),
                    )
                  else if (_filteredRecipes.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptySearch())
                  else
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _RecipeCard(
                            recipe: _filteredRecipes[i],
                            onTap: () => _openRecipe(_filteredRecipes[i]),
                          ),
                          childCount: _filteredRecipes.length,
                        ),
                      ),
                    ),
                ] else ...[
                  // ── For You ────────────────────────────────────────────
                  if (_forYouRecipes.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'For You',
                        action: _forYouRecipes.length > 6 ? 'See all' : '',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AllRecipesScreen(),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _RecipeCard(
                            recipe: _forYouRecipes[i],
                            onTap: () => _openRecipe(_forYouRecipes[i]),
                          ),
                          childCount: _forYouRecipes.length > 6
                              ? 6
                              : _forYouRecipes.length,
                        ),
                      ),
                    ),
                  ],

                  // ── Featured Today ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Featured Today',
                      action: 'Refresh',
                      onAction: _loadData,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _featured != null
                          ? _FeaturedCard(
                              recipe: _featured!,
                              onTap: () => _openRecipe(_featured!),
                            )
                          : const _FeaturedPlaceholder(),
                    ),
                  ),

                  // ── Collections ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Collections',
                      action: 'See all',
                      onAction: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => _AllCollectionsSheet(
                          collections: _collections,
                          allRecipes: _allRecipes,
                          countFor: _countForCollection,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _collections.length,
                        itemBuilder: (ctx, i) => _CollectionCard(
                          data: _collections[i],
                          count: _countForCollection(_collections[i]),
                        ),
                      ),
                    ),
                  ),

                  // ── All Recipes grid ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: _selectedCategory == 'All'
                          ? 'All Recipes'
                          : '$_selectedCategory Recipes',
                      action: _filteredRecipes.length > 6 ? 'See all' : '',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AllRecipesScreen(),
                        ),
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      ),
                    )
                  else if (_filteredRecipes.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyRecipes())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _RecipeCard(
                            recipe: _filteredRecipes[i],
                            onTap: () => _openRecipe(_filteredRecipes[i]),
                          ),
                          childCount: _filteredRecipes.length > 6
                              ? 6
                              : _filteredRecipes.length,
                        ),
                      ),
                    ),

                  // ── Quick & Easy ───────────────────────────────────────
                  if (_quickRecipes.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Quick & Easy',
                        action: 'See all',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AllRecipesScreen(initialFilter: 'Quick'),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _quickRecipes.length,
                          itemBuilder: (ctx, i) => _QuickCard(
                            recipe: _quickRecipes[i],
                            onTap: () => _openRecipe(_quickRecipes[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRecipe(GeneratedRecipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GeneratedRecipeDetailPage(
        recipe: recipe,
        accentColor: _tagColor(recipe.difficulty),
      ),
    ));
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DISCOVER',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textLight,
                        letterSpacing: 1.4)),
                const SizedBox(height: 2),
                const Text('Explore',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        fontFamily: 'Nunito')),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ShoppingListsScreen(),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
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
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 20,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecipes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10)
            ]),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu_rounded,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text('Your recipes will appear here',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito')),
            const SizedBox(height: 6),
            Text(
              'Scan a grocery receipt and Quillo will generate recipes personalised to what you have at home.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _EmptyTip(icon: Icons.eco_rounded, color: const Color(0xFF4CAF50), label: 'Dietary preferences'),
                const SizedBox(width: 8),
                _EmptyTip(icon: Icons.public_rounded, color: const Color(0xFF5C6BC0), label: 'Your cuisines'),
                const SizedBox(width: 8),
                _EmptyTip(icon: Icons.timer_outlined, color: const Color(0xFF009688), label: 'Cook time'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    final query = _searchController.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          const Text('No recipes found',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito')),
          const SizedBox(height: 6),
          Text(
            'No results for "$query". Try scanning a receipt with those ingredients — Quillo will generate matching recipes.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onAction;
  const _SectionHeader(
      {required this.title, this.action = '', this.onAction});

  static const _actionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Color(0xFF6259FF),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          if (action.isNotEmpty)
            GestureDetector(
              onTap: onAction,
              child: Text(action, style: _actionStyle),
            ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8)
          ]),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded,
              color: AppColors.textLight, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Search recipes to plan your shop...',
                hintStyle: TextStyle(
                    fontSize: 14, color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => controller.clear(),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.chipBorder,
                    shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textMedium),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final void Function(String) onSelect;
  const _CategoryRow(
      {required this.categories,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          final sel = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8, top: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : AppColors.chipBorder),
              ),
              child: Text(cat,
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
}

class _FeaturedCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _FeaturedCard({required this.recipe, required this.onTap});

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
              end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Stack(
          children: [
            // Background image or emoji
            if (recipe.imageUrl != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    recipe.imageUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.35),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              )
            else
              Positioned(
                  right: 16,
                  top: 12,
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 70))),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text("Quillo Pick",
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700))),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${recipe.cookTimeMinutes} min',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600))),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                  gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75)
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.difficulty.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                    Text(recipe.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Nunito')),
                    Row(children: [
                      const Icon(Icons.people_outline_rounded,
                          color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text('${recipe.servings} servings',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ]),
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

class _FeaturedPlaceholder extends StatelessWidget {
  const _FeaturedPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_rounded, size: 44, color: Colors.white38),
            SizedBox(height: 10),
            Text('Your featured recipe will appear here',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Scan a receipt to get started',
                style: TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _EmptyTip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _EmptyTip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Collection data & card ─────────────────────────────────────────────────

class _CollectionData {
  final String title;
  final String emoji;
  final Color color;
  final List<String> keywords;
  final bool quickOnly;
  const _CollectionData({
    required this.title,
    required this.emoji,
    required this.color,
    this.keywords = const [],
    this.quickOnly = false,
  });
}

class _CollectionCard extends StatelessWidget {
  final _CollectionData data;
  final int count;
  const _CollectionCard({required this.data, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count == 0
        ? 'No recipes yet'
        : '$count recipe${count == 1 ? '' : 's'}';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CollectionDetailScreen(
            title: data.title,
            emoji: data.emoji,
            color: data.color,
            keywords: data.keywords,
            quickOnly: data.quickOnly,
          ),
        ),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 8,
              bottom: 8,
              child: Opacity(
                opacity: 0.3,
                child: Text(data.emoji,
                    style: const TextStyle(fontSize: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COLLECTION',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(data.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Nunito')),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700),
                    ),
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

// ── Recipe grid card ─────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji(recipe.title);
    final tagColor = _tagColor(recipe.difficulty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: recipe.imageUrl != null
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: tagColor.withValues(alpha: 0.1),
                          child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 36))),
                        ),
                      )
                    : Container(
                        color: tagColor.withValues(alpha: 0.1),
                        child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 36))),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.difficulty.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: tagColor,
                          letterSpacing: 0.8)),
                  Text(recipe.title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 10, color: AppColors.textLight),
                    const SizedBox(width: 2),
                    Text('${recipe.cookTimeMinutes}m',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight)),
                    const SizedBox(width: 6),
                    const Icon(Icons.people_outline_rounded,
                        size: 10, color: AppColors.textLight),
                    const SizedBox(width: 2),
                    Text('${recipe.servings}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick & Easy horizontal card ─────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _QuickCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji(recipe.title);
    final color = _tagColor(recipe.difficulty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8)
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(recipe.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.timer_outlined,
                  size: 10, color: AppColors.textLight),
              const SizedBox(width: 2),
              Text('${recipe.cookTimeMinutes}m',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textLight)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
  if (t.contains('egg') || t.contains('omelette')) return '🍳';
  if (t.contains('bread') || t.contains('toast')) return '🍞';
  if (t.contains('mushroom')) return '🍄';
  if (t.contains('ramen') || t.contains('noodle')) return '🍜';
  if (t.contains('taco') || t.contains('burrito')) return '🌮';
  if (t.contains('pancake') || t.contains('waffle')) return '🥞';
  if (t.contains('shrimp') || t.contains('prawn')) return '🍤';
  return '🍽️';
}

// ── All Collections bottom sheet ──────────────────────────────────────────────

class _AllCollectionsSheet extends StatelessWidget {
  final List<_CollectionData> collections;
  final List<GeneratedRecipe> allRecipes;
  final int Function(_CollectionData) countFor;
  const _AllCollectionsSheet({
    required this.collections,
    required this.allRecipes,
    required this.countFor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('All Collections',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        fontFamily: 'Nunito')),
                const SizedBox(height: 14),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 24),
              children: [
                ...collections.map((col) {
            final count = countFor(col);
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CollectionDetailScreen(
                    title: col.title,
                    emoji: col.emoji,
                    color: col.color,
                    keywords: col.keywords,
                    quickOnly: col.quickOnly,
                  ),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: col.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: col.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Text(col.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(col.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: col.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count == 0
                            ? 'No recipes'
                            : '$count recipe${count == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: col.color),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: col.color),
                  ],
                ),
              ),
            );
          }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _tagColor(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return const Color(0xFF4CAF50);
    case 'hard':
      return const Color(0xFFE53935);
    default:
      return const Color(0xFFFF9800);
  }
}
