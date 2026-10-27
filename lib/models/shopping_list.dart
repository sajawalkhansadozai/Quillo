// ─────────────────────────────────────────────────────────────────────────────
// Shopping list — saved from a recipe's ingredients
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingListItem {
  final String name;
  final String amount;
  /// Prep tip shown under the name (e.g. "Peeled and minced").
  final String note;
  final bool checked;

  const ShoppingListItem({
    required this.name,
    required this.amount,
    this.note = '',
    this.checked = false,
  });

  ShoppingListItem copyWith({bool? checked, String? note, String? amount}) =>
      ShoppingListItem(
        name: name,
        amount: amount ?? this.amount,
        note: note ?? this.note,
        checked: checked ?? this.checked,
      );

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        name: json['name'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
        note: json['note'] as String? ?? '',
        checked: json['checked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        if (note.isNotEmpty) 'note': note,
        'checked': checked,
      };
}

class ShoppingList {
  /// Items added from the pantry ("Add to list"), not from a recipe.
  static const pantryRestockId = 'pantry_restock';

  final String id;
  final String recipeName;
  final String? recipeId;
  final List<ShoppingListItem> items;
  final DateTime createdAt;

  const ShoppingList({
    required this.id,
    required this.recipeName,
    this.recipeId,
    required this.items,
    required this.createdAt,
  });

  int get totalCount => items.length;
  int get checkedCount => items.where((i) => i.checked).length;

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ShoppingList(
      id: json['id'] as String,
      recipeName: json['recipe_name'] as String? ?? 'Shopping List',
      recipeId: json['recipe_id'] as String?,
      items: rawItems
          .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_name': recipeName,
        if (recipeId != null) 'recipe_id': recipeId,
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}
