import 'package:flutter/material.dart';

enum IngredientCategory {
  protein,
  seafood,
  dairy,
  produce,
  grain,
  spice,
  oil,
  pantry,
}

/// Soft accent color for the ingredient pill left stripe.
Color ingredientCategoryColor(String name) {
  switch (ingredientCategoryFor(name)) {
    case IngredientCategory.protein:
      return const Color(0xFFE57373);
    case IngredientCategory.seafood:
      return const Color(0xFF4FC3F7);
    case IngredientCategory.dairy:
      return const Color(0xFFFFD54F);
    case IngredientCategory.produce:
      return const Color(0xFF81C784);
    case IngredientCategory.grain:
      return const Color(0xFFFFB74D);
    case IngredientCategory.spice:
      return const Color(0xFFBA68C8);
    case IngredientCategory.oil:
      return const Color(0xFF64B5F6);
    case IngredientCategory.pantry:
      return const Color(0xFF9B9BB8);
  }
}

IngredientCategory ingredientCategoryFor(String name) {
  final n = name.toLowerCase();

  for (final rule in _rules) {
    if (rule.keywords.any((k) => _matchesKeyword(n, k))) {
      return rule.category;
    }
  }
  return IngredientCategory.pantry;
}

bool _matchesKeyword(String text, String keyword) {
  final k = keyword.toLowerCase().trim();
  if (k.isEmpty) return false;

  final isPhrase = k.contains(' ') || k.contains('-') || k.startsWith("'");
  if (isPhrase) return text.contains(k);

  final pattern = RegExp(
    '(?<![a-z])${RegExp.escape(k)}(es|s)?(?![a-z])',
  );
  return pattern.hasMatch(text);
}

class _CategoryRule {
  final List<String> keywords;
  final IngredientCategory category;
  const _CategoryRule(this.keywords, this.category);
}

const _rules = <_CategoryRule>[
  _CategoryRule(
    ['olive oil', 'vegetable oil', 'canola oil', 'sesame oil', 'coconut oil', 'oil'],
    IngredientCategory.oil,
  ),
  _CategoryRule(
    [
      'chicken', 'turkey', 'duck', 'beef', 'steak', 'veal', 'lamb', 'goat',
      'mutton', 'pork', 'bacon', 'ham', 'sausage', 'meat', 'venison',
    ],
    IngredientCategory.protein,
  ),
  _CategoryRule(
    [
      'fish', 'salmon', 'tuna', 'shrimp', 'prawn', 'crab', 'lobster',
      'scallop', 'clam', 'mussel', 'oyster', 'anchovy', 'cod',
    ],
    IngredientCategory.seafood,
  ),
  _CategoryRule(
    [
      'milk', 'cream', 'cheese', 'butter', 'yogurt', 'egg', 'ghee',
      'parmesan', 'mozzarella', 'feta', 'ricotta',
    ],
    IngredientCategory.dairy,
  ),
  _CategoryRule(
    [
      'onion', 'garlic', 'tomato', 'potato', 'carrot', 'spinach', 'lettuce',
      'pepper', 'mushroom', 'broccoli', 'celery', 'fennel', 'herb', 'parsley',
      'basil', 'cilantro', 'mint', 'avocado', 'cucumber', 'zucchini', 'squash',
      'bean', 'pea', 'corn', 'olive', 'pickle', 'ginger', 'fruit', 'lemon',
      'lime', 'apple', 'banana', 'berry',
    ],
    IngredientCategory.produce,
  ),
  _CategoryRule(
    [
      'rice', 'pasta', 'noodle', 'bread', 'flour', 'quinoa', 'barley',
      'tortilla', 'pita', 'naan', 'breadcrumb', 'cornmeal',
    ],
    IngredientCategory.grain,
  ),
  _CategoryRule(
    [
      'salt', 'pepper', 'cumin', 'paprika', 'turmeric', 'cinnamon', 'spice',
      'seasoning', 'nutmeg', 'clove', 'curry', 'vanilla', 'sugar', 'honey',
    ],
    IngredientCategory.spice,
  ),
];
