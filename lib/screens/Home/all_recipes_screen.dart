import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../scan/recipe_detail_page.dart';
import '../scan/recipe_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AllRecipesScreen — loads every recipe the user has ever generated
// ─────────────────────────────────────────────────────────────────────────────

class AllRecipesScreen extends StatefulWidget {
  const AllRecipesScreen({super.key});
  @override
  State<AllRecipesScreen> createState() => _AllRecipesScreenState();
}

class _AllRecipesScreenState extends State<AllRecipesScreen> {
  final _client = Supabase.instance.client;
  List<GeneratedRecipe> _recipes = [];
  List<GeneratedRecipe> _filtered = [];
  final Set<String> _savedIds = {};
  bool _loading = true;
  String _selectedFilter = 'All';
  final _searchCtrl = TextEditingController();
  final _filters = ['All', 'Quick', 'Dinner', 'Lunch', 'Breakfast', 'Vegan', 'Dessert'];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final data = await _client
          .from('recipes')
          .select('id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final savedData = await _client
          .from('saved_recipes').select('recipe_id')
          .eq('user_id', uid);

      if (!mounted) return;
      final recipes = (data as List).map<GeneratedRecipe?>((r) {
        try { return GeneratedRecipe.fromJson(Map<String, dynamic>.from(r)); }
        catch (_) { return null; }
      }).whereType<GeneratedRecipe>().toList();

      setState(() {
        _recipes = recipes;
        _savedIds.addAll((savedData as List).map((s) => s['recipe_id'] as String? ?? '').where((s) => s.isNotEmpty));
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _recipes.where((r) {
        final matchSearch = q.isEmpty || r.title.toLowerCase().contains(q);
        if (!matchSearch) return false;
        switch (_selectedFilter) {
          case 'All': return true;
          case 'Quick': return r.cookTimeMinutes <= 20;
          case 'Dinner':
            final t = r.title.toLowerCase();
            return t.contains('chicken') || t.contains('beef') || t.contains('salmon') || t.contains('pasta') || t.contains('steak');
          case 'Lunch':
            final t = r.title.toLowerCase();
            return t.contains('salad') || t.contains('soup') || t.contains('sandwich') || t.contains('bowl');
          case 'Breakfast':
            final t = r.title.toLowerCase();
            return t.contains('egg') || t.contains('pancake') || t.contains('toast') || t.contains('omelette') || t.contains('smoothie');
          case 'Vegan':
            final t = r.title.toLowerCase();
            return t.contains('vegan') || t.contains('salad') || t.contains('tofu') || t.contains('avocado') || t.contains('lentil');
          case 'Dessert':
            final t = r.title.toLowerCase();
            return t.contains('cake') || t.contains('dessert') || t.contains('sweet') || t.contains('mousse');
          default: return true;
        }
      }).toList();
    });
  }

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

  void _openRecipe(GeneratedRecipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GeneratedRecipeDetailPage(recipe: recipe, accentColor: AppColors.primary),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_filtered.isEmpty)
              _buildEmpty()
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadRecipes,
                  color: AppColors.primary,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final recipe = _filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: RecipeListCard(
                          recipe: recipe,
                          isSaved: _savedIds.contains(recipe.id),
                          onTap: () => _openRecipe(recipe),
                          onSave: () => _toggleSave(recipe),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Recipes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
              Text('${_recipes.length} AI-generated recipes',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
            child: Text('${_filtered.length} shown',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.textLight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: const InputDecoration(
                hintText: 'Search your recipes...',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textLight),
                border: InputBorder.none, contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () { _searchCtrl.clear(); _applyFilter(); },
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.textLight),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final sel = f == _selectedFilter;
          return GestureDetector(
            onTap: () { setState(() => _selectedFilter = f); _applyFilter(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.chipBorder),
              ),
              child: Text(f,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.textMedium)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Expanded(
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🍽️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(_searchCtrl.text.isNotEmpty ? 'No results for "${_searchCtrl.text}"' : 'No recipes in this category',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text('Try a different filter or scan a receipt',
              style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
        ]),
      ),
    );
  }
}
