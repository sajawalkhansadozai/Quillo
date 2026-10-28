import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/generated_recipe.dart';
import '../../config/recipe_search_config.dart';
import '../../services/local_db_service.dart';
import '../../services/recipe_service.dart';
import '../scan/recipe_detail_page.dart';
import '../shopping/shopping_lists_screen.dart';
import 'all_recipes_screen.dart';
import '../../models/user_recipe_preferences.dart';
import '../../utils/recipe_preference_filter.dart';
import '../../utils/recipe_image_source.dart';
import '../../services/recipe_rating_service.dart';
import '../../widgets/recipe_rating_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExploreScreen — real recipes from Supabase with search + category filter
// ─────────────────────────────────────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => ExploreScreenState();
}

class ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  Timer? _suggestDebounce;

  static const _searchDebounceMs = 800;
  static const _suggestDebounceMs = 220;
  static const _minSearchLength = 2;
  static const _minSuggestLength = 2;

  String _selectedCategory = 'All';
  static const _baseCategories = ['All', 'Easy', 'Medium', 'Hard', 'Quick'];

  List<GeneratedRecipe> _allRecipes = [];
  List<GeneratedRecipe> _forYouRecipes = [];
  List<GeneratedRecipe> _searchResults = [];
  List<GeneratedRecipe> _filteredRecipes = [];
  List<String> _searchSuggestions = [];
  bool _loading = true;
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _searchShowSkeleton = false;
  bool _searchTimedOut = false;
  bool _searchHasMore = false;
  int _searchExternalOffset = 0;
  bool _searchPageInFlight = false;
  int _searchPageToken = 0;
  String? _searchHint;
  Timer? _searchSkeletonTimer;
  final Set<String> _savedIds = {};
  final Set<String> _savingIds = {};
  final Set<String> _upgradingImageKeys = {};
  int _imageUpgradeGeneration = 0;

  // User preferences for personalisation
  UserRecipePreferences _userPrefs = UserRecipePreferences.empty;

  List<String> get _categories {
    // Append saved cuisines as extra filter chips
    final extras = _userPrefs.cuisines
        .where((c) => !_baseCategories.any(
            (b) => b.toLowerCase() == c.toLowerCase()))
        .toList();
    return [..._baseCategories, ...extras];
  }

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
    _suggestDebounce?.cancel();

    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchSuggestions = [];
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchHasMore = false;
        _searchExternalOffset = 0;
        _searchHint = null;
      });
      _applyFilters();
      return;
    }

    if (q.length >= _minSuggestLength) {
      _suggestDebounce = Timer(
        const Duration(milliseconds: _suggestDebounceMs),
        () => _loadSearchSuggestions(q),
      );
    } else if (_searchSuggestions.isNotEmpty) {
      setState(() => _searchSuggestions = []);
    }

    if (q.length < _minSearchLength) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchHasMore = false;
        _searchExternalOffset = 0;
        _searchHint = null;
      });
      _applyFilters();
      return;
    }

    // Wait until the user stops typing before calling the API.
    _searchDebounce = Timer(const Duration(milliseconds: _searchDebounceMs), () {
      _runSearch(q);
    });
  }

  Future<void> _loadSearchSuggestions(String prefix) async {
    final suggestions = await RecipeService.suggestSearchTerms(prefix);
    if (!mounted) return;
    if (_searchController.text.trim() != prefix) return;
    setState(() => _searchSuggestions = suggestions);
  }

  void _applySuggestion(String suggestion) {
    _suggestDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.collapsed(offset: suggestion.length);
    setState(() => _searchSuggestions = []);
    _submitSearch(suggestion);
  }

  void _submitSearch([String? value]) {
    _searchDebounce?.cancel();
    _suggestDebounce?.cancel();
    final q = (value ?? _searchController.text).trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchSuggestions = [];
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchHasMore = false;
        _searchExternalOffset = 0;
        _searchHint = null;
      });
      _applyFilters();
      return;
    }
    if (q.length < _minSearchLength) return;
    setState(() => _searchSuggestions = []);
    _runSearch(q);
  }

  /// Claims the shared "page request in flight" flag. Only the request
  /// holding the latest token may clear it, so an older prefetch finishing
  /// can't unlock load-more while a newer request is still running.
  int _claimSearchPage() {
    _searchPageInFlight = true;
    return ++_searchPageToken;
  }

  void _releaseSearchPage(int token) {
    if (token == _searchPageToken) _searchPageInFlight = false;
  }

  Future<void> _runSearch(String query, {bool append = false}) async {
    if (append && (_searchPageInFlight || _searchLoadingMore || !_searchHasMore)) {
      return;
    }
    final generation = append ? _imageUpgradeGeneration : ++_imageUpgradeGeneration;
    _searchSkeletonTimer?.cancel();
    final pageToken = _claimSearchPage();
    setState(() {
      if (!append) {
        _searchLoading = true;
        _searchShowSkeleton = false;
        _searchTimedOut = false;
        _searchExternalOffset = 0;
        _searchHasMore = false;
      } else {
        _searchLoadingMore = true;
      }
      _searchHint = null;
      if (!append) _upgradingImageKeys.clear();
    });

    if (!append) {
      _searchSkeletonTimer = Timer(RecipeSearchConfig.searchSkeletonAfter, () {
        if (!mounted || generation != _imageUpgradeGeneration) return;
        if (_searchLoading) setState(() => _searchShowSkeleton = true);
      });
    }

    bool isStale() =>
        !mounted ||
        generation != _imageUpgradeGeneration ||
        _searchController.text.trim() != query;

    void stopLoading() {
      if (!mounted) return;
      _searchSkeletonTimer?.cancel();
      setState(() {
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchShowSkeleton = false;
      });
    }

    try {
      final conn = await Connectivity().checkConnectivity();
      final online = conn.any((r) => r != ConnectivityResult.none);

      if (!online && !append) {
        final cached = await LocalDbService.loadSearchCache(query);
        final filtered = RecipePreferenceFilter.apply(cached, _userPrefs);
        if (!mounted || generation != _imageUpgradeGeneration) return;
        _searchSkeletonTimer?.cancel();
        setState(() {
          _searchResults = filtered;
          _searchLoading = false;
          _searchShowSkeleton = false;
          _searchTimedOut = false;
          _searchHasMore = false;
          _searchHint = filtered.isEmpty
              ? 'You\'re offline and no cached results for "$query".'
              : 'Offline — showing cached results for "$query"';
        });
        _applyFilters();
        return;
      }

      final requestOffset = append ? _searchExternalOffset : 0;
      final page = await RecipeService.searchCatalog(
        query: query,
        limit: RecipeSearchConfig.exploreSearchLimit,
        offset: requestOffset,
        excludeIds: append
            ? RecipeService.searchExcludeIds(_searchResults)
            : const [],
        preferences: _userPrefs,
      ).timeout(RecipeSearchConfig.searchTimeout);

      if (!mounted || generation != _imageUpgradeGeneration) return;
      if (_searchController.text.trim() != query) {
        // The user edited the query while this was loading; a newer search
        // owns the results, but don't leave this one's spinner behind.
        stopLoading();
        return;
      }
      _searchSkeletonTimer?.cancel();
      final seen = <String>{};
      if (append) RecipeService.dedupeSearchResults(_searchResults, seen);
      final fresh = RecipeService.dedupeSearchResults(page.recipes, seen);
      final pendingUpgrade =
          fresh.where(RecipeService.needsGeminiImageUpgrade).length;
      setState(() {
        _searchResults = append ? [..._searchResults, ...fresh] : fresh;
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchShowSkeleton = false;
        _searchTimedOut = false;
        // Keep paging while the server has more and we're still moving
        // forward, even if this page happened to be all repeats.
        _searchHasMore = page.hasMore &&
            (fresh.isNotEmpty || page.nextOffset > requestOffset);
        _searchExternalOffset = page.nextOffset;
        if (_searchResults.isEmpty) {
          _searchHint = 'No recipes found for "$query". Try another dish or ingredient.';
          if (page.warning?.isNotEmpty == true) {
            debugPrint('search-catalog warning: ${page.warning}');
          }
        } else {
          _searchHint = _buildSearchHint(
            total: _searchResults.length,
            catalogCount: page.catalogCount,
            externalCount: page.externalCount,
            pendingUpgrade: pendingUpgrade,
          );
        }
      });
      _applyFilters();
      unawaited(LocalDbService.cacheSearchResults(query, _searchResults));
      if (!mounted || generation != _imageUpgradeGeneration) return;
      unawaited(RecipeRatingService.prefetchSummaries(fresh));
      unawaited(_startBackgroundImageUpgrades(
        fresh,
        generation,
        replaceTrackedKeys: !append,
      ));
      // Prefetch AFTER this request releases the in-flight flag (see finally),
      // otherwise the guard makes prefetch a no-op and results stay stuck.
      final shouldPrefetch = !append && _searchHasMore;
      await _loadSavedIds();
      if (shouldPrefetch && mounted && generation == _imageUpgradeGeneration) {
        // Let finally clear the in-flight flag first.
        scheduleMicrotask(() {
          if (!mounted || generation != _imageUpgradeGeneration) return;
          unawaited(_prefetchNextSearchPage(query, generation));
        });
      }
    } on TimeoutException {
      debugPrint('Explore search timed out for "$query"');
      if (isStale()) {
        stopLoading();
        return;
      }
      _searchSkeletonTimer?.cancel();
      final cached = append ? <GeneratedRecipe>[] : await LocalDbService.loadSearchCache(query);
      if (isStale()) return;
      final filtered = RecipePreferenceFilter.apply(cached, _userPrefs);
      setState(() {
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchShowSkeleton = false;
        _searchTimedOut = true;
        if (!append && filtered.isNotEmpty) {
          _searchResults = filtered;
          _searchHint = 'Search timed out — showing cached results. Tap retry for fresh data.';
        } else {
          _searchHint = 'Search timed out. Check your connection and try again.';
        }
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Explore search error: $e');
      // An older request failing must not overwrite a newer search.
      if (isStale()) {
        if (mounted && generation == _imageUpgradeGeneration) stopLoading();
        return;
      }
      _searchSkeletonTimer?.cancel();
      final cached = append ? <GeneratedRecipe>[] : await LocalDbService.loadSearchCache(query);
      if (isStale()) return;
      final filtered = RecipePreferenceFilter.apply(cached, _userPrefs);
      setState(() {
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchShowSkeleton = false;
        if (!append && filtered.isNotEmpty) {
          _searchResults = filtered;
          _searchHint = 'Search failed — showing cached results.';
        } else if (append) {
          _searchHint = 'Couldn\'t load more recipes. Tap to try again.';
        } else {
          _searchHint = 'Search failed. Pull to refresh and try again.';
        }
      });
      _applyFilters();
    } finally {
      _releaseSearchPage(pageToken);
    }
  }

  Future<void> _loadMoreSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || !_searchHasMore || _searchPageInFlight) return;
    await _runSearch(query, append: true);
    if (!mounted) return;
    if (_searchHasMore) {
      unawaited(_prefetchNextSearchPage(query, _imageUpgradeGeneration));
    }
  }

  /// Silently cache the next page so scrolling never waits on the network.
  Future<void> _prefetchNextSearchPage(String query, int generation) async {
    if (_searchPageInFlight || !_searchHasMore) return;
    final pageToken = _claimSearchPage();
    try {
      final requestOffset = _searchExternalOffset;
      final page = await RecipeService.searchCatalog(
        query: query,
        limit: RecipeSearchConfig.exploreSearchLimit,
        offset: requestOffset,
        excludeIds: RecipeService.searchExcludeIds(_searchResults),
        preferences: _userPrefs,
      );
      if (!mounted || generation != _imageUpgradeGeneration) return;
      if (_searchController.text.trim() != query) return;

      final seen = <String>{};
      RecipeService.dedupeSearchResults(_searchResults, seen);
      final fresh = RecipeService.dedupeSearchResults(page.recipes, seen);

      setState(() {
        _searchResults = [..._searchResults, ...fresh];
        _searchHasMore = page.hasMore &&
            (fresh.isNotEmpty || page.nextOffset > requestOffset);
        _searchExternalOffset = page.nextOffset;
      });
      if (fresh.isEmpty) return;
      _applyFilters();
      unawaited(LocalDbService.cacheSearchResults(query, _searchResults));
      unawaited(RecipeRatingService.prefetchSummaries(fresh));
      unawaited(_startBackgroundImageUpgrades(
        fresh,
        generation,
        replaceTrackedKeys: false,
      ));
    } catch (e) {
      debugPrint('prefetch next search page failed: $e');
    } finally {
      _releaseSearchPage(pageToken);
    }
  }

  /// Called from Home when the user taps the search bar or submits a query.
  void openSearch(String query, {bool focusSearch = false}) {
    _searchDebounce?.cancel();
    _searchController.text = query;
    final trimmed = query.trim();
    if (trimmed.length >= _minSearchLength) {
      _submitSearch(trimmed);
    } else {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchHasMore = false;
        _searchExternalOffset = 0;
        _searchHint = null;
      });
      _applyFilters();
    }
    if (focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocusNode.requestFocus();
        });
      });
    }
  }

  @override
  void dispose() {
    _imageUpgradeGeneration++;
    _searchDebounce?.cancel();
    _suggestDebounce?.cancel();
    _searchSkeletonTimer?.cancel();
    _fadeCtrl.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    try {
      final prefs = await RecipeService.loadUserPreferences();
      final recipes = await RecipeService.listPublicRecipes(
        limit: 100,
        preferences: prefs,
      );

      if (mounted) {
        setState(() {
          _allRecipes = recipes;
          _forYouRecipes = RecipeService.lastForYouRecipes;
          _userPrefs = prefs;
          _loading = false;
        });
        _applyFilters();
      }
      await _loadSavedIds();
      unawaited(RecipeRatingService.prefetchSummaries(recipes));
    } catch (e) {
      debugPrint('ExploreScreen error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedIds() async {
    try {
      final saved = await RecipeService.loadSavedRecipes();
      if (!mounted) return;
      setState(() {
        _savedIds
          ..clear()
          ..addAll(saved.map((r) => r.id).whereType<String>());
      });
    } catch (_) {}
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
      patch(_allRecipes);
      patch(_searchResults);
      patch(_filteredRecipes);
      _upgradingImageKeys.remove(oldKey);
    });
  }

  String _buildSearchHint({
    required int total,
    required int catalogCount,
    required int externalCount,
    required int pendingUpgrade,
  }) {
    final parts = <String>['$total recipes'];
    if (catalogCount > 0) parts.add('$catalogCount catalog');
    if (externalCount > 0) parts.add('$externalCount Edamam');
    if (pendingUpgrade > 0) {
      parts.add('enhancing $pendingUpgrade AI images');
    }
    return parts.join(' · ');
  }

  void _updateSearchHintAfterUpgrade() {
    if (_searchController.text.trim().isEmpty || _searchResults.isEmpty) return;
    final geminiReady = _searchResults
        .where((r) => !RecipeService.needsGeminiImageUpgrade(r))
        .length;
    final stillUpgrading = _upgradingImageKeys.length;
    setState(() {
      if (stillUpgrading > 0) {
        _searchHint =
            '${_searchResults.length} recipes · enhancing $stillUpgrading AI images...';
      } else if (geminiReady > 0) {
        _searchHint =
            '${_searchResults.length} recipes · $geminiReady AI images ready';
      }
    });
  }

  Future<void> _startBackgroundImageUpgrades(
    List<GeneratedRecipe> recipes,
    int generation, {
    bool replaceTrackedKeys = true,
  }) async {
    final targets = recipes
        .where(RecipeService.needsGeminiImageUpgrade)
        .take(RecipeSearchConfig.exploreAiImageUpgradeLimit)
        .toList();
    if (targets.isEmpty) return;

    setState(() {
      if (replaceTrackedKeys) {
        _upgradingImageKeys
          ..clear()
          ..addAll(targets.map(RecipeService.imageTrackKey));
      } else {
        _upgradingImageKeys.addAll(targets.map(RecipeService.imageTrackKey));
      }
      _searchHint =
          '${_searchResults.length} recipes · enhancing ${_upgradingImageKeys.length} AI images...';
    });

    await RecipeService.upgradeRecipeImagesInBackground(
      recipes: targets,
      shouldContinue: () =>
          mounted && generation == _imageUpgradeGeneration,
      onUpdated: (old, updated) {
        if (!mounted || generation != _imageUpgradeGeneration) return;
        _replaceRecipeInLists(old, updated);
        _updateSearchHintAfterUpgrade();
      },
      onFinished: (recipe) {
        if (!mounted || generation != _imageUpgradeGeneration) return;
        setState(() {
          _upgradingImageKeys.remove(RecipeService.imageTrackKey(recipe));
        });
        _updateSearchHintAfterUpgrade();
      },
    );
  }

  Future<void> _toggleSave(GeneratedRecipe recipe) async {
    final trackKey = recipe.id ?? recipe.externalId ?? recipe.title;
    if (_savingIds.contains(trackKey)) return;

    setState(() => _savingIds.add(trackKey));
    var r = recipe;

    if (r.id == null) {
      final persisted = await RecipeService.ensureRecipePersisted(r);
      if (!mounted) return;
      if (persisted?.id == null) {
        setState(() => _savingIds.remove(trackKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save this recipe right now. Check your connection and try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      r = persisted!;
      _replaceRecipeInLists(recipe, r);
    }

    final id = r.id!;
    final wasSaved = _savedIds.contains(id);
    setState(() {
      if (wasSaved) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });

    final ok = wasSaved
        ? await RecipeService.unsaveRecipe(id)
        : await RecipeService.saveRecipe(r);

    if (!mounted) return;
    setState(() => _savingIds.remove(trackKey));
    if (!ok) {
      setState(() {
        if (wasSaved) {
          _savedIds.add(id);
        } else {
          _savedIds.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update saved recipes. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!wasSaved) {
      await LocalDbService.cacheRecipe(r);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${r.title}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await LocalDbService.removeRecipe(id);
    }
  }

  bool _isRecipeSaved(GeneratedRecipe recipe) =>
      recipe.id != null && _savedIds.contains(recipe.id);

  bool _matchesCategory(GeneratedRecipe recipe, [String? category]) {
    final cat = category ?? _selectedCategory;
    if (cat == 'All') return true;
    if (cat == 'Quick') return recipe.cookTimeMinutes <= 20;
    if (cat == 'Easy' || cat == 'Medium' || cat == 'Hard') {
      return recipe.difficulty.toLowerCase() == cat.toLowerCase();
    }
    final title = recipe.title.toLowerCase();
    return title.contains(cat.toLowerCase());
  }

  List<GeneratedRecipe> get _visibleForYouRecipes =>
      _forYouRecipes.where(_matchesCategory).toList();

  void _applyFilters() {
    final isSearching = _searchController.text.trim().isNotEmpty;
    final featuredId = _visibleFeatured?.id;
    final source = isSearching ? _searchResults : _allRecipes;
    setState(() {
      _filteredRecipes = source.where((r) {
        if (!isSearching && r.id != null && r.id == featuredId) return false;
        return _matchesCategory(r);
      }).toList();
    });
  }

  void _selectCategory(String cat) {
    setState(() => _selectedCategory = cat);
    _applyFilters();
  }

  List<GeneratedRecipe> get _quickRecipes => _allRecipes
      .where((r) => r.cookTimeMinutes <= 20)
      .where(_matchesCategory)
      .toList();

  GeneratedRecipe? get _featured =>
      RecipePreferenceFilter.pickFeatured(_allRecipes, _userPrefs);

  GeneratedRecipe? get _visibleFeatured {
    final featured = _featured;
    if (featured == null || _matchesCategory(featured)) return featured;
    final pool = _allRecipes.where(_matchesCategory).toList();
    if (pool.isEmpty) return null;
    return RecipePreferenceFilter.pickFeatured(pool, _userPrefs) ?? pool.first;
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
                    child: _SearchBar(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSubmitted: _submitSearch,
                    ),
                  ),
                ),

                if (_searchSuggestions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _SearchSuggestions(
                        suggestions: _searchSuggestions,
                        onSelect: _applySuggestion,
                      ),
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
                        ],
                      ),
                    ),
                  ),
                  if (_searchLoading)
                    SliverToBoxAdapter(
                      child: _searchShowSkeleton
                          ? _buildSearchSkeleton()
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            ),
                    )
                  else if (_searchTimedOut && _filteredRecipes.isEmpty)
                    SliverToBoxAdapter(child: _buildSearchTimeout())
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
                          (ctx, i) {
                            final recipe = _filteredRecipes[i];
                            return _RecipeCard(
                              key: ValueKey(
                                '${RecipeService.imageTrackKey(recipe)}:${recipe.imageUrl ?? ''}',
                              ),
                              recipe: recipe,
                              isSaved: _isRecipeSaved(recipe),
                              isSaving: _savingIds.contains(
                                recipe.id ??
                                    recipe.externalId ??
                                    recipe.title,
                              ),
                              isImageUpgrading: _upgradingImageKeys.contains(
                                RecipeService.imageTrackKey(recipe),
                              ),
                              onTap: () => _openRecipe(recipe),
                              onSave: () => _toggleSave(recipe),
                            );
                          },
                          childCount: _filteredRecipes.length,
                        ),
                      ),
                    ),
                  if (_searchTimedOut && _filteredRecipes.isNotEmpty)
                    SliverToBoxAdapter(child: _buildSearchTimeout(compact: true)),
                  if (!_searchLoading &&
                      _filteredRecipes.isNotEmpty &&
                      _searchHasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        child: _LoadMoreSearchButton(
                          loading: _searchLoadingMore,
                          onTap: _loadMoreSearch,
                        ),
                      ),
                    ),
                ] else ...[
                  // ── For You ────────────────────────────────────────────
                  if (_visibleForYouRecipes.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'For You',
                        action: _visibleForYouRecipes.length > 6 ? 'See all' : '',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AllRecipesScreen(
                              initialFilter: _selectedCategory,
                            ),
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
                          (ctx, i) {
                            final recipe = _visibleForYouRecipes[i];
                            return _RecipeCard(
                              recipe: recipe,
                              isSaved: _isRecipeSaved(recipe),
                              isSaving: _savingIds.contains(
                                recipe.id ??
                                    recipe.externalId ??
                                    recipe.title,
                              ),
                              onTap: () => _openRecipe(recipe),
                              onSave: () => _toggleSave(recipe),
                            );
                          },
                          childCount: _visibleForYouRecipes.length > 6
                              ? 6
                              : _visibleForYouRecipes.length,
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
                      child: _visibleFeatured != null
                          ? _FeaturedCard(
                              recipe: _visibleFeatured!,
                              onTap: () => _openRecipe(_visibleFeatured!),
                            )
                          : const _FeaturedPlaceholder(),
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
                          builder: (_) => AllRecipesScreen(
                            initialFilter: _selectedCategory,
                          ),
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
                          (ctx, i) {
                            final recipe = _filteredRecipes[i];
                            return _RecipeCard(
                              recipe: recipe,
                              isSaved: _isRecipeSaved(recipe),
                              isSaving: _savingIds.contains(
                                recipe.id ??
                                    recipe.externalId ??
                                    recipe.title,
                              ),
                              onTap: () => _openRecipe(recipe),
                              onSave: () => _toggleSave(recipe),
                            );
                          },
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
                        height: 168,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _quickRecipes.length,
                          itemBuilder: (ctx, i) {
                            final recipe = _quickRecipes[i];
                            return _QuickCard(
                              recipe: recipe,
                              isSaved: _isRecipeSaved(recipe),
                              onTap: () => _openRecipe(recipe),
                              onSave: () => _toggleSave(recipe),
                            );
                          },
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
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => GeneratedRecipeDetailPage(
            recipe: recipe,
            accentColor: _tagColor(recipe.difficulty),
          ),
        ))
        .then((_) => _loadSavedIds());
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Text(
        'No recipes found',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }

  Widget _buildSearchTimeout({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 8 : 24, 20, 20),
      child: Column(
        children: [
          Text(
            compact
                ? (_searchHint ?? 'Search timed out.')
                : 'Search is taking too long',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _submitSearch(_searchController.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Retry search',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: List.generate(2, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _skeletonCard()),
                const SizedBox(width: 12),
                Expanded(child: _skeletonCard()),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _skeletonCard() {
    return AspectRatio(
      aspectRatio: 1.35,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.green.withValues(alpha: 0.18),
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.green.withValues(alpha: 0.22),
            ],
          ),
        ),
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
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  const _SearchBar({
    required this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
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
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSubmitted,
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
                  onTap: controller.clear,
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
      },
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  const _SearchSuggestions({
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.chipBorder),
            InkWell(
              onTap: () => onSelect(suggestions[i]),
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(14) : Radius.zero,
                bottom: i == suggestions.length - 1
                    ? const Radius.circular(14)
                    : Radius.zero,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.north_west_rounded,
                        size: 16, color: AppColors.textLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        suggestions[i],
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
              bottom: 14,
              left: 14,
              child: RecipeRatingBadge(
                recipe: recipe,
                accentColor: AppColors.primary,
                compact: true,
              ),
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

// ── Recipe grid card ─────────────────────────────────────────────────────────

class _RecipeHeroImage extends StatefulWidget {
  final String? imageUrl;
  final String emoji;
  final Color tagColor;
  final bool isImageUpgrading;

  const _RecipeHeroImage({
    required this.imageUrl,
    required this.emoji,
    required this.tagColor,
    required this.isImageUpgrading,
  });

  @override
  State<_RecipeHeroImage> createState() => _RecipeHeroImageState();
}

class _RecipeHeroImageState extends State<_RecipeHeroImage> {
  bool _frameReady = true;

  @override
  void didUpdateWidget(covariant _RecipeHeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _frameReady = widget.imageUrl == null;
    }
  }

  bool get _showUpgradeOverlay =>
      widget.isImageUpgrading ||
      (!_frameReady && recipeImageSource(widget.imageUrl) == RecipeImageSource.gemini);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOut,
          child: widget.imageUrl != null
              ? Image.network(
                  resizedRecipeImageUrl(widget.imageUrl, width: 480)!,
                  key: ValueKey(widget.imageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  gaplessPlayback: false,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    final ready = frame != null || wasSynchronouslyLoaded;
                    if (ready && !_frameReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _frameReady = true);
                      });
                    }
                    return child;
                  },
                  errorBuilder: (_, __, ___) => Container(
                    key: const ValueKey('emoji-fallback'),
                    color: widget.tagColor.withValues(alpha: 0.1),
                    child: Center(
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                )
              : Container(
                  key: const ValueKey('no-image'),
                  color: widget.tagColor.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
        ),
        if (_showUpgradeOverlay)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.28),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final GeneratedRecipe recipe;
  final bool isSaved;
  final bool isSaving;
  final bool isImageUpgrading;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _RecipeCard({
    super.key,
    required this.recipe,
    required this.isSaved,
    this.isSaving = false,
    this.isImageUpgrading = false,
    required this.onTap,
    required this.onSave,
  });

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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RecipeHeroImage(
                      imageUrl: recipe.imageUrl,
                      emoji: emoji,
                      tagColor: tagColor,
                      isImageUpgrading: isImageUpgrading,
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: RecipeRatingBadge(
                        recipe: recipe,
                        accentColor: tagColor,
                        compact: true,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: isSaving ? null : onSave,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: isSaving
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Icon(
                                  isSaved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  size: 16,
                                  color: isSaved
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                ),
                        ),
                      ),
                    ),
                  ],
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
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _QuickCard({
    required this.recipe,
    required this.isSaved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = _emoji(recipe.title);
    final color = _tagColor(recipe.difficulty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RecipeHeroImage(
                      imageUrl: recipe.imageUrl,
                      emoji: emoji,
                      tagColor: color,
                      isImageUpgrading: false,
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: RecipeRatingBadge(
                        recipe: recipe,
                        accentColor: color,
                        compact: true,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onSave,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 14,
                            color: isSaved
                                ? AppColors.primary
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 10, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Text(
                        '${recipe.cookTimeMinutes}m',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textLight),
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

class _LoadMoreSearchButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _LoadMoreSearchButton({
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'Load ${RecipeSearchConfig.exploreSearchLimit} more recipes',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontFamily: 'Nunito',
                  ),
                ),
        ),
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
