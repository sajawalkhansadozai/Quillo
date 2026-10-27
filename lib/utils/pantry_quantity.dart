/// Converts recipe amounts and pantry quantities so a cook can deduct what
/// was used instead of deleting the whole item.
class PantryQuantity {
  PantryQuantity._();

  static const _generic = {
    'oil', 'milk', 'sauce', 'cheese', 'pepper', 'sugar', 'flour', 'cream',
    'rice', 'vinegar', 'powder', 'stock', 'broth', 'juice', 'wine', 'water',
    'salt', 'butter',
  };

  /// True when [shorter] is a more specific name inside [longer]
  /// ("red onion" covers "onion") and not a generic staple ("oil" vs "olive oil").
  static bool specificSubset(String shorter, String longer) {
    final a = shorter.split(' ').where((w) => w.isNotEmpty).toList();
    final b = longer.split(' ').where((w) => w.isNotEmpty).toList();
    if (a.isEmpty || a.length >= b.length) return false;
    if (!a.every(b.contains)) return false;
    if (a.length == 1 && _generic.contains(a.single)) return false;
    return a.every((t) => t.length >= 3);
  }

  static ({double value, String unit})? parse(String raw) {
    var t = raw.trim().toLowerCase();
    if (t.isEmpty) return null;
    t = t
        .replaceAll('½', '0.5')
        .replaceAll('¼', '0.25')
        .replaceAll('¾', '0.75')
        .replaceAll('⅓', '0.333')
        .replaceAll('⅔', '0.667');
    final match = RegExp(
      r'^(\d+(?:\.\d+)?|\d+\s*/\s*\d+)\s*(.*)$',
    ).firstMatch(t);
    if (match == null) return null;
    final value = _number(match.group(1)!);
    if (value == null || value <= 0) return null;
    return (value: value, unit: canon(match.group(2) ?? ''));
  }

  /// Quantity left in [haveUnit], or null when the units can't be compared.
  /// Zero means the pantry item was used up.
  static double? remaining({
    required double have,
    required String haveUnit,
    required double use,
    required String useUnit,
  }) {
    final h = _base(have, canon(haveUnit));
    final u = _base(use, canon(useUnit));
    if (h == null || u == null || h.dim != u.dim) return null;
    final left = h.value - u.value;
    if (left <= 0.0001) return 0;
    final converted = _fromBase(left, canon(haveUnit));
    final rounded = (converted * 100).round() / 100;
    return rounded;
  }

  static String canon(String unit) {
    final u = unit.toLowerCase().trim();
    switch (u) {
      case 'piece':
      case 'pieces':
      case 'pc':
      case 'pcs':
        return 'pcs';
      case 'tablespoon':
      case 'tablespoons':
      case 'tbsp':
        return 'tbsp';
      case 'teaspoon':
      case 'teaspoons':
      case 'tsp':
        return 'tsp';
      case 'cup':
      case 'cups':
        return 'cup';
      case 'gram':
      case 'grams':
        return 'g';
      case 'kilogram':
      case 'kilograms':
        return 'kg';
      case 'millilitre':
      case 'milliliter':
      case 'millilitres':
      case 'milliliters':
      case 'ml':
        return 'ml';
      case 'litre':
      case 'liter':
      case 'litres':
      case 'liters':
      case 'l':
        return 'l';
      default:
        return u;
    }
  }

  static double? _number(String raw) {
    final numStr = raw.replaceAll(' ', '');
    if (numStr.contains('/')) {
      final parts = numStr.split('/');
      if (parts.length != 2) return null;
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a == null || b == null || b == 0) return null;
      return a / b;
    }
    return double.tryParse(numStr);
  }

  static ({String dim, double value})? _base(double amount, String unit) {
    switch (unit) {
      case 'g':
        return (dim: 'mass', value: amount);
      case 'kg':
        return (dim: 'mass', value: amount * 1000);
      case 'ml':
        return (dim: 'volume', value: amount);
      case 'l':
        return (dim: 'volume', value: amount * 1000);
      case 'tsp':
        return (dim: 'volume', value: amount * 5);
      case 'tbsp':
        return (dim: 'volume', value: amount * 15);
      case 'cup':
        return (dim: 'volume', value: amount * 240);
      case 'pcs':
      case '':
        return (dim: 'count', value: amount);
      default:
        return null;
    }
  }

  static double _fromBase(double base, String unit) {
    switch (unit) {
      case 'kg':
        return base / 1000;
      case 'l':
        return base / 1000;
      case 'tbsp':
        return base / 15;
      case 'tsp':
        return base / 5;
      case 'cup':
        return base / 240;
      default:
        return base;
    }
  }
}
