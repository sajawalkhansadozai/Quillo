import '../models/generated_recipe.dart';
import '../models/shopping_list.dart';
import 'local_db_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShoppingListService — persist recipe ingredient lists locally
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingListService {
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
    final items = itemsFromRecipe(recipe);
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
}
