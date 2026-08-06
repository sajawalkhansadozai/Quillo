import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/generated_recipe.dart';
import '../utils/recipe_image_source.dart';
import 'recipe_service.dart';

class RecipeRatingResult {
  final int rating;
  final GeneratedRecipe recipe;
  final bool syncedToServer;

  const RecipeRatingResult({
    required this.rating,
    required this.recipe,
    required this.syncedToServer,
  });
}

class RecipeRatingSummary {
  final double averageRating;
  final int ratingCount;

  const RecipeRatingSummary({
    required this.averageRating,
    required this.ratingCount,
  });

  bool get hasRatings => ratingCount > 0;

  String get label {
    if (!hasRatings) return '';
    final avg = averageRating == averageRating.roundToDouble()
        ? averageRating.round().toString()
        : averageRating.toStringAsFixed(1);
    final noun = ratingCount == 1 ? 'rating' : 'ratings';
    return '$avg · $ratingCount $noun';
  }
}

/// Loads and saves per-recipe star ratings (Supabase + local cache).
class RecipeRatingService {
  RecipeRatingService._();

  static const _prefix = 'recipe_rating_';
  static final _client = Supabase.instance.client;
  static final _summaryCache = <String, RecipeRatingSummary>{};
  static final summaryRevision = ValueNotifier<int>(0);

  static void _bumpSummaries() {
    summaryRevision.value++;
  }

  static void invalidateSummary(String recipeId) {
    _summaryCache.remove(recipeId);
    _bumpSummaries();
  }

  static RecipeRatingSummary? _parseSummaryRow(Map<String, dynamic> row) {
    final count = (row['rating_count'] as num?)?.toInt() ?? 0;
    if (count <= 0) {
      return const RecipeRatingSummary(averageRating: 0, ratingCount: 0);
    }
    final avg = (row['average_rating'] as num?)?.toDouble() ?? 0;
    return RecipeRatingSummary(averageRating: avg, ratingCount: count);
  }

  static List<String> _recipeIds(Iterable<GeneratedRecipe> recipes) {
    return recipes
        .map((r) => r.id)
        .whereType<String>()
        .where(isSupabaseRecipeId)
        .toSet()
        .toList();
  }

  /// Preload community ratings for a list of recipes (e.g. grid screens).
  static Future<void> prefetchSummaries(Iterable<GeneratedRecipe> recipes) async {
    if (_client.auth.currentUser == null) return;
    final ids = _recipeIds(recipes)
        .where((id) => !_summaryCache.containsKey(id))
        .toList();
    if (ids.isEmpty) return;

    try {
      final rows = await _client.rpc(
        'get_recipe_rating_summaries',
        params: {'p_recipe_ids': ids},
      );
      if (rows is! List) return;

      final returned = <String>{};
      for (final raw in rows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        final id = row['recipe_id']?.toString();
        if (id == null) continue;
        returned.add(id);
        _summaryCache[id] = _parseSummaryRow(row)!;
      }

      for (final id in ids) {
        if (!returned.contains(id)) {
          _summaryCache[id] =
              const RecipeRatingSummary(averageRating: 0, ratingCount: 0);
        }
      }
      _bumpSummaries();
    } catch (e) {
      debugPrint('prefetchSummaries failed: $e');
    }
  }

  static String cacheKeyFor(GeneratedRecipe recipe) {
    final id = recipe.id;
    if (id != null && isSupabaseRecipeId(id)) return '$_prefix$id';
    if (recipe.externalSource != null && recipe.externalId != null) {
      return '$_prefix${recipe.externalSource}_${recipe.externalId}';
    }
    return '$_prefix${recipe.title.trim().toLowerCase().hashCode}';
  }

  static Future<int?> getRating(GeneratedRecipe recipe) async {
    final remote = await _fetchRemoteRating(recipe.id);
    if (remote != null) {
      await _cacheLocal(recipe, remote);
      return remote;
    }
    return _readLocal(recipe);
  }

  /// Community average for a recipe (all users).
  static Future<RecipeRatingSummary?> getSummary(GeneratedRecipe recipe) async {
    final recipeId = recipe.id;
    if (recipeId == null ||
        !isSupabaseRecipeId(recipeId) ||
        _client.auth.currentUser == null) {
      return null;
    }

    final cached = _summaryCache[recipeId];
    if (cached != null) return cached;

    try {
      final row = await _client
          .rpc('get_recipe_rating_summary', params: {'p_recipe_id': recipeId})
          .maybeSingle();
      if (row == null) return null;
      final summary = _parseSummaryRow(Map<String, dynamic>.from(row));
      if (summary != null) _summaryCache[recipeId] = summary;
      return summary;
    } catch (e) {
      debugPrint('getSummary failed: $e');
      return null;
    }
  }

  static Future<RecipeRatingResult> setRating(
    GeneratedRecipe recipe,
    int stars,
  ) async {
    final rating = stars.clamp(1, 5);
    var resolved = recipe;

    if (resolved.id == null || !isSupabaseRecipeId(resolved.id)) {
      final persisted = await RecipeService.ensureRecipePersisted(resolved);
      if (persisted != null) resolved = persisted;
    }

    var synced = false;
    final recipeId = resolved.id;
    if (recipeId != null &&
        isSupabaseRecipeId(recipeId) &&
        _client.auth.currentUser != null) {
      synced = await _upsertRemote(recipeId, rating);
      invalidateSummary(recipeId);
    }

    await _cacheLocal(resolved, rating);

    return RecipeRatingResult(
      rating: rating,
      recipe: resolved,
      syncedToServer: synced,
    );
  }

  static Future<void> clearRating(GeneratedRecipe recipe) async {
    final recipeId = recipe.id;
    if (recipeId != null &&
        isSupabaseRecipeId(recipeId) &&
        _client.auth.currentUser != null) {
      try {
        await _client
            .from('recipe_ratings')
            .delete()
            .eq('user_id', _client.auth.currentUser!.id)
            .eq('recipe_id', recipeId);
      } catch (e) {
        debugPrint('clearRating remote failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKeyFor(recipe));
  }

  static Future<int?> _fetchRemoteRating(String? recipeId) async {
    if (recipeId == null ||
        !isSupabaseRecipeId(recipeId) ||
        _client.auth.currentUser == null) {
      return null;
    }
    try {
      final row = await _client
          .from('recipe_ratings')
          .select('rating')
          .eq('user_id', _client.auth.currentUser!.id)
          .eq('recipe_id', recipeId)
          .maybeSingle();
      final value = row?['rating'];
      if (value is num) {
        final rating = value.toInt();
        if (rating >= 1 && rating <= 5) return rating;
      }
    } catch (e) {
      debugPrint('getRating remote failed: $e');
    }
    return null;
  }

  static Future<bool> _upsertRemote(String recipeId, int rating) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('recipe_ratings').upsert(
        {
          'user_id': user.id,
          'recipe_id': recipeId,
          'rating': rating,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,recipe_id',
      );
      return true;
    } catch (e) {
      debugPrint('setRating remote failed: $e');
      return false;
    }
  }

  static Future<int?> _readLocal(GeneratedRecipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(cacheKeyFor(recipe));
    if (value == null || value < 1 || value > 5) return null;
    return value;
  }

  static Future<void> _cacheLocal(GeneratedRecipe recipe, int rating) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(cacheKeyFor(recipe), rating.clamp(1, 5));
  }
}
