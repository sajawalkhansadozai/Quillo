import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/recipe_search_config.dart';
import '../models/ingredient_item.dart';
import '../models/generated_recipe.dart';
import 'scan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecipeService — calls the generate-recipes Edge Function and handles
// saving / loading recipes from Supabase.
// ─────────────────────────────────────────────────────────────────────────────

class RecipeService {
  static final _client = Supabase.instance.client;

  static const _recipeColumns =
      'id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url, is_public';

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

  /// Browse the public Explore catalog (is_public = true).
  static Future<List<GeneratedRecipe>> listPublicRecipes({
    int limit = 100,
  }) async {
    if (_client.auth.currentUser == null) return [];
    try {
      final rows = await _client
          .from('recipes')
          .select(_recipeColumns)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return parseRecipeRows(rows as List);
    } catch (e) {
      debugPrint('listPublicRecipes failed: $e');
      return [];
    }
  }

  /// Search public catalog in Supabase plus Edamam (BigOven fallback via edge function).
  static Future<List<GeneratedRecipe>> searchCatalog({
    required String query,
    int limit = 50,
  }) async {
    final localFuture = searchPublicRecipes(query: query, limit: limit);
    // Edge function caps external API results at 30 per request.
    final externalFuture = _searchExternalRecipes(
      query: query,
      limit: limit.clamp(1, 30),
    );
    final results = await Future.wait([localFuture, externalFuture]);
    return _mergeCatalogResults(results[0], results[1], limit);
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

  static Future<List<GeneratedRecipe>> _searchExternalRecipes({
    required String query,
    int limit = 20,
  }) async {
    if (_client.auth.currentUser == null) {
      debugPrint('search-external-recipes skipped: not signed in');
      return [];
    }
    final term = query.trim();
    if (term.isEmpty) return [];

    try {
      final response = await _client.functions.invoke(
        'search-external-recipes',
        body: {
          'query': term,
          'limit': limit,
          'provider': RecipeSearchConfig.provider,
        },
      );
      final data = _parseFunctionData(response.data);
      if (response.status != 200) {
        debugPrint(
          'search-external-recipes HTTP ${response.status}: ${data?['error'] ?? response.data}',
        );
        return [];
      }
      final activeProvider = data?['provider'] as String?;
      final warning = data?['warning'] as String?;
      debugPrint(
        'search-external-recipes provider=${activeProvider ?? RecipeSearchConfig.provider}',
      );
      if (warning != null) debugPrint('search-external-recipes: $warning');

      final raw = data?['recipes'] as List<dynamic>? ?? [];
      final recipes = raw
          .map((r) {
            try {
              return GeneratedRecipe.fromJson(
                Map<String, dynamic>.from(r as Map),
              );
            } catch (e) {
              debugPrint('search-external-recipes parse error: $e');
              return null;
            }
          })
          .whereType<GeneratedRecipe>()
          .toList();
      debugPrint('search-external-recipes returned ${recipes.length} for "$term"');
      return recipes;
    } catch (e) {
      debugPrint('search-external-recipes failed: $e');
      return [];
    }
  }

  static List<GeneratedRecipe> _mergeCatalogResults(
    List<GeneratedRecipe> local,
    List<GeneratedRecipe> external,
    int limit,
  ) {
    final seenIds = <String>{};
    final seenTitles = <String>{};
    final merged = <GeneratedRecipe>[];

    void add(GeneratedRecipe r) {
      if (r.id != null) {
        if (seenIds.contains(r.id)) return;
        seenIds.add(r.id!);
      }
      final key = r.title.trim().toLowerCase();
      if (key.isEmpty || seenTitles.contains(key)) return;
      seenTitles.add(key);
      merged.add(r);
    }

    for (final r in local) {
      add(r);
    }
    for (final r in external) {
      add(r);
    }
    if (merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  /// Generate cooking steps via Claude when an external API only returned a URL.
  static Future<List<RecipeStep>?> generateInstructions(
    GeneratedRecipe recipe,
  ) async {
    if (_client.auth.currentUser == null) return null;
    if (!recipe.needsGeneratedInstructions) return recipe.steps;

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
      return raw
          .map((s) => RecipeStep.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();
    } catch (e) {
      debugPrint('generate-recipe-instructions failed: $e');
      return null;
    }
  }

  /// Load a web recipe into Supabase (or return cached row).
  static Future<GeneratedRecipe?> fetchExternalRecipe({
    required String source,
    required String sourceId,
  }) async {
    if (_client.auth.currentUser == null) return null;

    try {
      final response = await _client.functions.invoke(
        'fetch-external-recipe',
        body: {
          'source': source,
          'source_id': sourceId,
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
      final rows = await _client
          .from('recipes')
          .select(_recipeColumns)
          .eq('is_public', true)
          .ilike('title', '%$term%')
          .order('created_at', ascending: false)
          .limit(limit);
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
      final rows = await _client
          .from('recipes')
          .select(_recipeColumns)
          .eq('user_id', user.id)
          .ilike('title', '%$term%')
          .order('created_at', ascending: false)
          .limit(limit);
      return parseRecipeRows(rows as List);
    }
  }

  // ── Generate 3 recipes ──────────────────────────────────────────────────────

  static Future<List<GeneratedRecipe>> generateRecipes({
    required String scanId,
    required List<IngredientItem> ingredients,
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
        },
      );
    } catch (e) {
      throw const ScanException(
          'Recipe generation is taking longer than usual — tap to retry.');
    }

    if (response.status == 429) {
      throw const RateLimitException(
          'You have reached your daily recipe limit. Upgrade to Premium for more.');
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

  // ── Helper: load user dietary + cuisine + household from DB ────────────────

  static Future<(List<String>, List<String>, int)> _loadUserPreferences(
      String userId) async {
    try {
      final userRow = await _client
          .from('users')
          .select('household_size, preferred_cuisine')
          .eq('id', userId)
          .maybeSingle();

      final prefsRow = await _client
          .from('user_preferences')
          .select('dietary_labels')
          .eq('user_id', userId)
          .maybeSingle();

      final householdSize = (userRow?['household_size'] as int?) ?? 2;
      final cuisines = List<String>.from(
          userRow?['preferred_cuisine'] as List? ?? []);
      final dietary = List<String>.from(
          prefsRow?['dietary_labels'] as List? ?? []);

      return (dietary, cuisines, householdSize);
    } catch (_) {
      return (const <String>[], const <String>[], 2);
    }
  }
}
