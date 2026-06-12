// Merged shopping list — all recipes combined, grouped by supermarket aisle.

class ShoppingItemSource {
  final String listId;
  final int itemIndex;

  const ShoppingItemSource({
    required this.listId,
    required this.itemIndex,
  });
}

class MergedShoppingItem {
  final String key;
  final String name;
  final String amount;
  final String categoryId;
  final bool checked;
  final List<ShoppingItemSource> sources;

  const MergedShoppingItem({
    required this.key,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.checked,
    required this.sources,
  });

  MergedShoppingItem copyWith({bool? checked}) => MergedShoppingItem(
        key: key,
        name: name,
        amount: amount,
        categoryId: categoryId,
        checked: checked ?? this.checked,
        sources: sources,
      );
}

class ShoppingListCategory {
  final String id;
  final String label;
  final List<MergedShoppingItem> items;

  const ShoppingListCategory({
    required this.id,
    required this.label,
    required this.items,
  });
}

class MergedShoppingListResult {
  final List<ShoppingListCategory> categories;
  final int recipeCount;

  const MergedShoppingListResult({
    required this.categories,
    this.recipeCount = 0,
  });

  static const empty = MergedShoppingListResult(categories: []);

  int get checkedCount => categories.fold(
        0,
        (n, c) => n + c.items.where((i) => i.checked).length,
      );

  int get totalCount =>
      categories.fold(0, (n, c) => n + c.items.length);
}
