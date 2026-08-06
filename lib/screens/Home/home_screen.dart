import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../config/recipe_search_config.dart';
import '../../services/streak_service.dart';
import '../../services/scan_limit_service.dart';
import '../../models/generated_recipe.dart';
import '../../widgets/scan_limit_sheet.dart';
import '../../widgets/scan_usage_banner.dart';
import '../../models/user_recipe_preferences.dart';
import '../../utils/recipe_preference_filter.dart';
import '../../services/recipe_service.dart';
import '../../services/recipe_rating_service.dart';
import '../../widgets/recipe_rating_badge.dart';
import '../../widgets/recipe_thumbnail_image.dart';
import '../scan/ingredient_review_screen.dart';
import '../scan/recipe_detail_page.dart';
import 'all_recipes_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onExploreTap;
  final void Function(String query, {bool focusSearch})? onSearchNavigate;

  const HomeScreen({
    super.key,
    this.onExploreTap,
    this.onSearchNavigate,
  });
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _client = Supabase.instance.client;

  String _userName = '';
  String? _avatarUrl;
  int _streak = 0;
  List<Map<String, dynamic>> _recentScans = [];
  List<GeneratedRecipe> _recentRecipes = [];
  List<GeneratedRecipe> _savedRecipes = [];
  List<GeneratedRecipe> _catalogRecipes = [];
  UserRecipePreferences _userPrefs = UserRecipePreferences.empty;
  bool _loading = true;
  String _selectedCategory = 'All';
  int _imageUpgradeGeneration = 0;
  final Set<String> _upgradingImageKeys = {};

  List<String> get _categories {
    final extras = _userPrefs.cuisines
        .where((c) => !['All', 'Quick', 'Breakfast', 'Lunch', 'Dinner', 'Vegan']
            .any((b) => b.toLowerCase() == c.toLowerCase()))
        .toList();
    return ['All', 'Quick', ...extras, 'Breakfast', 'Lunch', 'Dinner', 'Vegan'];
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
  }

  void _openExploreSearch({String query = '', bool focusSearch = false}) {
    widget.onSearchNavigate?.call(query, focusSearch: focusSearch);
  }

  @override
  void dispose() {
    _imageUpgradeGeneration++;
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _replaceRecipeInLists(GeneratedRecipe old, GeneratedRecipe updated) {
    final oldKey = RecipeService.imageTrackKey(old);

    void patch(List<GeneratedRecipe> list) {
      final i = list.indexWhere(
        (r) => RecipeService.imageTrackKey(r) == oldKey,
      );
      if (i >= 0) list[i] = updated;
    }

    setState(() {
      patch(_catalogRecipes);
      patch(_recentRecipes);
      _upgradingImageKeys.remove(oldKey);
    });
  }

  Future<void> _startBackgroundImageUpgrades(List<GeneratedRecipe> recipes) async {
    final generation = ++_imageUpgradeGeneration;
    final targets = recipes
        .where(RecipeService.needsGeminiImageUpgrade)
        .take(RecipeSearchConfig.exploreAiImageUpgradeLimit)
        .toList(growable: false);
    if (targets.isEmpty) return;

    setState(() {
      _upgradingImageKeys
        ..clear()
        ..addAll(targets.map(RecipeService.imageTrackKey));
    });

    await RecipeService.upgradeRecipeImagesInBackground(
      recipes: targets,
      shouldContinue: () =>
          mounted && generation == _imageUpgradeGeneration,
      onUpdated: (old, updated) {
        if (!mounted || generation != _imageUpgradeGeneration) return;
        _replaceRecipeInLists(old, updated);
      },
      onFinished: (recipe) {
        if (!mounted || generation != _imageUpgradeGeneration) return;
        setState(() {
          _upgradingImageKeys.remove(RecipeService.imageTrackKey(recipe));
        });
      },
    );
  }

  /// Called by MainShell when the user returns to the Home tab.
  Future<void> refresh() async {
    await Future.wait([refreshName(), _reloadPreferencesAndCatalog()]);
  }

  Future<void> _reloadPreferencesAndCatalog() async {
    try {
      final prefs = await RecipeService.loadUserPreferences();
      final catalog = await RecipeService.listPublicRecipes(
        limit: 40,
        preferences: prefs,
      );
      if (!mounted) return;
      setState(() {
        _userPrefs = prefs;
        _catalogRecipes = catalog;
        _recentRecipes = RecipePreferenceFilter.apply(_recentRecipes, prefs);
      });
      unawaited(_startBackgroundImageUpgrades([
        ...catalog,
        ..._recentRecipes,
      ]));
    } catch (_) {}
  }

  Future<void> refreshName() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await _client
          .from('users')
          .select('email, full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      final email = (row?['email'] as String?) ?? _client.auth.currentUser?.email ?? '';
      final dbFullName = (row?['full_name'] as String?)?.trim() ?? '';
      final ssoName = (_client.auth.currentUser?.userMetadata?['full_name'] as String?)?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _userName = dbFullName.isNotEmpty
            ? dbFullName
            : ssoName.isNotEmpty
                ? ssoName
                : _firstName(email);
        _avatarUrl = _resolveAvatarUrl(row);
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final prefsFuture = RecipeService.loadUserPreferences();
      final userRowFuture = _client
          .from('users')
          .select('email, full_name, avatar_url, scan_streak, last_scan_date')
          .eq('id', uid)
          .maybeSingle();
      final scansFuture = _client
          .from('scans').select('id, scan_date, status')
          .eq('user_id', uid).eq('status', 'complete')
          .order('scan_date', ascending: false).limit(5);
      final recipesFuture = _client
          .from('recipes')
          .select('id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url')
          .eq('user_id', uid)
          .order('created_at', ascending: false).limit(10);
      final savedFuture = _client
          .from('saved_recipes').select('cached_data')
          .eq('user_id', uid)
          .order('saved_at', ascending: false).limit(6);

      final prefs = await prefsFuture;
      final catalogFuture = RecipeService.listPublicRecipes(
        limit: 40,
        preferences: prefs,
      );
      final streakFuture = StreakService.getCurrentStreak();

      final results = await Future.wait<dynamic>([
        userRowFuture,
        scansFuture,
        recipesFuture,
        savedFuture,
        catalogFuture,
        streakFuture,
      ]);

      final userRow = results[0] as Map<String, dynamic>?;
      final email = (userRow?['email'] as String?) ?? _client.auth.currentUser?.email ?? '';
      final dbFullName = (userRow?['full_name'] as String?)?.trim() ?? '';
      final ssoName = (_client.auth.currentUser?.userMetadata?['full_name'] as String?)?.trim() ?? '';

      if (!mounted) return;
      setState(() {
        _userName = dbFullName.isNotEmpty
            ? dbFullName
            : ssoName.isNotEmpty
                ? ssoName
                : _firstName(email);
        _avatarUrl = _resolveAvatarUrl(userRow);
        _streak = results[5] as int;
        _recentScans = List<Map<String, dynamic>>.from(results[1] as List);
        _recentRecipes = RecipePreferenceFilter.apply(
          _parseRecipes(results[2] as List),
          prefs,
        );
        _savedRecipes = _parseSavedRecipes(results[3] as List);
        _catalogRecipes = results[4] as List<GeneratedRecipe>;
        _userPrefs = prefs;
        _loading = false;
      });
      RecipeRatingService.prefetchSummaries([
        ..._catalogRecipes,
        ..._recentRecipes,
        ..._savedRecipes,
      ]);
      unawaited(_startBackgroundImageUpgrades([
        ..._catalogRecipes,
        ..._recentRecipes,
      ]));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _firstName(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Chef';
    final stripped = local.replaceAll(RegExp(r'\d+$'), '');
    final name = stripped.isNotEmpty ? stripped : 'Chef';
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  String? _resolveAvatarUrl(Map<String, dynamic>? row) {
    final dbUrl = (row?['avatar_url'] as String?)?.trim();
    if (dbUrl != null && dbUrl.isNotEmpty) return dbUrl;

    final meta = _client.auth.currentUser?.userMetadata;
    if (meta == null) return null;
    for (final key in ['avatar_url', 'picture', 'avatar']) {
      final value = meta[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String get _userInitial {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  List<GeneratedRecipe> _parseRecipes(List data) =>
      GeneratedRecipe.sortedByIngredientMatch(
        data
            .map<GeneratedRecipe?>((r) {
              try {
                return GeneratedRecipe.fromJson(Map<String, dynamic>.from(r));
              } catch (_) {
                return null;
              }
            })
            .whereType<GeneratedRecipe>()
            .toList(),
      );

  List<GeneratedRecipe> _parseSavedRecipes(List data) {
    final recipes = <GeneratedRecipe>[];
    for (final item in data) {
      try {
        final c = item['cached_data'];
        if (c != null) recipes.add(GeneratedRecipe.fromJson(Map<String, dynamic>.from(c)));
      } catch (_) {}
    }
    return recipes;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<GeneratedRecipe> get _suggestedPool {
    final seen = <String>{};
    final merged = <GeneratedRecipe>[];
    for (final r in [..._catalogRecipes, ..._recentRecipes]) {
      final key = r.id ?? r.title.toLowerCase();
      if (seen.add(key)) merged.add(r);
    }
    return RecipePreferenceFilter.apply(merged, _userPrefs);
  }

  List<GeneratedRecipe> get _filtered {
    var list = _suggestedPool;
    if (_selectedCategory == 'All') return list;
    return list.where((r) => _matchesHomeCategory(r, _selectedCategory)).toList();
  }

  /// Category chips must match the same rules as the Suggested tile badges.
  static bool _matchesHomeCategory(GeneratedRecipe r, String category) {
    final t = r.title.toLowerCase();
    switch (category) {
      case 'Quick':
        // Match badge: QUICK is cook time ≤ 20 only (do NOT use maxCookTime prefs).
        return r.cookTimeMinutes > 0 && r.cookTimeMinutes <= 20;
      case 'Breakfast':
        return t.contains('egg') ||
            t.contains('pancake') ||
            t.contains('toast') ||
            t.contains('omelette') ||
            t.contains('oatmeal') ||
            t.contains('breakfast');
      case 'Lunch':
        return t.contains('salad') ||
            t.contains('soup') ||
            t.contains('sandwich') ||
            t.contains('wrap') ||
            t.contains('lunch');
      case 'Dinner':
        return t.contains('dinner') ||
            t.contains('chicken') ||
            t.contains('beef') ||
            t.contains('pasta') ||
            t.contains('steak') ||
            t.contains('salmon') ||
            t.contains('lamb') ||
            t.contains('pork') ||
            t.contains('roast');
      case 'Vegan':
        if (t.contains('vegan')) return true;
        if (!RecipePreferenceFilter.isVegetarian(r)) return false;
        return t.contains('salad') ||
            t.contains('tofu') ||
            t.contains('avocado') ||
            t.contains('lentil') ||
            t.contains('chickpea') ||
            t.contains('bean');
      default:
        // Cuisine chips from onboarding prefs (Greek, Turkish, Italian, …).
        return RecipePreferenceFilter.matchesCuisine(r, category);
    }
  }

  GeneratedRecipe? get _featuredRecipe {
    final fromScans = _recentRecipes.isNotEmpty ? _recentRecipes : null;
    if (fromScans != null && fromScans.isNotEmpty) {
      return RecipePreferenceFilter.pickFeatured(fromScans, _userPrefs) ??
          fromScans.first;
    }
    return RecipePreferenceFilter.pickFeatured(_catalogRecipes, _userPrefs);
  }

  void _goToScan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Get Recipe Ideas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Nunito')),
              const SizedBox(height: 4),
              const Text('Scan a receipt or enter ingredients manually.', style: TextStyle(fontSize: 13, color: Color(0xFF8B8B9E))),
              const SizedBox(height: 20),
              _ScanOption(icon: Icons.qr_code_scanner_rounded, color: AppColors.primary, title: 'Scan Receipt', subtitle: 'Take a photo — Quilloreads it instantly', onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, anim, __) => const ScanScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                  fullscreenDialog: true,
                ));
              }),
              const SizedBox(height: 12),
              _ScanOption(icon: Icons.edit_note_rounded, color: const Color(0xFF4CAF50), title: 'Enter Manually', subtitle: 'Type your ingredients yourself', onTap: () async {
                Navigator.pop(ctx);
                if (!await ScanLimitService.canScan()) {
                  if (context.mounted) await showScanLimitSheet(context);
                  return;
                }
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IngredientReviewScreen(ingredients: [], scanId: '')));
                }
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _goToAllRecipes() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllRecipesScreen()));
  }

  void _openRecipe(GeneratedRecipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GeneratedRecipeDetailPage(recipe: recipe, accentColor: AppColors.primary),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),
              const SliverToBoxAdapter(child: ScanUsageBanner()),

              // ── Search bar ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildSearchBar()),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else ...[
                // ── Featured Recipe ──────────────────────────────────────
                if (_featuredRecipe != null) ...[
                  SliverToBoxAdapter(child: _sectionHeader('Featured Recipe', 'View all', onTap: () => _goToAllRecipes())),
                  SliverToBoxAdapter(child: _buildFeaturedCard()),
                ],

                // ── AI Banner ────────────────────────────────────────────
                if (_featuredRecipe != null || _suggestedPool.isNotEmpty)
                  SliverToBoxAdapter(child: _buildAIBanner()),

                // ── Categories ───────────────────────────────────────────
                SliverToBoxAdapter(child: _buildCategories()),

                // ── Suggested for You ───────────────────────────────────
                SliverToBoxAdapter(
                  child: _sectionHeader(
                    'Suggested for You',
                    'See all',
                    onTap: () => _goToAllRecipes(),
                  ),
                ),
                if (_filtered.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyRecipes())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _SuggestedTile(
                        recipe: _filtered[i],
                        isImageUpgrading: _upgradingImageKeys.contains(
                          RecipeService.imageTrackKey(_filtered[i]),
                        ),
                        onTap: () => _openRecipe(_filtered[i]),
                      ),
                      childCount: _filtered.length.clamp(0, 6),
                    ),
                  ),

                // ── Saved Recipes ─────────────────────────────────────────
                if (_savedRecipes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _sectionHeader('Saved Recipes', 'See all', onTap: () => _goToAllRecipes()),
                  ),
                  SliverToBoxAdapter(child: _buildSavedScroll()),
                ],

                // ── Scan Banner ───────────────────────────────────────────
                SliverToBoxAdapter(child: _buildScanBanner()),

                // ── Recent Scans ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _sectionHeader('Recent Scans', '', onTap: () {}),
                ),
                SliverToBoxAdapter(
                  child: _recentScans.isEmpty
                      ? _buildEmptyScans()
                      : _buildRecentScans(),
                ),

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
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting ${DateTime.now().hour < 12 ? "☀️" : DateTime.now().hour < 17 ? "🌤️" : "🌙"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      fontFamily: 'Nunito',
                    ),
                    children: [
                      const TextSpan(text: 'Hey, '),
                      TextSpan(
                        text: '$_userName!',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Streak badge
          if (_streak > 0)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text('$_streak', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
              ]),
            ),
          // Bell
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => const _NotificationsSheet(),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderAvatar(),
        ],
      ),
    );
  }

  Widget _buildHeaderAvatar() {
    const size = 40.0;
    final hasImage = _avatarUrl != null && _avatarUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: hasImage
          ? Image.network(
              _avatarUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildHeaderAvatarInitial(size),
            )
          : _buildHeaderAvatarInitial(size),
    );
  }

  Widget _buildHeaderAvatarInitial([double size = 40]) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF9C8FFF)],
        ),
      ),
      child: Text(
        _userInitial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openExploreSearch(focusSearch: true),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: AppColors.textLight, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Search recipes...',
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Featured Recipe ──────────────────────────────────────────────────────────

  Widget _buildFeaturedCard() {
    final recipe = _featuredRecipe!;
    final emoji = _emojiFor(recipe.title);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: GestureDetector(
        onTap: () => _openRecipe(recipe),
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RecipeThumbnailImage(
                  imageUrl: recipe.imageUrl,
                  emoji: emoji,
                  placeholderColor: const Color(0xFF1A1A2E),
                  isImageUpgrading: _upgradingImageKeys.contains(
                    RecipeService.imageTrackKey(recipe),
                  ),
                  cacheWidth: 960,
                ),
                // Dark overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
                // Badges
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: AppColors.primary, size: 12),
                        SizedBox(width: 4),
                        Text(
                          "Chef's Pick",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, color: AppColors.textDark, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.cookTimeMinutes} min',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Title + stats
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(recipe.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito')),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _FeaturedStat(
                            icon: Icons.people_outline_rounded,
                            label: '${recipe.servings} servings',
                          ),
                          const SizedBox(width: 12),
                          _FeaturedStat(
                            icon: Icons.bar_chart_rounded,
                            label: recipe.difficultyLabel,
                          ),
                          const SizedBox(width: 12),
                          _FeaturedStat(
                            icon: Icons.restaurant_rounded,
                            label: _cuisineHint(recipe.title),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AI Banner ────────────────────────────────────────────────────────────────

  Widget _buildAIBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF9E6), Color(0xFFFFF0B8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quillo found ${_recentRecipes.length} new recipes',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Based on your last recipe scan',
                    style: TextStyle(fontSize: 11, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onExploreTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Text('Categories', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final sel = cat == _selectedCategory;
              final chipStyle = _categoryChipStyle(cat, sel);
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: chipStyle.$1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: chipStyle.$2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Empty recipes ────────────────────────────────────────────────────────────

  Widget _buildEmptyRecipes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const Text('🍽️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text(
            'No recipes yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan a receipt to get recipes!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMedium),
          ),
        ]),
      ),
    );
  }

  // ── Saved scroll ─────────────────────────────────────────────────────────────

  Widget _buildSavedScroll() {
    return SizedBox(
      height: _SavedCard.cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _savedRecipes.length,
        itemBuilder: (ctx, i) => _SavedCard(
          recipe: _savedRecipes[i],
          onTap: () => _openRecipe(_savedRecipes[i]),
        ),
      ),
    );
  }

  // ── Scan banner ───────────────────────────────────────────────────────────────

  Widget _buildScanBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: _goToScan,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B89F4), Color(0xFFA5A6F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -22,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                right: 36,
                bottom: -28,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.document_scanner_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Scan a Receipt',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Turn groceries into meal ideas',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 10,
                                color: AppColors.accent.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.auto_awesome,
                                size: 8,
                                color: AppColors.accent.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppColors.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF5C4033),
                        size: 20,
                      ),
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

  // ── Recent scans ─────────────────────────────────────────────────────────────

  Widget _buildEmptyScans() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'No scans yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan your first grocery receipt and let\nQUILLO work its magic on your meals.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.5),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _goToScan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                    '+ Scan First Receipt',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRecentScans() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: _recentScans.map((scan) {
          final date = DateTime.tryParse(scan['scan_date'] ?? '') ?? DateTime.now();
          final daysAgo = DateTime.now().difference(date).inDays;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('🧾', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Grocery Scan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(daysAgo == 0 ? 'Today' : daysAgo == 1 ? 'Yesterday' : '$daysAgo days ago',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4CAF50))),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontFamily: 'Nunito',
          ),
        ),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ]),
    );
  }

  static (Color, Color) _categoryChipStyle(String cat, bool selected) {
    if (selected) return (AppColors.primary, Colors.white);
    switch (cat) {
      case 'Breakfast':
        return (const Color(0xFFFFE8D6), const Color(0xFF8D4E1F));
      case 'Lunch':
        return (const Color(0xFFDFF5EE), const Color(0xFF1B6B52));
      case 'Dinner':
        return (const Color(0xFFEDE7FF), const Color(0xFF5E4DB0));
      case 'Vegan':
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case 'Quick':
        return (const Color(0xFFEDE7FF), AppColors.primary);
      default:
        return (Colors.white, AppColors.textMedium);
    }
  }

  static String _cuisineHint(String title) {
    final t = title.toLowerCase();
    if (t.contains('ramen') || t.contains('sushi') || t.contains('teriyaki')) return 'Japanese';
    if (t.contains('taco') || t.contains('burrito') || t.contains('mexican')) return 'Mexican';
    if (t.contains('pasta') || t.contains('pizza') || t.contains('risotto')) return 'Italian';
    if (t.contains('curry') || t.contains('tikka') || t.contains('biryani')) return 'Indian';
    if (t.contains('pad thai') || t.contains('thai')) return 'Thai';
    if (t.contains('croissant') || t.contains('baguette')) return 'French';
    return 'Global';
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
    if (t.contains('taco') || t.contains('burrito')) return '🌮';
    return '🍽️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggested for You tile
// ─────────────────────────────────────────────────────────────────────────────

// ── Notifications sheet ───────────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Notifications',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito')),
          const SizedBox(height: 8),
          const Text(
            "You're all caught up! Recipe tips and\ncooking reminders will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('Got it',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedTile extends StatefulWidget {
  final GeneratedRecipe recipe;
  final bool isImageUpgrading;
  final VoidCallback onTap;
  const _SuggestedTile({
    required this.recipe,
    this.isImageUpgrading = false,
    required this.onTap,
  });

  @override
  State<_SuggestedTile> createState() => _SuggestedTileState();
}

class _SuggestedTileState extends State<_SuggestedTile> {
  bool _saved = false;
  bool _saving = false;

  Future<void> _toggleSave() async {
    if (_saving || widget.recipe.id == null) return;
    setState(() => _saving = true);
    try {
      if (_saved) {
        await RecipeService.unsaveRecipe(widget.recipe.id!);
      } else {
        await RecipeService.saveRecipe(widget.recipe);
      }
      if (mounted) setState(() => _saved = !_saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save recipe'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final badge = _badge(recipe);
    final (badgeBg, badgeFg) = _badgeStyle(badge);
    final emoji = HomeScreenState._emojiFor(recipe.title);
    final servingsLabel =
        recipe.servings == 1 ? '1 serving' : '${recipe.servings} servings';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        constraints: const BoxConstraints(minHeight: 104),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 124,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RecipeThumbnailImage(
                      imageUrl: recipe.imageUrl,
                      emoji: emoji,
                      placeholderColor: badgeBg,
                      isImageUpgrading: widget.isImageUpgrading,
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: RecipeRatingBadge(
                        recipe: recipe,
                        accentColor: badgeFg,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeFg,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          height: 1.2,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Color(0xFF7C7C8C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe.cookTimeMinutes} min',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C7C8C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                servingsLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7C7C8C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleSave,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E8FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Icon(
                                      _saved
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, Color) _badgeStyle(String badge) {
    switch (badge) {
      case 'QUICK':
        return (const Color(0xFFE8E8FF), AppColors.primary);
      case 'VEGAN':
        return (const Color(0xFFE2F9F0), const Color(0xFF27AE60));
      case 'DINNER':
        return (const Color(0xFFEDE7FF), const Color(0xFF7B6FE8));
      case 'DESSERT':
        return (const Color(0xFFFFE8F0), const Color(0xFFE91E8C));
      case 'BREAKFAST':
        return (const Color(0xFFFFE8D6), const Color(0xFFE65100));
      default:
        return (const Color(0xFFF0F0F5), AppColors.textMedium);
    }
  }

  static String _badge(GeneratedRecipe r) {
    final t = r.title.toLowerCase();
    if (r.cookTimeMinutes <= 20) return 'QUICK';
    if (t.contains('vegan') || t.contains('salad') || t.contains('avocado')) return 'VEGAN';
    if (t.contains('chicken') || t.contains('beef') || t.contains('salmon')) return 'DINNER';
    if (t.contains('egg') || t.contains('pancake') || t.contains('toast')) return 'BREAKFAST';
    if (t.contains('cake') || t.contains('dessert') || t.contains('sweet')) return 'DESSERT';
    return r.difficulty.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved Recipe card
// ─────────────────────────────────────────────────────────────────────────────

class _SavedCard extends StatelessWidget {
  static const double cardWidth = 168;
  /// Image (4:3) + text block + small buffer for font metrics.
  static const double cardHeight = cardWidth * 3 / 4 + 74;

  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _SavedCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = HomeScreenState._emojiFor(recipe.title);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  recipe.imageUrl != null
                      ? Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(emoji),
                        )
                      : _imagePlaceholder(emoji),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: RecipeRatingBadge(
                      recipe: recipe,
                      accentColor: AppColors.primary,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      height: 1.15,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 13,
                        color: Color(0xFF7C7C8C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.cookTimeMinutes} min',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7C7C8C),
                          fontWeight: FontWeight.w500,
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

  Widget _imagePlaceholder(String emoji) {
    return ColoredBox(
      color: AppColors.primaryLight,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Featured card stat row item
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturedStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 12),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan option row for bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ScanOption({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, fontFamily: 'Nunito')),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
        ]),
      ),
    );
  }
}
