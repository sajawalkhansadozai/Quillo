import '../models/merged_shopping_list.dart';
import '../models/shopping_list.dart';

/// Merges per-recipe shopping lists into one aisle-sorted checklist.
class ShoppingListMerge {
  ShoppingListMerge._();

  static const categoryOrder = [
    'produce',
    'meat',
    'dairy',
    'pantry',
    'carbs',
  ];

  static const categoryLabels = {
    'produce': 'Produce',
    'meat': 'Meat & Fish',
    'dairy': 'Dairy',
    'pantry': 'Pantry',
    'carbs': 'Bakery & Carbs',
  };

  static MergedShoppingListResult merge(List<ShoppingList> lists) {
    if (lists.isEmpty) return MergedShoppingListResult.empty;

    final groups = <String, List<({ShoppingList list, int index})>>{};

    for (final list in lists) {
      for (var i = 0; i < list.items.length; i++) {
        final item = list.items[i];
        final key = _slugKey(item.name);
        groups.putIfAbsent(key, () => []).add((list: list, index: i));
      }
    }

    final merged = <MergedShoppingItem>[];

    for (final entry in groups.entries) {
      final refs = entry.value;
      final first = refs.first.list.items[refs.first.index];
      final amounts = refs
          .map((r) => r.list.items[r.index].amount.trim())
          .where((a) => a.isNotEmpty)
          .toList();
      final allChecked = refs.every((r) => r.list.items[r.index].checked);

      merged.add(MergedShoppingItem(
        key: entry.key,
        name: _titleCase(first.name),
        amount: _mergeAmounts(amounts),
        categoryId: _guessCategory(first.name),
        checked: allChecked,
        sources: refs
            .map(
              (r) => ShoppingItemSource(
                listId: r.list.id,
                itemIndex: r.index,
              ),
            )
            .toList(),
      ));
    }

    final buckets = <String, List<MergedShoppingItem>>{
      for (final id in categoryOrder) id: [],
    };
    for (final item in merged) {
      final id =
          categoryOrder.contains(item.categoryId) ? item.categoryId : 'pantry';
      buckets[id]!.add(item);
    }

    final categories = <ShoppingListCategory>[];
    for (final id in categoryOrder) {
      final items = buckets[id]!
        ..sort((a, b) {
          if (a.checked != b.checked) return a.checked ? 1 : -1;
          return a.name.compareTo(b.name);
        });
      if (items.isEmpty) continue;
      categories.add(ShoppingListCategory(
        id: id,
        label: categoryLabels[id]!,
        items: items,
      ));
    }

    return MergedShoppingListResult(
      categories: categories,
      recipeCount: lists.length,
    );
  }

  /// Combines duplicate amounts e.g. "2 cloves" + "2 cloves" → "4 cloves".
  static String _mergeAmounts(List<String> amounts) {
    if (amounts.isEmpty) return '';
    if (amounts.length == 1) return amounts.first;

    final parsed = <_ParsedAmount>[];
    for (final a in amounts) {
      final p = _parseAmount(a);
      if (p != null) parsed.add(p);
    }

    if (parsed.length == amounts.length) {
      final byUnit = <String, double>{};
      for (final p in parsed) {
        final unitKey = p.unit.toLowerCase();
        byUnit[unitKey] = (byUnit[unitKey] ?? 0) + p.value;
      }
      if (byUnit.length == 1) {
        final e = byUnit.entries.first;
        return _formatAmount(e.value, e.key);
      }
    }

    return amounts.toSet().join(' + ');
  }

  static _ParsedAmount? _parseAmount(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(
      r'^([\d]+(?:\s*[/]\s*[\d]+)?)\s*(.*)$',
    ).firstMatch(trimmed);
    if (match == null) return null;

    final numStr = match.group(1)!.replaceAll(' ', '');
    double value;
    if (numStr.contains('/')) {
      final parts = numStr.split('/');
      if (parts.length != 2) return null;
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a == null || b == null || b == 0) return null;
      value = a / b;
    } else {
      final parsed = double.tryParse(numStr);
      if (parsed == null) return null;
      value = parsed;
    }

    return _ParsedAmount(value, match.group(2)!.trim());
  }

  static String _formatAmount(double value, String unit) {
    final n = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return unit.isEmpty ? n : '$n $unit';
  }

  static String _slugKey(String name) {
    final s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return s.isEmpty ? 'item' : s;
  }

  static String _titleCase(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _guessCategory(String name) {
    final n = name.toLowerCase();
    if (RegExp(
            r'\b(chicken|beef|pork|lamb|fish|salmon|prawn|shrimp|bacon|sausage|mince|steak|turkey|meat)\b')
        .hasMatch(n)) {
      return 'meat';
    }
    if (RegExp(
            r'\b(milk|cheese|butter|yogurt|yoghurt|cream|egg|mozzarella|cheddar|feta|dairy)\b')
        .hasMatch(n)) {
      return 'dairy';
    }
    if (RegExp(
            r'\b(bread|pasta|rice|noodle|flour|tortilla|wrap|bagel|potato|spaghetti|penne)\b')
        .hasMatch(n)) {
      return 'carbs';
    }
    if (RegExp(
            r'\b(tomato|onion|garlic|pepper|carrot|lettuce|spinach|herb|basil|parsley|coriander|lime|lemon|apple|banana|mushroom|cucumber|avocado|ginger|celery|broccoli)\b')
        .hasMatch(n)) {
      return 'produce';
    }
    return 'pantry';
  }
}

class _ParsedAmount {
  final double value;
  final String unit;
  _ParsedAmount(this.value, this.unit);
}
