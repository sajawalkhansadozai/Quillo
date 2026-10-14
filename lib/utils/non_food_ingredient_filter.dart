/// Strip non-food / non-cooking items before recipe generation (checklist 2.6).
class NonFoodIngredientFilter {
  NonFoodIngredientFilter._();

  static final _banned = RegExp(
    r'\b('
    r'carrier\s*bag|shopping\s*bag|bag\s*charge|plastic\s*bag|'
    r'detergent|bleach|disinfectant|cleaner|cleaning|soap|shampoo|'
    r'toothpaste|deodorant|cosmetics?|makeup|lotion|wipes?|'
    r'batter(?:y|ies)|light\s*bulb|toilet\s*roll|kitchen\s*roll|'
    r'medicine|paracetamol|ibuprofen|vitamin\s*tablet|supplement\s*tablet|'
    r'pet\s*food|cat\s*litter|dog\s*food|'
    r'cigarette|tobacco|lottery|gift\s*card|'
    r'delivery\s*fee|service\s*charge|vat|subtotal|total|loyalty'
    r')\b',
    caseSensitive: false,
  );

  static bool isFoodName(String name) {
    final t = name.trim();
    if (t.length < 2) return false;
    if (_banned.hasMatch(t)) return false;
    return true;
  }

  static List<T> filter<T>(
    List<T> items,
    String Function(T) nameOf,
  ) {
    return items.where((i) => isFoodName(nameOf(i))).toList();
  }
}
