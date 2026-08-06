import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/recipe_search_config.dart';
import '../models/ingredient_item.dart';
import '../models/generated_recipe.dart';
import '../models/user_recipe_preferences.dart';
import '../utils/recipe_image_source.dart';
import 'scan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecipeService — calls the generate-recipes Edge Function and handles
// saving / loading recipes from Supabase.
// ─────────────────────────────────────────────────────────────────────────────

class RecipeService {
  static final _client = Supabase.instance.client;

  static const _recipeColumnsBase =
      'id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url, is_public';

  static const _recipeSourceColumns = 'source, source_id';

  static bool? _recipeSourceColumnsAvailable;

  static String get _recipeColumns {
    if (_recipeSourceColumnsAvailable == false) return _recipeColumnsBase;
    return '$_recipeColumnsBase, $_recipeSourceColumns';
  }

  static bool _isMissingSourceColumnError(Object error) {
    if (error is PostgrestException) {
      return error.code == '42703' &&
          (error.message.contains('source') ||
              error.message.contains('source_id'));
    }
    return false;
  }

  static Future<T> _withRecipeColumns<T>(
    Future<T> Function(String columns) run,
  ) async {
    if (_recipeSourceColumnsAvailable == false) {
      return run(_recipeColumnsBase);
    }

    try {
      final result = await run(_recipeColumns);
      _recipeSourceColumnsAvailable = true;
      return result;
    } catch (e) {
      if (_isMissingSourceColumnError(e)) {
        _recipeSourceColumnsAvailable = false;
        debugPrint(
          'recipes.source columns missing — using base recipe columns only',
        );
        return run(_recipeColumnsBase);
      }
      rethrow;
    }
  }

  /// Latest image-generation stats from the most recent external catalog search.
  static String? lastSearchImageWarning;
  static int? lastGeminiImageCount;
  static int? lastProviderImageCount;
  static int? lastCatalogResultCount;
  static int? lastExternalResultCount;
  static int? lastImagesPendingUpgrade;
  static bool lastSearchHasMore = false;
  static int lastSearchNextOffset = 0;
  static List<GeneratedRecipe> lastForYouRecipes = [];

  static Map<String, dynamic> _preferencesBody(
    UserRecipePreferences? preferences,
  ) =>
      {'preferences': (preferences ?? UserRecipePreferences.empty).toJson()};

  static List<GeneratedRecipe> _parseRecipeList(dynamic raw) {
    if (raw is! List) return [];
    return parseRecipeRows(raw);
  }

