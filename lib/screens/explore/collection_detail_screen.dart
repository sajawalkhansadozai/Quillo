import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/generated_recipe.dart';
import '../scan/recipe_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CollectionDetailScreen — shows user's recipes matching a collection's keywords
// ─────────────────────────────────────────────────────────────────────────────

class CollectionDetailScreen extends StatefulWidget {
  final String title;
  final String emoji;
  final Color color;
  /// Title keywords to match (case-insensitive). Empty = filter by quick time.
  final List<String> keywords;
  /// If true, filter by cook_time_minutes <= 20 instead of keywords.
  final bool quickOnly;

  const CollectionDetailScreen({
    super.key,
    required this.title,
    required this.emoji,
    required this.color,
    this.keywords = const [],
    this.quickOnly = false,
  });

  @override
  State<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final _client = Supabase.instance.client;
  List<GeneratedRecipe> _recipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      var query = _client
          .from('recipes')
          .select(
              'id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url')
          .eq('user_id', uid);

      if (widget.quickOnly) {
        // Quick Bites — cook time ≤ 20 minutes
        query = query.lte('cook_time_minutes', 20);
      } else if (widget.keywords.isNotEmpty) {
        // Match any keyword in the title (case-insensitive)
        final orFilter =
            widget.keywords.map((k) => 'title.ilike.%$k%').join(',');
        query = query.or(orFilter);
      }

      final data = await query
          .order('created_at', ascending: false)
          .limit(50);

      final recipes = (data as List)
          .map<GeneratedRecipe?>((r) {
            try {
              return GeneratedRecipe.fromJson(
                  Map<String, dynamic>.from(r));
            } catch (_) {
              return null;
            }
          })
          .whereType<GeneratedRecipe>()
          .toList();

      if (mounted) {
        setState(() {
          _recipes = recipes;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('CollectionDetailScreen error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header ──────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHero(context)),

          // ── Count badge ───────────────────────────────────────────────
          if (!_loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  '${_recipes.length} recipe${_recipes.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

          // ── Loading ───────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )

          // ── Empty state ───────────────────────────────────────────────
          else if (_recipes.isEmpty)
            SliverFillRemaining(child: _buildEmpty())

          // ── Recipe grid ───────────────────────────────────────────────
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RecipeTile(
                    recipe: _recipes[i],
                    accentColor: widget.color,
                    onTap: () => _openRecipe(_recipes[i]),
                  ),
                  childCount: _recipes.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openRecipe(GeneratedRecipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GeneratedRecipeDetailPage(
        recipe: recipe,
        accentColor: widget.color,
      ),
    ));
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Background large emoji
          Positioned(
            right: 20,
            bottom: 20,
            child: Opacity(
              opacity: 0.25,
              child: Text(widget.emoji,
                  style: const TextStyle(fontSize: 110)),
            ),
          ),
          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
          // Title
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COLLECTION',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Nunito')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('No ${widget.title} recipes yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito')),
            const SizedBox(height: 8),
            Text(
              'Scan a grocery receipt and generate some recipes — they\'ll appear here automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RecipeTile — grid card used inside the collection
// ─────────────────────────────────────────────────────────────────────────────

class _RecipeTile extends StatelessWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;
  final VoidCallback onTap;
  const _RecipeTile(
      {required this.recipe,
      required this.accentColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiFor(recipe.title);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or emoji header
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: recipe.imageUrl != null
                    ? Image.network(
                        recipe.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accentColor.withValues(alpha: 0.1),
                          child: Center(
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 44))),
                        ),
                      )
                    : Container(
                        color: accentColor.withValues(alpha: 0.1),
                        child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 44))),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          height: 1.3)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(recipe.difficulty,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: accentColor)),
                    ),
                    const Spacer(),
                    const Icon(Icons.timer_outlined,
                        size: 11, color: AppColors.textLight),
                    const SizedBox(width: 2),
                    Text('${recipe.cookTimeMinutes}m',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emojiFor(String title) {
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
    if (t.contains('mushroom')) return '🍄';
    if (t.contains('ramen') || t.contains('noodle')) return '🍜';
    if (t.contains('taco') || t.contains('burrito')) return '🌮';
    if (t.contains('shrimp') || t.contains('prawn')) return '🍤';
    if (t.contains('bread') || t.contains('toast')) return '🍞';
    if (t.contains('pancake')) return '🥞';
    return '🍽️';
  }
}
