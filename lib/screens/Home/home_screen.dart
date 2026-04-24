import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/streak_service.dart';
import '../../models/generated_recipe.dart';
import '../../widgets/ad_banner.dart';
import '../scan/ingredient_review_screen.dart';
import '../scan/recipe_results_screen.dart';
import 'scan_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — live data: user name, streak, recent scans, recent recipes
// ─────────────────────────────────────────────────────────────────────────────

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

  String _userName = '';
  int _streak = 0;
  List<Map<String, dynamic>> _recentScans = [];
  List<GeneratedRecipe> _recentRecipes = [];
  List<GeneratedRecipe> _savedRecipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      debugPrint('🏠 HomeScreen: loading data for uid=$uid');

      // User name + streak
      final userRow = await _client
          .from('users')
          .select('email, scan_streak, last_scan_date')
          .eq('id', uid)
          .maybeSingle();
      debugPrint('🏠 userRow: $userRow');

      final email = (userRow?['email'] as String?) ??
          _client.auth.currentUser?.email ??
          '';
      final rawStreak = await StreakService.getCurrentStreak();

      // Recent scans
      final scansData = await _client
          .from('scans')
          .select('id, scan_date, status')
          .eq('user_id', uid)
          .eq('status', 'complete')
          .order('scan_date', ascending: false)
          .limit(5);
      debugPrint('🏠 scans count: ${(scansData as List).length}');

      // Recent recipes
      final recipesData = await _client
          .from('recipes')
          .select('id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(6);
      debugPrint('🏠 recipes count: ${(recipesData as List).length}');

      // Saved recipes — load from cached_data column
      final savedData = await _client
          .from('saved_recipes')
          .select('cached_data')
          .eq('user_id', uid)
          .order('saved_at', ascending: false)
          .limit(5);
      debugPrint('🏠 saved_recipes count: ${(savedData as List).length}');

      if (!mounted) return;
      setState(() {
        _userName = _firstName(email);
        _streak = rawStreak;
        _recentScans = List<Map<String, dynamic>>.from(scansData);
        _recentRecipes = _parseRecipes(recipesData);
        _savedRecipes = _parseSavedRecipes(savedData);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('🏠 HomeScreen._loadData ERROR: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _firstName(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Chef';
    // Strip trailing digits (e.g. "mehrooz123" → "Mehrooz")
    final stripped = local.replaceAll(RegExp(r'\d+$'), '');
    // If nothing left after stripping (e.g. "12345"), fall back to "Chef"
    final name = stripped.isNotEmpty ? stripped : 'Chef';
    // Capitalise first letter only, keep the rest lowercase
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  List<GeneratedRecipe> _parseRecipes(List data) {
    return data.map<GeneratedRecipe?>((r) {
      try {
        return GeneratedRecipe.fromJson(Map<String, dynamic>.from(r));
      } catch (_) {
        return null;
      }
    }).whereType<GeneratedRecipe>().toList();
  }

  List<GeneratedRecipe> _parseSavedRecipes(List data) {
    final recipes = <GeneratedRecipe>[];
    for (final item in data) {
      try {
        final cached = item['cached_data'];
        if (cached != null) {
          recipes.add(GeneratedRecipe.fromJson(Map<String, dynamic>.from(cached)));
        }
      } catch (_) {}
    }
    return recipes;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Sticky ad banner pinned to bottom (hidden for premium users) ─────────
      bottomNavigationBar: const AdBannerWidget(),
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

                // ── Streak banner (if active) ─────────────────────────
                if (_streak > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _StreakBanner(streak: _streak),
                    ),
                  ),

                // ── AI recipe summary (if recent recipes exist) ────────
                if (_recentRecipes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _AIBanner(
                        count: _recentRecipes.length,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecipeResultsScreen(
                              recipes: _recentRecipes,
                              scanId: '',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Scan CTA ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _ScanBanner(
                      onTap: () => _goToScan(),
                    ),
                  ),
                ),

                // ── Saved Recipes horizontal list ──────────────────────
                if (_savedRecipes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Saved Recipes',
                      onViewAll: () {},
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _savedRecipes.length,
                        itemBuilder: (ctx, i) =>
                            _SavedCard(recipe: _savedRecipes[i]),
                      ),
                    ),
                  ),
                ],

                // ── Recent AI Recipes ─────────────────────────────────────
                if (_recentRecipes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Recent AI Recipes',
                      onViewAll: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecipeResultsScreen(
                            recipes: _recentRecipes,
                            scanId: '',
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: _RecipeListTile(
                          recipe: _recentRecipes[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecipeResultsScreen(
                                recipes: _recentRecipes,
                                scanId: '',
                              ),
                            ),
                          ),
                        ),
                      ),
                      childCount: _recentRecipes.length,
                    ),
                  ),
                ],

                // ── Recent Scans ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Recent Scans',
                    onViewAll: () {},
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _recentScans.isEmpty
                        ? _EmptyScans(onScan: _goToScan)
                        : _RecentScansList(scans: _recentScans),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToScan() {
    // Show a bottom sheet letting the user choose between camera scan or manual entry
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Get Recipe Ideas',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito')),
              const SizedBox(height: 4),
              const Text('Scan a receipt or enter ingredients manually.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8B8B9E))),
              const SizedBox(height: 20),
              _ScanOption(
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF6C63FF),
                title: 'Scan Receipt',
                subtitle: 'Take a photo — AI reads it instantly',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, anim, __) => const ScanScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 300),
                    fullscreenDialog: true,
                  ));
                },
              ),
              const SizedBox(height: 12),
              _ScanOption(
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF4CAF50),
                title: 'Enter Manually',
                subtitle: 'Type your ingredients yourself',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const IngredientReviewScreen(
                      ingredients: [],
                      scanId: '',
                    ),
                  ));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$_greeting ',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium)),
                    Text(_greetingEmoji,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _loading ? 'Loading...' : 'Hey, $_userName!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
          _Avatar(name: _userName),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF9C8FFF)]),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'Q',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16),
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFFB300)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak-Day Scan Streak!',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                Text(
                  'Keep scanning to keep the streak alive',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$streak 🔥',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AIBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AIBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(
                child: Text('✦',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI found $count new recipes',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                  ),
                  const Text(
                    'Based on your last receipt scan',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('View',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.9),
              const Color(0xFF9C8FFF),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Text('🧾', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan a Receipt',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Nunito')),
                  Text('Turn groceries into meal ideas',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito')),
          GestureDetector(
            onTap: onViewAll,
            child: const Text('View all',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  const _SavedCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiForRecipe(recipe.title);
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              recipe.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${recipe.cookTimeMinutes} min',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  String _emojiForRecipe(String title) {
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
}

class _RecipeListTile extends StatelessWidget {
  final GeneratedRecipe recipe;
  final VoidCallback onTap;
  const _RecipeListTile({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiForRecipe(recipe.title);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 32))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      recipe.difficulty.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                  Text(
                    recipe.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Text('${recipe.cookTimeMinutes} min',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight)),
                      const SizedBox(width: 10),
                      const Icon(Icons.people_outline_rounded,
                          size: 12, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Text('${recipe.servings} servings',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  String _emojiForRecipe(String title) {
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
}

class _RecentScansList extends StatelessWidget {
  final List<Map<String, dynamic>> scans;
  const _RecentScansList({required this.scans});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: scans.map((scan) {
        final scanDate = scan['scan_date'] as String? ?? '';
        final date = scanDate.isNotEmpty
            ? DateTime.tryParse(scanDate)
            : null;
        final dateStr = date != null
            ? '${date.day}/${date.month}/${date.year}'
            : 'Unknown date';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6)
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                    child: Text('🧾',
                        style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Receipt Scan',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4CAF50))),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyScans extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyScans({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text('🧾', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('No scans yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito')),
          const SizedBox(height: 6),
          const Text(
            'Scan your first grocery receipt and let QUILLO work its AI magic on your meals.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                height: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onScan,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('+ Scan First Receipt',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan option row used in the _goToScan bottom sheet ────────────────────────

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ScanOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

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
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontFamily: 'Nunito')),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