  static List<GeneratedRecipe> parseRecipeRows(List<dynamic> rows) =>
      GeneratedRecipe.sortedByIngredientMatch(
        rows
            .map<GeneratedRecipe?>((r) {
              try {
                return GeneratedRecipe.fromJson(
                  Map<String, dynamic>.from(r as Map),
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<GeneratedRecipe>()
            .toList(),
      );

  /// Browse the public Explore catalog via edge function (preference-filtered).
  static Future<List<GeneratedRecipe>> listPublicRecipes({
    int limit = 100,
    UserRecipePreferences? preferences,
  }) async {
    if (_client.auth.currentUser == null) return [];
    try {
      final prefs = preferences ?? await loadUserPreferences();
      final response = await _client.functions.invoke(
        'list-public-recipes',
        body: {
          'limit': limit,
          ..._preferencesBody(prefs),
        },
      );
      final data = _parseFunctionData(response.data);
      if (response.status != 200) {
        debugPrint(
          'list-public-recipes HTTP ${response.status}: '
          '${data?['error'] ?? response.data} '
          'detail=${data?['detail']}',
        );
        return [];
      }
      lastForYouRecipes = _parseRecipeList(data?['for_you']);
      return _parseRecipeList(data?['recipes']);
    } catch (e) {
      debugPrint('listPublicRecipes failed: $e');
      return [];
    }
  }

  /// Search public catalog via edge function (Supabase + external APIs).
  static Future<List<GeneratedRecipe>> searchCatalog({
    required String query,
    int limit = 50,
    int offset = 0,
    List<String> excludeIds = const [],
    UserRecipePreferences? preferences,
  }) async {
    final term = query.trim();
    if (term.isEmpty) return [];

    if (_client.auth.currentUser == null) return [];

    final prefs = preferences ?? await loadUserPreferences();
    final cap = limit.clamp(1, 50);

    try {
      final response = await _client.functions.invoke(
        'search-catalog',
        body: {
          'query': term,
          'limit': cap,
          'offset': offset,
          if (excludeIds.isNotEmpty) 'exclude_ids': excludeIds,
          'provider': RecipeSearchConfig.provider,
          ..._preferencesBody(prefs),
        },
      );
      final data = _parseFunctionData(response.data);
      if (response.status != 200) {
        debugPrint(
          'search-catalog HTTP ${response.status}: ${data?['error'] ?? response.data}',
        );
        lastSearchHasMore = false;
        return [];
      }

      final recipes = _parseRecipeList(data?['recipes']);
      lastSearchImageWarning = data?['warning'] as String?;
      lastGeminiImageCount = data?['gemini_image_count'] as int?;
      lastProviderImageCount = data?['provider_image_count'] as int?;
      lastCatalogResultCount = data?['catalog_count'] as int?;
      lastExternalResultCount = data?['external_count'] as int?;
      lastImagesPendingUpgrade = data?['images_pending_upgrade'] as int?;
      lastSearchHasMore = data?['has_more'] as bool? ?? false;
      lastSearchNextOffset = data?['next_offset'] as int? ?? offset;
      debugPrint(
        'searchCatalog "$term": ${recipes.length} recipes '
        '(catalog=${lastCatalogResultCount ?? 0}, '
        'external=${lastExternalResultCount ?? 0}, '
        'provider=${data?['provider']}, '
        'warning=${lastSearchImageWarning ?? 'none'})',
      );
      return recipes;
    } catch (e) {
      debugPrint('searchCatalog failed: $e');
      lastSearchHasMore = false;
      return [];
    }
  }

  /// Stable keys for recipes already shown in a paginated search.
  static List<String> searchExcludeIds(Iterable<GeneratedRecipe> recipes) {
    final keys = <String>{};
    for (final recipe in recipes) {
      final id = recipe.id;
      if (id != null && id.isNotEmpty) keys.add(id);
      final source = recipe.externalSource;
      final sourceId = recipe.externalId;
      if (source != null && sourceId != null && sourceId.isNotEmpty) {
        keys.add('$source:$sourceId');
      }
    }
    return keys.toList();
  }

  static Map<String, dynamic>? _parseFunctionData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// Generate cooking steps via Claude when an external API only returned a URL.
  static Future<({List<RecipeStep> steps, int? cookTimeMinutes})?>
      generateInstructions(
    GeneratedRecipe recipe,
  ) async {
    if (_client.auth.currentUser == null) return null;
    if (!recipe.needsGeneratedInstructions) {
      return (steps: recipe.steps, cookTimeMinutes: null);
    }

    try {
      final response = await _client.functions.invoke(
        'generate-recipe-instructions',
        body: {
          if (recipe.id != null) 'recipe_id': recipe.id,
          'title': recipe.title,
          'servings': recipe.servings,
          'cook_time_minutes': recipe.cookTimeMinutes,
          'difficulty': recipe.difficulty,
          'ingredients_used': recipe.ingredientsUsed
              .map((i) => {'name': i.name, 'amount': i.amount})
              .toList(),
          'steps': recipe.steps.map((s) => s.toJson()).toList(),
        },
      );
      final data = _parseFunctionData(response.data);
      if (response.status != 200) {
        debugPrint(
          'generate-recipe-instructions HTTP ${response.status}: ${data?['error'] ?? response.data}',
        );
        return null;
      }
      final raw = data?['steps'] as List<dynamic>? ?? [];
      final steps = raw
          .map((s) => RecipeStep.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
      final ct = data?['cook_time_minutes'];
      return (
        steps: steps,
        cookTimeMinutes: ct is num ? ct.toInt() : null,
      );
    } catch (e) {
      debugPrint('generate-recipe-instructions failed: $e');
      return null;
    }
  }

  /// Load a web recipe into Supabase (or return cached row).
  static Future<GeneratedRecipe?> fetchExternalRecipe({
    String? source,
    String? sourceId,
    String? recipeId,
  }) async {
    if (_client.auth.currentUser == null) return null;
    if (recipeId == null && (source == null || sourceId == null)) return null;

    try {
      final response = await _client.functions.invoke(
        'fetch-external-recipe',
        body: {
          if (source != null) 'source': source,
          if (sourceId != null) 'source_id': sourceId,
          if (recipeId != null) 'recipe_id': recipeId,
        },
      );
      final data = _parseFunctionData(response.data);
      if (response.status != 200) {
        debugPrint(
          'fetch-external-recipe HTTP ${response.status}: ${data?['error'] ?? response.data}',
        );
        return null;
      }
      final raw = data?['recipe'];
      if (raw == null) return null;
      return GeneratedRecipe.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (e) {
      debugPrint('fetch-external-recipe failed: $e');
      return null;
    }
  }

  static String imageTrackKey(GeneratedRecipe recipe) => recipeImageTrackKey(
        id: recipe.id,
        externalSource: recipe.externalSource,
        externalId: recipe.externalId,
        title: recipe.title,
      );

  static bool needsGeminiImageUpgrade(GeneratedRecipe recipe) =>
      needsGeminiRecipeImage(recipe.imageUrl);

  /// Generate a Gemini hero image and return the recipe with an updated image URL.
  /// Backoff before each retry. Transient Gemini "high demand" errors usually
  /// clear within seconds; spacing attempts out maximizes eventual success.
  static const List<Duration> _upgradeRetryBackoff = [
    Duration(seconds: 5),
    Duration(seconds: 12),
    Duration(seconds: 25),
  ];

  static Future<GeneratedRecipe?> upgradeRecipeHeroImage(
    GeneratedRecipe recipe, {
    int maxAttempts = 4,
  }) async {
    if (!needsGeminiImageUpgrade(recipe)) return recipe;

    final source = recipe.externalSource;
    final sourceId = recipe.externalId;

    debugPrint(
      'upgradeRecipeHeroImage: title="${recipe.title}" '
      'id=${recipe.id} source=$source sourceId=$sourceId '
      'imageUrl=${recipe.imageUrl}',
    );

    if (!isSupabaseRecipeId(recipe.id) &&
        (source == null || sourceId == null || sourceId.isEmpty)) {
      debugPrint(
        'upgradeRecipeHeroImage: skipping "${recipe.title}" — no valid id or source+sourceId',
      );
      return null;
    }

    final requestBody = <String, dynamic>{
      if (isSupabaseRecipeId(recipe.id)) 'recipe_id': recipe.id,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      'title': recipe.title,
      // Omit large Edamam signed URLs — edge function does not need them.
      if (recipe.imageUrl != null &&
          recipe.imageUrl!.contains('/recipe-images/'))
        'image_url': recipe.imageUrl,
      'ingredients': recipe.ingredientsUsed
          .take(6)
          .map((i) => {'name': i.name})
          .toList(growable: false),
    };
    debugPrint('upgrade-recipe-image request body: $requestBody');

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client.functions.invoke(
          'upgrade-recipe-image',
          body: requestBody,
        );
        final data = _parseFunctionData(response.data);
        debugPrint(
          'upgrade-recipe-image response status=${response.status} '
          'elapsed=${data?['elapsed_ms']}ms data=$data',
        );

        if (response.status == 404) {
          return _upgradeRecipeHeroImageLegacy(recipe);
        }

        if (response.status != 200) {
          final geminiError = data?['gemini_error'] as String?;
          final retriable = data?['retriable'] == true ||
              _isRetriableGeminiError(geminiError);
          if (retriable && attempt < maxAttempts) {
            debugPrint(
              'upgrade-recipe-image retry $attempt/$maxAttempts for "${recipe.title}" '
              '(${geminiError ?? response.status})',
            );
            await Future<void>.delayed(_backoffForAttempt(attempt));
            continue;
          }
          debugPrint(
            'upgrade-recipe-image gave up for "${recipe.title}": '
            '${geminiError ?? data?['error'] ?? response.data}',
          );
          return null;
        }

        final imageUrl = data?['image_url'] as String?;
        if (imageUrl == null || needsGeminiRecipeImage(imageUrl)) {
          debugPrint(
            'upgrade-recipe-image: no valid AI url returned (got $imageUrl)',
          );
          return null;
        }

        debugPrint(
          'upgrade-recipe-image SUCCESS: "${recipe.title}" → $imageUrl',
        );
        return recipe.copyWith(imageUrl: imageUrl);
      } on FunctionException catch (e) {
        final details = e.details;
        final geminiError =
            details is Map ? details['gemini_error'] as String? : null;
        final retriable = details is Map && details['retriable'] == true ||
            _isRetriableGeminiError(geminiError);
        debugPrint(
          'upgrade-recipe-image failed: $e'
          '${geminiError != null ? ' gemini_error=$geminiError' : ''}',
        );
        if (e.status == 404) {
          return _upgradeRecipeHeroImageLegacy(recipe);
        }
        if (retriable && attempt < maxAttempts) {
          debugPrint(
            'upgrade-recipe-image retry $attempt/$maxAttempts for "${recipe.title}" '
            '(${geminiError ?? 'transient error'})',
          );
          await Future<void>.delayed(_backoffForAttempt(attempt));
          continue;
        }
        debugPrint(
          'upgrade-recipe-image gave up for "${recipe.title}": $e'
          '${geminiError != null ? ' gemini_error=$geminiError' : ''}',
        );
        return null;
      } catch (e) {
        debugPrint('upgrade-recipe-image failed: $e');
        return null;
      }
    }

    return null;
  }

  static Duration _backoffForAttempt(int attempt) {
    final idx = (attempt - 1).clamp(0, _upgradeRetryBackoff.length - 1);
    return _upgradeRetryBackoff[idx];
  }

  static bool _isRetriableGeminiError(String? error) {
    if (error == null || error.isEmpty) return true;
    final lower = error.toLowerCase();
    return lower.contains('high demand') ||
        lower.contains('overloaded') ||
        lower.contains('try again') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('signal') ||
        lower.contains('resource exhausted');
  }

  static Future<GeneratedRecipe?> _upgradeRecipeHeroImageLegacy(
    GeneratedRecipe recipe,
  ) async {
    final upgraded = await fetchExternalRecipe(
      recipeId: recipe.id,
      source: recipe.externalSource,
      sourceId: recipe.externalId,
    );

    final imageUrl = upgraded?.imageUrl;
    if (upgraded == null ||
        imageUrl == null ||
        needsGeminiRecipeImage(imageUrl)) {
      return null;
    }

    return recipe.copyWith(
      imageUrl: imageUrl,
      id: upgraded.id ?? recipe.id,
      externalSource: upgraded.externalSource ?? recipe.externalSource,
      externalId: upgraded.externalId ?? recipe.externalId,
    );
  }

  /// Upgrade provider thumbnails to Gemini images without blocking the UI.
  static Future<void> upgradeRecipeImagesInBackground({
    required List<GeneratedRecipe> recipes,
    bool Function()? shouldContinue,
    required void Function(GeneratedRecipe original, GeneratedRecipe upgraded)
        onUpdated,
    void Function(GeneratedRecipe original)? onFinished,
  }) async {
    final targets =
        recipes.where(needsGeminiImageUpgrade).toList(growable: false);
    if (targets.isEmpty) return;

    bool keepGoing() => shouldContinue == null || shouldContinue();

    // Returns true if the card was upgraded, false if it should be retried.
    Future<bool> attempt(GeneratedRecipe original, int maxAttempts) async {
      final upgraded =
          await upgradeRecipeHeroImage(original, maxAttempts: maxAttempts);
      if (!keepGoing()) return true;

      final aiUrl = upgraded?.imageUrl;
      if (upgraded != null &&
          aiUrl != null &&
          aiUrl != original.imageUrl &&
          !needsGeminiRecipeImage(aiUrl)) {
        onUpdated(original, upgraded);
        return true;
      }
      return false;
    }

    // First pass: one quick attempt per card so images appear fast and a
    // slow/failing card never blocks the others.
    final pending = <GeneratedRecipe>[];
    for (final original in targets) {
      if (!keepGoing()) return;
      final ok = await attempt(original, 1);
      if (!ok) pending.add(original);
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    // Retry pass: only the cards that failed, with internal backoff. Since
    // generated images are cached permanently, every card eventually succeeds.
    for (final original in pending) {
      if (!keepGoing()) return;
      final ok = await attempt(original, 4);
      if (!ok) onFinished?.call(original);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// Search all users' public recipes (Explore) — Supabase only.
  static Future<List<GeneratedRecipe>> searchPublicRecipes({
    required String query,
    int limit = 50,
  }) async {
    if (_client.auth.currentUser == null) return [];

    final term = query.trim();
    if (term.isEmpty) return [];

    try {
      final rows = await _client.rpc(
        'search_public_recipes',
        params: {'p_query': term, 'p_limit': limit},
      );
      return parseRecipeRows(rows as List);
    } catch (e) {
      debugPrint('search_public_recipes RPC failed, using title filter: $e');
      final rows = await _withRecipeColumns(
        (columns) => _client
            .from('recipes')
            .select(columns)
            .eq('is_public', true)
            .ilike('title', '%$term%')
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return parseRecipeRows(rows as List);
    }
  }

  /// Whether the current user owns the recipe and its public flag.
  static Future<({bool isOwner, bool isPublic})?> getRecipeShareStatus(
    String recipeId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('recipes')
          .select('user_id, is_public')
          .eq('id', recipeId)
          .maybeSingle();
      if (row == null) return null;
      return (
        isOwner: row['user_id'] == user.id,
        isPublic: row['is_public'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Opt in / out of the public Explore catalog (owner only).
  static Future<bool> setRecipePublic({
    required String recipeId,
    required bool isPublic,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client
          .from('recipes')
          .update({'is_public': isPublic})
          .eq('id', recipeId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      debugPrint('setRecipePublic failed: $e');
      return false;
    }
  }

  /// Search the signed-in user's recipes in Supabase (title + ingredients).
  static Future<List<GeneratedRecipe>> searchRecipes({
    required String query,
    int limit = 50,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final term = query.trim();
    if (term.isEmpty) return [];

    try {
      final rows = await _client.rpc(
        'search_user_recipes',
        params: {'p_query': term, 'p_limit': limit},
      );
      return parseRecipeRows(rows as List);
    } catch (e) {
      debugPrint('search_user_recipes RPC failed, using title filter: $e');
      final rows = await _withRecipeColumns(
        (columns) => _client
            .from('recipes')
            .select(columns)
            .eq('user_id', user.id)
            .ilike('title', '%$term%')
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return parseRecipeRows(rows as List);
    }
  }

  // ── Generate 3 recipes ──────────────────────────────────────────────────────

  static Future<List<GeneratedRecipe>> generateRecipes({
    required String scanId,
    required List<IngredientItem> ingredients,
    bool isManualEntry = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const ScanException('You must be signed in.');

    // If no scan was performed (manual entry), create a lightweight scan record
    // so the Edge Function always receives a valid scan_id.
    String effectiveScanId = scanId;
    if (effectiveScanId.isEmpty) {
      try {
        final row = await _client.from('scans').insert({
          'user_id': user.id,
          'status': 'complete',
          'raw_ocr_text':
              'Manual entry: ${ingredients.map((i) => i.name).join(', ')}',
        }).select('id').single();
        effectiveScanId = row['id'] as String;
      } catch (_) {
        // If the insert fails, generate a client-side UUID as fallback
        effectiveScanId =
            DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(32, '0');
      }
    }

    // Load user preferences from Supabase
    final prefs = await _loadUserPreferences(user.id);

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'generate-recipes',
        body: {
          'ingredients': ingredients.map((i) => i.toJson()).toList(),
          'dietary_labels': prefs.$1,
          'preferred_cuisines': prefs.$2,
          'household_size': prefs.$3,
          'scan_id': effectiveScanId,
          'user_id': user.id,
          'is_manual_entry': isManualEntry,
        },
      );
    } catch (e) {
      throw const ScanException(
          'Recipe generation is taking longer than usual — tap to retry.');
    }

    if (response.status == 429) {
      throw const RateLimitException(
          'You have reached your monthly scan limit. Upgrade to Premium for unlimited scans.');
    }
    if (response.status != 200) {
      final errorData = response.data as Map<String, dynamic>?;
      final msg = errorData?['error'] as String? ??
          'Recipe generation is taking longer than usual — tap to retry.';
      throw ScanException(msg);
    }

    final data = response.data as Map<String, dynamic>;
    final rawList = data['recipes'] as List<dynamic>? ?? [];
    final recipes = rawList
        .map((r) => GeneratedRecipe.fromJson(r as Map<String, dynamic>))
        .toList();
    return GeneratedRecipe.sortedByIngredientMatch(recipes);
  }

  /// Ensures a web recipe exists in `recipes` and returns it with a Supabase [id].
  static Future<GeneratedRecipe?> ensureRecipePersisted(
    GeneratedRecipe recipe,
  ) async {
    if (recipe.id != null) return recipe;
    final source = recipe.externalSource;
    final sourceId = recipe.externalId;
    if (source == null || sourceId == null || sourceId.isEmpty) return null;
    return fetchExternalRecipe(source: source, sourceId: sourceId);
  }

  // ── Save a recipe to saved_recipes ─────────────────────────────────────────

  static Future<bool> saveRecipe(GeneratedRecipe recipe) async {
    final user = _client.auth.currentUser;
    if (user == null || recipe.id == null) return false;
    try {
      await _client.from('saved_recipes').upsert(
        {
          'user_id': user.id,
          'recipe_id': recipe.id,
          'cached_data': recipe.toJson(),
        },
        onConflict: 'user_id,recipe_id',
      );
      return true;
    } catch (e) {
      debugPrint('saveRecipe failed: $e');
      return false;
    }
  }

  // ── Remove a recipe from saved_recipes ─────────────────────────────────────

  static Future<bool> unsaveRecipe(String recipeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client
          .from('saved_recipes')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', recipeId);
      return true;
    } catch (e) {
      debugPrint('unsaveRecipe failed: $e');
      return false;
    }
  }

  // ── Check if recipe is saved ────────────────────────────────────────────────

  static Future<bool> isRecipeSaved(String recipeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await _client
          .from('saved_recipes')
          .select('id')
          .eq('user_id', user.id)
          .eq('recipe_id', recipeId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  // ── Load all saved recipes ──────────────────────────────────────────────────

  static Future<List<GeneratedRecipe>> loadSavedRecipes() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      final rows = await _client
          .from('saved_recipes')
          .select('cached_data, saved_at')
          .eq('user_id', user.id)
          .order('saved_at', ascending: false);

      return (rows as List<dynamic>)
          .map((r) {
            final cached = r['cached_data'] as Map<String, dynamic>?;
            if (cached == null) return null;
            return GeneratedRecipe.fromJson(cached);
          })
          .whereType<GeneratedRecipe>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<UserRecipePreferences> loadUserPreferences() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return UserRecipePreferences.empty;
    try {
      final userRow = await _client
          .from('users')
          .select('household_size, preferred_cuisine')
          .eq('id', uid)
          .maybeSingle();

      final prefsRow = await _client
          .from('user_preferences')
          .select('dietary_labels, cooking_skill, max_cook_time')
          .eq('user_id', uid)
          .maybeSingle();

      return UserRecipePreferences(
        dietary: List<String>.from(prefsRow?['dietary_labels'] as List? ?? []),
        cuisines: List<String>.from(userRow?['preferred_cuisine'] as List? ?? []),
        maxCookTimeMinutes: (prefsRow?['max_cook_time'] as int?) ?? 45,
        cookingSkill: (prefsRow?['cooking_skill'] as String?) ?? 'Intermediate',
        householdSize: (userRow?['household_size'] as int?) ?? 2,
      );
    } catch (_) {
      return UserRecipePreferences.empty;
    }
  }

  static Future<(List<String>, List<String>, int)> _loadUserPreferences(
      String userId) async {
    final prefs = await loadUserPreferences();
    return (prefs.dietary, prefs.cuisines, prefs.householdSize);
  }
}
