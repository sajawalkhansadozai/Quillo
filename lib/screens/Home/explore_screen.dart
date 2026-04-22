import 'package:flutter/material.dart';
import 'package:quillo/models/recipe_model.dart';
import 'package:quillo/theme/app_theme.dart';
import 'recipe_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  String _selectedCategory = 'All';
  final _searchController = TextEditingController();
  bool _isSearchFocused = false;

  final List<String> _categories = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'];

  final List<_CollectionData> _collections = const [
    _CollectionData(title: 'Italian Classics', emoji: '🍝', color: Color(0xFFE53935), recipeCount: 24),
    _CollectionData(title: 'Street Food', emoji: '🌮', color: Color(0xFFFF9800), recipeCount: 18),
    _CollectionData(title: 'Plant Based', emoji: '🌱', color: Color(0xFF4CAF50), recipeCount: 32),
  ];

  final List<_ExploreRecipe> _trending = const [
    _ExploreRecipe(name: 'Lemon Butter Past', emoji: '🍝', tag: 'ITALIAN', rating: 4.8, time: 20, color: Color(0xFFFF9800)),
    _ExploreRecipe(name: 'Avocado Buddha Bowl', emoji: '🥗', tag: 'VEGAN', rating: 4.9, time: 15, color: Color(0xFF4CAF50)),
    _ExploreRecipe(name: 'Chicken Tikka Masala', emoji: '🍛', tag: 'DINNER', rating: 4.9, time: 45, color: Color(0xFFE91E63)),
    _ExploreRecipe(name: 'Strawberry Mousse', emoji: '🍓', tag: 'VEGAN', rating: 4.6, time: 30, color: Color(0xFFE91E63)),
    _ExploreRecipe(name: 'Garlic Mashed Potato', emoji: '🥔', tag: 'COMFORT', rating: 4.7, time: 25, color: Color(0xFFFF9800)),
    _ExploreRecipe(name: 'Tomato Bruschetta', emoji: '🍅', tag: 'STARTER', rating: 4.5, time: 10, color: Color(0xFFE53935)),
  ];

  final List<_ExploreRecipe> _quickEasy = const [
    _ExploreRecipe(name: 'Carrot Ginger Soup', emoji: '🥕', tag: 'QUICK', rating: 4.5, time: 15, color: Color(0xFFFF9800)),
    _ExploreRecipe(name: 'Spring Salad', emoji: '🥗', tag: 'EASY', rating: 4.4, time: 10, color: Color(0xFF4CAF50)),
    _ExploreRecipe(name: 'Fluffy Pancakes', emoji: '🥞', tag: 'BREAKFAST', rating: 4.8, time: 20, color: Color(0xFFFF9800)),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DISCOVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textLight, letterSpacing: 1.4)),
                            const SizedBox(height: 2),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(fontFamily: 'Nunito'),
                                children: [
                                  TextSpan(text: 'Explore', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                                  TextSpan(text: ' 🌍', style: TextStyle(fontSize: 24)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _NotifBell(),
                      const SizedBox(width: 10),
                      _FilterButton(),
                    ],
                  ),
                ),
              ),

              // ── Search ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _ExploreSearchBar(controller: _searchController),
                ),
              ),

              // ── Category chips ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _CategoryRow(
                  categories: _categories,
                  selected: _selectedCategory,
                  onSelect: (c) => setState(() => _selectedCategory = c),
                ),
              ),

              // ── Featured Today ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Featured Today', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                      GestureDetector(
                        onTap: () {},
                        child: Text('Refresh', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _FeaturedTodayCard(recipe: RecipeModel.featured),
                ),
              ),

              // ── Collections ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Collections', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                      Text('See all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _collections.length,
                    itemBuilder: (ctx, i) => _CollectionCard(data: _collections[i]),
                  ),
                ),
              ),

              // ── Trending Now ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Text('Trending Now', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                        const SizedBox(width: 6),
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                      ]),
                      Text('See all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _trending.map((r) => _TrendingCard(recipe: r)).toList(),
                  ),
                ),
              ),

              // ── Quick & Easy ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Text('Quick & Easy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                        const SizedBox(width: 6),
                        const Text('⚡', style: TextStyle(fontSize: 16)),
                      ]),
                      Text('See all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 145,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _quickEasy.length,
                    itemBuilder: (ctx, i) => _QuickCard(recipe: _quickEasy[i]),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _CollectionData {
  final String title;
  final String emoji;
  final Color color;
  final int recipeCount;
  const _CollectionData({required this.title, required this.emoji, required this.color, required this.recipeCount});
}

class _ExploreRecipe {
  final String name;
  final String emoji;
  final String tag;
  final double rating;
  final int time;
  final Color color;
  const _ExploreRecipe({required this.name, required this.emoji, required this.tag, required this.rating, required this.time, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NotifBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
          child: const Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.textDark),
        ),
        Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5252), shape: BoxShape.circle))),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
      child: const Icon(Icons.tune_rounded, size: 20, color: AppColors.textDark),
    );
  }
}

class _ExploreSearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _ExploreSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.textLight, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Recipes, cuisines, ingredients',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.mic_rounded, size: 16, color: AppColors.primary),
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
  const _CategoryRow({required this.categories, required this.selected, required this.onSelect});

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
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.chipBorder),
              ),
              child: Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textMedium)),
            ),
          );
        },
      ),
    );
  }
}

class _FeaturedTodayCard extends StatelessWidget {
  final RecipeModel recipe;
  const _FeaturedTodayCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned(right: 16, top: 16, child: Text(recipe.emoji, style: const TextStyle(fontSize: 70))),
            Positioned(
              top: 14, left: 14,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)), child: const Text("Editor's Pick", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
            ),
            Positioned(
              top: 14, right: 14,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)), child: Text('${recipe.time} min', style: const TextStyle(fontSize: 11, color: Colors.white))),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.7)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.cuisine.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700, letterSpacing: 1)),
                    Text(recipe.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito')),
                    Row(children: [
                      const Icon(Icons.star_rounded, color: AppColors.accent, size: 12),
                      const SizedBox(width: 4),
                      Text('${recipe.rating}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Text('(${recipe.reviews})', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
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

class _CollectionCard extends StatelessWidget {
  final _CollectionData data;
  const _CollectionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(right: 8, bottom: 8, child: Text(data.emoji, style: const TextStyle(fontSize: 32))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COLLECTION', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(data.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Nunito')),
                Text('${data.recipeCount} recipes', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final _ExploreRecipe recipe;
  const _TrendingCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: recipe.color.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
              child: Center(child: Text(recipe.emoji, style: const TextStyle(fontSize: 36))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: recipe.color, letterSpacing: 0.8)),
                Text(recipe.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  const Icon(Icons.star_rounded, color: AppColors.accent, size: 11),
                  const SizedBox(width: 2),
                  Text('${recipe.rating}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
                  const SizedBox(width: 6),
                  const Icon(Icons.timer_outlined, size: 10, color: AppColors.textLight),
                  const SizedBox(width: 2),
                  Text('${recipe.time}m', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final _ExploreRecipe recipe;
  const _QuickCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: recipe.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(child: Text(recipe.emoji, style: const TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(recipe.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.star_rounded, color: AppColors.accent, size: 11),
            const SizedBox(width: 2),
            Text('${recipe.rating}', style: const TextStyle(fontSize: 10, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}
