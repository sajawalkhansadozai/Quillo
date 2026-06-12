import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/generated_recipe.dart';
import '../models/merged_shopping_list.dart';
import '../models/shopping_list.dart';
import 'local_db_service.dart';
import 'shopping_list_merge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShoppingListService — persist recipe ingredient lists locally
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingListService {
  static final _client = Supabase.instance.client;

  /// BigOven cloud grocery list (via edge function). Falls back to local parse on failure.
  static Future<List<ShoppingListItem>> itemsFromBigOvenCloud(
    String bigovenRecipeId, {
    int servings = 1,
  }) async {
    if (_client.auth.currentUser == null) return [];

    try {
      final response = await _client.functions.invoke(
        'sync-bigoven-grocery',
        body: {'recipe_id': bigovenRecipeId, 'scale': servings},
      );
      if (response.status != 200) return [];
      final data = response.data as Map<String, dynamic>?;
      final raw = data?['items'] as List<dynamic>? ?? [];
      return raw
          .map((i) {
            final m = Map<String, dynamic>.from(i as Map);
            return ShoppingListItem(
              name: m['name'] as String? ?? '',
              amount: m['amount'] as String? ?? '',
            );
          })
          .where((i) => i.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// All ingredients from the recipe (pantry + missing), deduped by name.
  static List<ShoppingListItem> itemsFromRecipe(GeneratedRecipe recipe) {
    final seen = <String>{};
    final items = <ShoppingListItem>[];

    void add(String name, String amount) {
      final key = name.trim().toLowerCase();
      if (name.trim().isEmpty || seen.contains(key)) return;
      seen.add(key);
      items.add(ShoppingListItem(name: name.trim(), amount: amount.trim()));
    }

    for (final i in recipe.ingredientsUsed) {
      add(i.name, i.amount);
    }
    for (final i in recipe.missingIngredients) {
      add(i.name, i.amount);
    }
    return items;
  }

  static Future<ShoppingList> saveFromRecipe(GeneratedRecipe recipe) async {
    var items = itemsFromRecipe(recipe);

    // BigOven: prefer cloud grocery list (full ingredient lines + departments).
    if (recipe.externalSource == 'bigoven' && recipe.externalId != null) {
      final cloud = await itemsFromBigOvenCloud(
        recipe.externalId!,
        servings: recipe.servings,
      );
      if (cloud.isNotEmpty) items = cloud;
    }

    if (items.isEmpty) {
      throw StateError('This recipe has no ingredients to add.');
    }

    final existing = recipe.id != null
        ? await LocalDbService.findShoppingListByRecipeId(recipe.id!)
        : null;

    final list = ShoppingList(
      id: existing?.id ??
          '${DateTime.now().millisecondsSinceEpoch}_${recipe.id ?? 'local'}',
      recipeName: recipe.title,
      recipeId: recipe.id,
      items: items,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    await LocalDbService.saveShoppingList(list);
    return list;
  }

  static Future<List<ShoppingList>> getAll() =>
      LocalDbService.loadAllShoppingLists();

  static Future<ShoppingList?> getById(String id) =>
      LocalDbService.loadShoppingList(id);

  static Future<void> update(ShoppingList list) =>
      LocalDbService.saveShoppingList(list);

  static Future<void> toggleItem(String listId, int index, bool checked) async {
    final list = await getById(listId);
    if (list == null || index < 0 || index >= list.items.length) return;
    final items = List<ShoppingListItem>.from(list.items);
    items[index] = items[index].copyWith(checked: checked);
    await update(ShoppingList(
      id: list.id,
      recipeName: list.recipeName,
      recipeId: list.recipeId,
      items: items,
      createdAt: list.createdAt,
    ));
  }

  static Future<void> delete(String id) => LocalDbService.deleteShoppingList(id);

  /// All recipe lists merged, deduped, and grouped by supermarket aisle.
  static Future<MergedShoppingListResult> getMergedList() async {
    final lists = await getAll();
    return ShoppingListMerge.merge(lists);
  }

  /// Tick merged row — updates every underlying recipe line.
  static Future<void> toggleMergedItem(
    MergedShoppingItem item,
    bool checked,
  ) async {
    for (final src in item.sources) {
      await toggleItem(src.listId, src.itemIndex, checked);
    }
  }

  /// Remove checked lines from all recipe lists (after a completed shop).
  static Future<int> removeCompletedItems() async {
    var removed = 0;
    for (final list in await getAll()) {
      final before = list.items.length;
      final remaining =
          list.items.where((i) => !i.checked).toList(growable: false);
      removed += before - remaining.length;
      if (remaining.isEmpty) {
        await delete(list.id);
      } else if (remaining.length != before) {
        await update(ShoppingList(
          id: list.id,
          recipeName: list.recipeName,
          recipeId: list.recipeId,
          items: remaining,
          createdAt: list.createdAt,
        ));
      }
    }
    return removed;
  }
}
