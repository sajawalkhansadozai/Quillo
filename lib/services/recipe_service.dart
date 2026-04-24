import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ingredient_item.dart';
import '../models/generated_recipe.dart';
import 'scan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecipeService — calls the generate-recipes Edge Function and handles
// saving / loading recipes from Supabase.
// ─────────────────────────────────────────────────────────────────────────────

class RecipeService {
  static final _client = Supabase.instance.client;

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
    return rawList
        .map((r) => GeneratedRecipe.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Save a recipe to saved_recipes ─────────────────────────────────────────

  static Future<void> saveRecipe(GeneratedRecipe recipe) async {
    final user = _client.auth.currentUser;
    if (user == null || recipe.id == null) return;
    try {
      await _client.from('saved_recipes').upsert(
        {
          'user_id': user.id,
          'recipe_id': recipe.id,
          'cached_data': recipe.toJson(),
        },
        onConflict: 'user_id,recipe_id',
      );
    } catch (_) {}
  }

  // ── Remove a recipe from saved_recipes ─────────────────────────────────────

  static Future<void> unsaveRecipe(String recipeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client
          .from('saved_recipes')
          .delete()
          .eq('user_id', user.id)
          .eq('recipe_id', recipeId);
    } catch (_) {}
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
