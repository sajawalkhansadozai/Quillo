import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/generated_recipe.dart';
import '../../services/recipe_service.dart';
import '../../services/local_db_service.dart';
import '../../services/shopping_list_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/recipe_image_source.dart';
import '../../widgets/ingredient_visual_icon.dart';
import '../../widgets/recipe_rating_section.dart';
import '../../widgets/recipe_rating_badge.dart';
import '../../widgets/recipe_rating_sheet.dart';
import '../../services/recipe_rating_service.dart';
import '../../widgets/ad_banner.dart';
import '../cooking/cooking_mode_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GeneratedRecipeDetailPage — full-screen detail view matching design reference
// ─────────────────────────────────────────────────────────────────────────────

class GeneratedRecipeDetailPage extends StatefulWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;

  const GeneratedRecipeDetailPage({
    super.key,
    required this.recipe,
    required this.accentColor,
  });

  @override
  State<GeneratedRecipeDetailPage> createState() =>
      _GeneratedRecipeDetailPageState();
}

class _GeneratedRecipeDetailPageState
    extends State<GeneratedRecipeDetailPage> {
  static const _heroHeight = 300.0;
  static const _navHideStart = 20.0;
  static const _navHideEnd = 110.0;

  bool _isSaved = false;
  bool _checkingStatus = true;
  bool _hydratingExternal = false;
  bool _generatingInstructions = false;
  bool _saveInProgress = false;
  late GeneratedRecipe _recipe;
  int _servings = 2;
  int _ratingRevision = 0;
  int? _userRating;
  bool _userRatingLoading = true;
  final Set<int> _checkedIngredients = {};
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _recipe = _reconcileCookTime(widget.recipe);
    _servings = _recipe.servings;
    _scrollController.addListener(_onScroll);
    _initSavedStatus();
    _loadUserRating();
    if (_needsExternalHydration) {
      _hydrateExternalRecipe();
    } else {
      if (_needsProviderImageUpgrade) _upgradeProviderImageIfNeeded();
      if (_recipe.needsGeneratedInstructions) {
        _generateInstructionsIfNeeded();
      }
    }
  }

  Future<void> _loadUserRating() async {
    final rating = await RecipeRatingService.getRating(_recipe);
    if (!mounted) return;
    setState(() {
      _userRating = rating;
      _userRatingLoading = false;
    });
  }

  void _applyRatingResult(RecipeRatingResult result) {
    setState(() {
      _userRating = result.rating;
      if (result.recipe.id != _recipe.id) {
        _recipe = result.recipe;
      }
      _ratingRevision++;
    });
  }

  Future<void> _editRating(GeneratedRecipe recipe, Color color) async {
    final result = await showRecipeRatingSheet(
      context,
      recipe: recipe,
      accentColor: color,
      isEdit: true,
    );
    if (!mounted || result == null) return;
    _applyRatingResult(result);
  }

  /// Refetch from Edamam only when search did not already persist full recipe data.
  bool get _needsExternalHydration =>
      _recipe.externalId != null &&
      _recipe.externalSource != null &&
      (_recipe.id == null || _recipe.ingredientsUsed.isEmpty);

  /// DB or API rows with provider or legacy AI thumbnails — upgrade via edge function.
  bool get _needsProviderImageUpgrade {
    final url = _recipe.imageUrl;
    if (url == null || url.isEmpty) return false;
    if (url.contains('/recipe-images/')) return false;
    return isSupabaseRecipeId(_recipe.id) ||
        (_recipe.externalSource != null && _recipe.externalId != null);
  }

  Future<void> _upgradeProviderImageIfNeeded() async {
    final upgraded = await RecipeService.fetchExternalRecipe(
      source: _recipe.externalSource,
      sourceId: _recipe.externalId,
      recipeId: _recipe.id,
    );
    if (!mounted || upgraded == null) return;
    final newUrl = upgraded.imageUrl;
    if (newUrl == null || newUrl == _recipe.imageUrl) return;
    setState(() => _recipe = _recipe.copyWith(imageUrl: newUrl));
  }

  Future<void> _hydrateExternalRecipe() async {
    final source = _recipe.externalSource;
    final sourceId = _recipe.externalId;
    if (source == null || sourceId == null) return;

    setState(() => _hydratingExternal = true);
    final full = await RecipeService.fetchExternalRecipe(
      source: source,
      sourceId: sourceId,
    );
    if (!mounted) return;

    if (full != null) {
      setState(() {
        _recipe = _reconcileCookTime(full);
        _servings = full.servings;
        _hydratingExternal = false;
      });
      await _initSavedStatus();
      if (full.needsGeneratedInstructions) {
        await _generateInstructionsIfNeeded();
      }
    } else {
      setState(() => _hydratingExternal = false);
      // Search may already have returned enough data to display the recipe.
      if (_recipe.ingredientsUsed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load this recipe. Check your connection and try again.'),
          ),
        );
      } else if (_recipe.needsGeneratedInstructions) {
        await _generateInstructionsIfNeeded();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if ((offset - _scrollOffset).abs() < 0.5) return;
    setState(() => _scrollOffset = offset);
  }

  double get _navHideT {
    if (_scrollOffset <= _navHideStart) return 0;
    if (_scrollOffset >= _navHideEnd) return 1;
    return Curves.easeInOut.transform(
      (_scrollOffset - _navHideStart) / (_navHideEnd - _navHideStart),
    );
  }

  GeneratedRecipe _reconcileCookTime(GeneratedRecipe recipe) {
    final effective = recipe.effectiveCookTimeMinutes;
    if (effective != recipe.cookTimeMinutes) {
      return recipe.copyWith(cookTimeMinutes: effective);
    }
    return recipe;
  }

  Future<void> _generateInstructionsIfNeeded() async {
    if (!_recipe.needsGeneratedInstructions || _generatingInstructions) return;

    setState(() => _generatingInstructions = true);
    final result = await RecipeService.generateInstructions(_recipe);
    if (!mounted) return;

    if (result != null && result.steps.isNotEmpty) {
      setState(() {
        _recipe = _reconcileCookTime(
          _recipe.copyWith(
            steps: result.steps,
            cookTimeMinutes: result.cookTimeMinutes ?? _recipe.cookTimeMinutes,
          ),
        );
        _generatingInstructions = false;
      });
    } else {
      setState(() => _generatingInstructions = false);
    }
  }

  Future<void> _initSavedStatus() async {
    if (_recipe.id != null) {
      final saved = await RecipeService.isRecipeSaved(_recipe.id!);
      if (mounted) setState(() {
        _isSaved = saved;
        _checkingStatus = false;
      });
    } else {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _addToShoppingList(GeneratedRecipe recipe) async {
    try {
      final hadExisting = recipe.id != null &&
          (await ShoppingListService.getAll())
              .any((l) => l.recipeId == recipe.id);
      await ShoppingListService.saveFromRecipe(recipe);
      if (!mounted) return;
      final wasUpdate = hadExisting;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasUpdate
                ? 'Shopping list updated for "${recipe.title}"'
                : 'Added "${recipe.title}" to your shopping list',
          ),
          backgroundColor: widget.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save shopping list. Try again.')),
      );
    }
  }

  Future<void> _openCookingMode(GeneratedRecipe recipe, Color color) async {
    if (recipe.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This recipe has no cooking steps yet.'),
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CookingModeScreen(recipe: recipe, accentColor: color),
      ),
    );
    if (!mounted) return;
    await _loadUserRating();
    setState(() => _ratingRevision++);
  }

  Future<void> _toggleSave() async {
    if (_saveInProgress) return;

    setState(() => _saveInProgress = true);
    var recipe = _recipe;

    if (recipe.id == null) {
      final persisted = await RecipeService.ensureRecipePersisted(recipe);
      if (!mounted) return;
      if (persisted?.id == null) {
        setState(() => _saveInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recipe is still loading. Wait a moment, then try saving again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      recipe = persisted!;
      setState(() => _recipe = recipe);
    }

    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !wasSaved;
      _saveInProgress = false;
    });

    final ok = wasSaved
        ? await RecipeService.unsaveRecipe(recipe.id!)
        : await RecipeService.saveRecipe(recipe);

    if (!mounted) return;

    if (!ok) {
      setState(() => _isSaved = wasSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update saved recipes. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!wasSaved) {
      await LocalDbService.cacheRecipe(recipe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${recipe.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await LocalDbService.removeRecipe(recipe.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    final displayRecipe = recipe.scaledToServings(_servings);
    final color = widget.accentColor;
    final cookMins = recipe.effectiveCookTimeMinutes;

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          if (_hydratingExternal)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(recipe, color)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildTitleTags(recipe),
                      ),
                      const SizedBox(height: 10),
                      // Title
                      Text(recipe.title,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                              fontFamily: 'Nunito',
                              height: 1.2)),
                      const SizedBox(height: 8),
                      // Quick meta row
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: AppColors.textMedium),
                          const SizedBox(width: 3),
                          Text('$cookMins min total',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                          const SizedBox(width: 12),
                          const Icon(Icons.people_outline_rounded,
                              size: 13, color: AppColors.textMedium),
                          const SizedBox(width: 3),
                          Text('$_servings servings',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                          const SizedBox(width: 12),
                          const Icon(Icons.local_fire_department_outlined,
                              size: 13, color: AppColors.textMedium),
                          const SizedBox(width: 3),
                          Text('${recipe.nutrition.calories} cal',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMedium)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _StatBox(
                        asset: _RecipeDetailAssets.cookTime,
                        value: '$cookMins min',
                        label: 'Cook time',
                      ),
                      const SizedBox(width: 8),
                      _StatBox(
                        asset: _RecipeDetailAssets.calories,
                        value: '${recipe.nutrition.calories} cal',
                        label: 'Per serving',
                      ),
                      const SizedBox(width: 8),
                      _StatBox(
                        asset: _RecipeDetailAssets.servings,
                        value: '$_servings',
                        label: 'Servings',
                      ),
                      const SizedBox(width: 8),
                      _StatBox(
                        asset: _RecipeDetailAssets.difficulty,
                        value: recipe.difficultyLabel,
                        label: 'Difficulty',
                      ),
                    ],
                  ),
                ),
              ),

              if (!_userRatingLoading && _userRating == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: RecipeRatingSection(
                      key: ValueKey(
                        'rating:${RecipeRatingService.cacheKeyFor(recipe)}:$_ratingRevision',
                      ),
                      recipe: recipe,
                      accentColor: color,
                      showCommunitySummary: false,
                      onRated: _applyRatingResult,
                    ),
                  ),
                )
              else if (_userRating != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _editRating(recipe, color),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Change your rating',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ingredients',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                              fontFamily: 'Nunito')),
                      Row(
                        children: [
                          _CounterBtn(
                            icon: Icons.remove_rounded,
                            onTap: () {
                              if (_servings > 1) setState(() => _servings--);
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '$_servings',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          _CounterBtn(
                            icon: Icons.add_rounded,
                            onTap: () => setState(() => _servings++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.15,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _IngredientTile(
                      item: displayRecipe.ingredientsUsed[i],
                      checked: _checkedIngredients.contains(i),
                      onCheckChanged: (v) {
                        setState(() {
                          if (v) {
                            _checkedIngredients.add(i);
                          } else {
                            _checkedIngredients.remove(i);
                          }
                        });
                      },
                    ),
                    childCount: displayRecipe.ingredientsUsed.length,
                  ),
                ),
              ),

              // ── Missing Ingredients ───────────────────────────────────────
              if (displayRecipe.missingIngredients.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _MissingIngredientsCard(
                      items: displayRecipe.missingIngredients,
                      color: color,
                      onAddToList: () => _addToShoppingList(displayRecipe),
                    ),
                  ),
                ),

              if (displayRecipe.missingIngredients.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: GestureDetector(
                      onTap: () => _addToShoppingList(displayRecipe),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: color),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '+ Add to Shopping List',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Instructions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Video mode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_generatingInstructions)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _StepCard(
                        step: recipe.steps[i],
                        accentColor: color,
                      ),
                      childCount: recipe.steps.length,
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Nutrition per serving',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {},
                            child: const Text(
                              'Full info',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _NutBox(
                            value: '${recipe.nutrition.calories} kcal',
                            label: 'Calories',
                          ),
                          const SizedBox(width: 8),
                          _NutBox(
                            value: '${recipe.nutrition.carbs} g',
                            label: 'Carbs',
                          ),
                          const SizedBox(width: 8),
                          _NutBox(
                            value: '${recipe.nutrition.protein} g',
                            label: 'Protein',
                          ),
                          const SizedBox(width: 8),
                          _NutBox(
                            value: '${recipe.nutrition.fat} g',
                            label: 'Fat',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 170)),
            ],
          ),

          _buildFloatingNav(recipe, color, topInset),

          if (_navHideT > 0.85)
            Positioned(
              top: topInset + 8,
              left: 16,
              child: IgnorePointer(
                ignoring: _navHideT < 0.95,
                child: Opacity(
                  opacity: ((_navHideT - 0.85) / 0.15).clamp(0.0, 1.0),
                  child: _HeroBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

          // ── Sticky bottom CTA + free-tier banner (3.3) ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, -4))
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _openCookingMode(displayRecipe, color),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.chipBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              color: AppColors.textDark,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openCookingMode(displayRecipe, color),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color,
                                    color.withValues(alpha: 0.72),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Cooking',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontFamily: 'Nunito',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Below Start Cooking — free users only (pro hides automatically)
                  const AdBannerWidget(safeArea: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero image builder ──────────────────────────────────────────────────────

  Widget _buildFloatingNav(
    GeneratedRecipe recipe,
    Color color,
    double topInset,
  ) {
    final opacity = (1 - _navHideT).clamp(0.0, 1.0);
    final slideUp = -16.0 * _navHideT;

    return Positioned(
      top: topInset + 10,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: opacity < 0.05,
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slideUp),
            child: Row(
              children: [
                _HeroBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _HeroBtn(icon: Icons.share_rounded, onTap: () {}),
                const SizedBox(width: 8),
                _HeroBtn(
                  icon: _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onTap: _toggleSave,
                  active: _isSaved,
                  activeColor: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(GeneratedRecipe recipe, Color color) {
    final emoji = _emojiFor(recipe.title);
    final parallax = (_scrollOffset * 0.45).clamp(0.0, 140.0);
    final scale = 1.0 + (parallax / _heroHeight * 0.12);

    return ClipRect(
      child: SizedBox(
        height: _heroHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(0, parallax * 0.35),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: recipe.imageUrl != null
                    ? Image.network(
                        resizedRecipeImageUrl(recipe.imageUrl, width: 900, quality: 75)!,
                        fit: BoxFit.cover,
                        height: _heroHeight,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withValues(alpha: 0.15),
                          child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 90)),
                          ),
                        ),
                      )
                    : Container(
                        color: color.withValues(alpha: 0.12),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 90)),
                        ),
                      ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 16,
              child: RecipeRatingBadge(
                key: ValueKey(
                  'hero-rating:${RecipeRatingService.cacheKeyFor(recipe)}:$_ratingRevision',
                ),
                recipe: recipe,
                accentColor: color,
              ),
            ),
            Positioned(
              bottom: 14,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      recipe.matchLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  List<Widget> _buildTitleTags(GeneratedRecipe recipe) {
    final cuisines = _cuisineTags(recipe.title);
    final cuisineLabel = cuisines.first.toUpperCase();
    return [
      _PastelTag(
        label: cuisineLabel,
        background: const Color(0xFFFFF8E1),
        foreground: const Color(0xFF8D6E00),
      ),
      _PastelTag(
        label: recipe.difficultyLabel,
        background: const Color(0xFFE8F5E9),
        foreground: const Color(0xFF2E7D32),
      ),
      const _PastelTag(
        label: 'Quillo Pick',
        background: Color(0xFFEDE7FF),
        foreground: AppColors.primary,
      ),
    ];
  }

  static List<String> _cuisineTags(String title) {
    final t = title.toLowerCase();
    final tags = <String>[];
    if (t.contains('italian') || t.contains('pasta') ||
        t.contains('pizza') || t.contains('pesto')) {
      tags.add('Italian');
    }
    if (t.contains('thai') || t.contains('pad')) tags.add('Thai');
    if (t.contains('indian') || t.contains('curry') ||
        t.contains('tikka') || t.contains('paneer')) {
      tags.add('Indian');
    }
    if (t.contains('asian') || t.contains('stir') ||
        t.contains('ramen') || t.contains('miso')) {
      tags.add('Asian');
    }
    if (t.contains('chicken') || t.contains('fish') ||
        t.contains('beef') || t.contains('salmon')) {
      tags.add('Non-Veg');
    }
    if (t.contains('salad') || t.contains('vegan') ||
        t.contains('vegetable')) {
      tags.add('Vegetarian');
    }
    if (tags.isEmpty) tags.add('Quillo Recipe');
    return tags.take(3).toList();
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
    if (t.contains('taco') || t.contains('burrito')) return '🌮';
    if (t.contains('curry') || t.contains('indian')) return '🍛';
    if (t.contains('mushroom')) return '🍄';
    if (t.contains('bread') || t.contains('toast')) return '🍞';
    if (t.contains('pancake')) return '🥞';
    if (t.contains('shrimp') || t.contains('prawn')) return '🍤';
    return '🍽️';
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Hero action button
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  const _HeroBtn(
      {required this.icon,
      required this.onTap,
      this.active = false,
      this.activeColor});

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
                color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)
          ],
        ),
        child: Icon(icon,
            size: 17,
            color: active ? (activeColor ?? AppColors.primary) : AppColors.textDark),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recipe detail stat assets
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _RecipeDetailAssets {
  static const cookTime = 'assets/recipe_detail/stat_cook_time.png';
  static const calories = 'assets/recipe_detail/stat_calories.png';
  static const servings = 'assets/recipe_detail/stat_servings.png';
  static const difficulty = 'assets/recipe_detail/stat_difficulty.png';
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat box
// ─────────────────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String asset;
  final String value;
  final String label;
  const _StatBox({
    required this.asset,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              asset,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_outlined,
                size: 22,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ingredient tile
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientTile extends StatelessWidget {
  final RecipeIngredientUsed item;
  final bool checked;
  final ValueChanged<bool>? onCheckChanged;
  const _IngredientTile({
    required this.item,
    this.checked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          IngredientVisualIcon(ingredientName: item.name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    height: 1.25,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.amount.isNotEmpty)
                  Text(
                    item.amount,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMedium,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onCheckChanged?.call(!checked),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? AppColors.primary : const Color(0xFFE0E0E0),
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Missing ingredients card
// ─────────────────────────────────────────────────────────────────────────────

class _MissingIngredientsCard extends StatelessWidget {
  final List<MissingIngredient> items;
  final Color color;
  final VoidCallback onAddToList;
  const _MissingIngredientsCard({
    required this.items,
    required this.color,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Missing Ingredients',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito')),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${items.length} items',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 18, color: color.withValues(alpha: 0.9)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Almost there! ${items.length} ingredients not in your pantry',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map(
                (item) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.name} (${item.amount})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onAddToList,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE53935)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '+ Add to Shopping List',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE53935),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step card
// ─────────────────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final RecipeStep step;
  final Color accentColor;
  const _StepCard({required this.step, required this.accentColor});

  static (String title, String body) _parts(RecipeStep step) {
    final text = step.instruction.trim();
    final dot = text.indexOf('.');
    if (dot > 0 && dot < 55) {
      return (
        text.substring(0, dot),
        text.substring(dot + 1).trim(),
      );
    }
    return ('Step ${step.order}', text);
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = _parts(step);
    final stepColor = step.order == 1
        ? const Color(0xFF4CAF50)
        : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: stepColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '${step.order}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                      height: 1.5,
                    ),
                  ),
                ],
                if (step.durationMinutes != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        '${step.durationMinutes} min',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nutrition box
// ─────────────────────────────────────────────────────────────────────────────

class _NutBox extends StatelessWidget {
  final String value;
  final String label;
  const _NutBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
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
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pastel tag
// ─────────────────────────────────────────────────────────────────────────────

class _PastelTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  const _PastelTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: foreground,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Serving counter button
// ─────────────────────────────────────────────────────────────────────────────

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: AppColors.chipBorder,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }
}
