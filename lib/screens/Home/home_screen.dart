import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/streak_service.dart';
import '../../models/generated_recipe.dart';
import '../../widgets/ad_banner.dart';
import '../scan/ingredient_review_screen.dart';
import '../scan/recipe_detail_page.dart';
import 'all_recipes_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  String _userName = '';
  int _streak = 0;
  List<Map<String, dynamic>> _recentScans = [];
  List<GeneratedRecipe> _recentRecipes = [];
  List<GeneratedRecipe> _savedRecipes = [];
  bool _loading = true;
  String _selectedCategory = 'All';
  final _categories = ['All', 'Quick', 'Breakfast', 'Lunch', 'Dinner', 'Vegan'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final userRow = await _client
          .from('users')
          .select('email, scan_streak, last_scan_date')
          .eq('id', uid)
          .maybeSingle();
      final email = (userRow?['email'] as String?) ?? _client.auth.currentUser?.email ?? '';
      final rawStreak = await StreakService.getCurrentStreak();

      final scansData = await _client
          .from('scans').select('id, scan_date, status')
          .eq('user_id', uid).eq('status', 'complete')
          .order('scan_date', ascending: false).limit(5);

      final recipesData = await _client
          .from('recipes')
          .select('id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url')
          .eq('user_id', uid)
          .order('created_at', ascending: false).limit(10);

      final savedData = await _client
          .from('saved_recipes').select('cached_data')
          .eq('user_id', uid)
          .order('saved_at', ascending: false).limit(6);

      if (!mounted) return;
      setState(() {
        _userName = _firstName(email);
        _streak = rawStreak;
        _recentScans = List<Map<String, dynamic>>.from(scansData);
        _recentRecipes = _parseRecipes(recipesData);
        _savedRecipes = _parseSavedRecipes(savedData);
        _loading = false;
      });
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

  List<GeneratedRecipe> _parseRecipes(List data) => data
      .map<GeneratedRecipe?>((r) {
        try { return GeneratedRecipe.fromJson(Map<String, dynamic>.from(r)); }
        catch (_) { return null; }
      }).whereType<GeneratedRecipe>().toList();

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

  List<GeneratedRecipe> get _filtered {
    if (_selectedCategory == 'All') return _recentRecipes;
    return _recentRecipes.where((r) {
      final t = r.title.toLowerCase();
      switch (_selectedCategory) {
        case 'Quick': return r.cookTimeMinutes <= 20;
        case 'Breakfast': return t.contains('egg') || t.contains('pancake') || t.contains('toast') || t.contains('omelette');
        case 'Lunch': return t.contains('salad') || t.contains('soup') || t.contains('sandwich') || t.contains('wrap');
        case 'Dinner': return t.contains('chicken') || t.contains('beef') || t.contains('pasta') || t.contains('steak') || t.contains('salmon');
        case 'Vegan': return t.contains('vegan') || t.contains('salad') || t.contains('tofu') || t.contains('avocado') || t.contains('lentil');
        default: return true;
      }
    }).toList();
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
              _ScanOption(icon: Icons.qr_code_scanner_rounded, color: AppColors.primary, title: 'Scan Receipt', subtitle: 'Take a photo — AI reads it instantly', onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(PageRouteBuilder(
                  pageBuilder: (_, anim, __) => const ScanScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 300),
                  fullscreenDialog: true,
                ));
              }),
              const SizedBox(height: 12),
              _ScanOption(icon: Icons.edit_note_rounded, color: const Color(0xFF4CAF50), title: 'Enter Manually', subtitle: 'Type your ingredients yourself', onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IngredientReviewScreen(ingredients: [], scanId: '')));
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
      backgroundColor: const Color(0xFFF4F5FA),
      bottomNavigationBar: const AdBannerWidget(),
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

              // ── Search bar ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildSearchBar()),

              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else ...[
                // ── Featured Recipe ──────────────────────────────────────
                if (_recentRecipes.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader('Featured Recipe', 'View all', onTap: () => _goToAllRecipes())),
                  SliverToBoxAdapter(child: _buildFeaturedCard()),
                ],

                // ── AI Banner ────────────────────────────────────────────
                if (_recentRecipes.isNotEmpty)
                  SliverToBoxAdapter(child: _buildAIBanner()),

                // ── Categories ───────────────────────────────────────────
                SliverToBoxAdapter(child: _buildCategories()),

                // ── Suggested for You ────────────────────────────────────
                SliverToBoxAdapter(
                  child: _sectionHeader('Suggested for You', 'See all', onTap: () => _goToAllRecipes()),
                ),
                if (_filtered.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyRecipes())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _SuggestedTile(
                        recipe: _filtered[i],
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
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_greeting ${DateTime.now().hour < 12 ? "☀️" : DateTime.now().hour < 17 ? "🌤️" : "🌙"}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMedium, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Hey, $_userName!',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
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
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
            child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textDark),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF9C8FFF)]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search ${_recentRecipes.length + 1200}+ recipes...',
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Featured Recipe ──────────────────────────────────────────────────────────

  Widget _buildFeaturedCard() {
    final recipe = _recentRecipes[DateTime.now().day % _recentRecipes.length];
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
                // Background
                recipe.imageUrl != null
                    ? Image.network(recipe.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A2E),
                            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 80)))))
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 80))),
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
                  top: 14, left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 11),
                      SizedBox(width: 4),
                      Text("AI Pick", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                Positioned(
                  top: 14, right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.timer_outlined, color: Colors.white, size: 11),
                      const SizedBox(width: 4),
                      Text('${recipe.cookTimeMinutes} min', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
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
                      Row(children: [
                        _FeaturedStat(icon: Icons.people_outline_rounded, label: '${recipe.servings} srv'),
                        const SizedBox(width: 12),
                        _FeaturedStat(icon: Icons.bar_chart_rounded, label: recipe.difficulty),
                        const SizedBox(width: 12),
                        _FeaturedStat(icon: Icons.local_fire_department_outlined, label: '${recipe.nutrition.calories} cal'),
                      ]),
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
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFFFFCC02).withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI found ${_recentRecipes.length} new recipes',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 2),
              const Text('Based on your last recipe scan', style: TextStyle(fontSize: 11, color: AppColors.textMedium)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFF9800), borderRadius: BorderRadius.circular(20)),
            child: const Text('Explore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
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
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.chipBorder),
                  ),
                  child: Text(cat,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textMedium)),
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
        child: const Column(children: [
          Text('🍽️', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text('No recipes yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          SizedBox(height: 4),
          Text('Scan a receipt to get AI-generated recipes!',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
        ]),
      ),
    );
  }

  // ── Saved scroll ─────────────────────────────────────────────────────────────

  Widget _buildSavedScroll() {
    return SizedBox(
      height: 145,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _savedRecipes.length,
        itemBuilder: (ctx, i) => _SavedCard(recipe: _savedRecipes[i], onTap: () => _openRecipe(_savedRecipes[i])),
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF9C8FFF)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scan a Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito')),
                SizedBox(height: 2),
                Text('Get AI meal ideas from your groceries', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
            ),
          ]),
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
            child: const Center(child: Text('🧾', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 14),
          const Text('No scans yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
          const SizedBox(height: 6),
          const Text('Scan your first grocery receipt and let\nQuillo work its magic on your meals.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.5)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _goToScan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Scan First Receipt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
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
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onTap,
            child: Text(action, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
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

class _SuggestedTile extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _SuggestedTile({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _diffColor(recipe.difficulty);
    final badge = _badge(recipe);
    final emoji = _HomeScreenState._emojiFor(recipe.title);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80, height: 80,
              child: recipe.imageUrl != null
                  ? Image.network(recipe.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: color.withValues(alpha: 0.12),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
                      ))
                  : Container(
                      color: color.withValues(alpha: 0.12),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 5),
              Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.3)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 12, color: AppColors.textLight),
                const SizedBox(width: 3),
                Text('${recipe.cookTimeMinutes} min', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                const SizedBox(width: 10),
                const Icon(Icons.people_outline_rounded, size: 12, color: AppColors.textLight),
                const SizedBox(width: 3),
                Text('${recipe.servings} servings', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          // Bookmark
          Icon(Icons.bookmark_border_rounded, size: 20, color: AppColors.textLight),
        ]),
      ),
    );
  }

  static Color _diffColor(String d) {
    switch (d.toLowerCase()) {
      case 'easy': return const Color(0xFF4CAF50);
      case 'hard': return const Color(0xFFE53935);
      default: return const Color(0xFFFF9800);
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
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _SavedCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = _HomeScreenState._emojiFor(recipe.title);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 115,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 75, width: double.infinity,
              child: recipe.imageUrl != null
                  ? Image.network(recipe.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primaryLight,
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
                      ))
                  : Container(
                      color: AppColors.primaryLight,
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark, height: 1.3)),
              const SizedBox(height: 3),
              Text('${recipe.cookTimeMinutes} min', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
            ]),
          ),
        ]),
      ),
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
