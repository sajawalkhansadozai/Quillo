// Ingredient-specific visuals: app illustration assets first, then food emoji.

class IngredientVisual {
  final String? assetPath;
  final String emoji;

  const IngredientVisual({this.assetPath, required this.emoji});

  bool get hasAsset => assetPath != null;
}

IngredientVisual ingredientVisualFor(String name) {
  final n = name.toLowerCase();

  for (final rule in _rules) {
    if (rule.keywords.any((k) => _matchesKeyword(n, k))) {
      return IngredientVisual(assetPath: rule.asset, emoji: rule.emoji);
    }
  }
  return const IngredientVisual(emoji: '🥄');
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

class _VisualRule {
  final List<String> keywords;
  final String emoji;
  final String? asset;
  const _VisualRule(this.keywords, this.emoji, {this.asset});
}

const _rules = <_VisualRule>[
  // App illustrations (match onboarding style)
  _VisualRule(['tomato', 'marinara', 'passata'], '🍅', asset: 'assets/onboarding/signin_deco_tomato.png'),
  _VisualRule(['garlic'], '🧄', asset: 'assets/onboarding/signin_deco_garlic.png'),
  _VisualRule(['lemon', 'lime', 'citrus'], '🍋', asset: 'assets/onboarding/deco_lemon.png'),
  _VisualRule(['broccoli', 'cauliflower'], '🥦', asset: 'assets/onboarding/signin_deco_broccoli.png'),
  _VisualRule(['mint'], '🌿', asset: 'assets/onboarding/deco_mint.png'),
  _VisualRule(['bell pepper', 'jalape', 'habanero', 'chili', 'capsicum'], '🫑'),
  _VisualRule(['paprika', 'cayenne', 'chili powder'], '🌶️', asset: 'assets/onboarding/deco_pepper.png'),

  // Oils & liquids
  _VisualRule(['olive oil', 'vegetable oil', 'canola oil', 'sesame oil', 'coconut oil'], '🫒'),
  _VisualRule(['oil'], '🫒'),
  _VisualRule(['vinegar', 'balsamic'], '🍶'),
  _VisualRule(['wine', 'beer', 'sake'], '🍷'),
  _VisualRule(['water', 'broth', 'stock', 'soup'], '🍲'),

  // Proteins
  _VisualRule(['chicken', 'turkey', 'duck', 'poultry'], '🍗'),
  _VisualRule(['beef', 'steak', 'veal', 'brisket'], '🥩'),
  _VisualRule(['lamb', 'goat', 'mutton'], '🍖'),
  _VisualRule(['pork', 'bacon', 'ham', 'sausage', 'chorizo'], '🥓'),
  _VisualRule(['fish', 'salmon', 'tuna', 'cod', 'trout', 'anchovy'], '🐟'),
  _VisualRule(['shrimp', 'prawn', 'crab', 'lobster', 'scallop'], '🦐'),

  // Dairy & eggs
  _VisualRule(['egg'], '🥚'),
  _VisualRule(['milk', 'buttermilk', 'cream'], '🥛'),
  _VisualRule(['cheese', 'parmesan', 'mozzarella', 'feta', 'ricotta'], '🧀'),
  _VisualRule(['butter', 'ghee', 'margarine'], '🧈'),
  _VisualRule(['yogurt'], '🥣'),

  // Grains & bread
  _VisualRule(['pasta', 'spaghetti', 'noodle', 'macaroni'], '🍝'),
  _VisualRule(['rice', 'quinoa', 'couscous'], '🍚'),
  _VisualRule(['bread', 'bun', 'roll', 'baguette', 'pita', 'naan', 'bagel'], '🍞'),
  _VisualRule(['flour', 'cornstarch', 'breadcrumb'], '🌾'),
  _VisualRule(['pizza'], '🍕'),

  // Produce
  _VisualRule(['onion', 'shallot', 'leek', 'scallion'], '🧅'),
  _VisualRule(['ginger'], '🫚'),
  _VisualRule(['potato', 'yam', 'sweet potato'], '🥔'),
  _VisualRule(['carrot', 'parsnip', 'turnip'], '🥕'),
  _VisualRule(['spinach', 'kale', 'lettuce', 'arugula', 'cabbage'], '🥬'),
  _VisualRule(['cucumber', 'zucchini'], '🥒'),
  _VisualRule(['eggplant', 'aubergine'], '🍆'),
  _VisualRule(['avocado'], '🥑'),
  _VisualRule(['corn', 'maize'], '🌽'),
  _VisualRule(['mushroom', 'truffle'], '🍄'),
  _VisualRule(['bean', 'pea', 'lentil', 'chickpea'], '🫘'),
  _VisualRule(['celery', 'fennel', 'asparagus'], '🥬'),
  _VisualRule(['green olive', 'black olive', 'olives', 'pitted olive', 'caper'], '🫒'),
  _VisualRule(['pickle'], '🥒'),

  // Herbs
  _VisualRule(
    ['parsley', 'basil', 'cilantro', 'thyme', 'rosemary', 'dill', 'oregano', 'sage'],
    '🌿',
  ),

  // Spices & sweet
  _VisualRule(['salt', 'kosher salt', 'sea salt'], '🧂'),
  _VisualRule(['black pepper', 'white pepper', 'peppercorn'], '🧂'),
  _VisualRule(['cumin', 'turmeric', 'cinnamon', 'nutmeg', 'clove', 'cardamom'], '🫙'),
  _VisualRule(['ras el hanout', 'spice', 'seasoning', 'curry'], '🌶️'),
  _VisualRule(['sugar', 'honey', 'maple syrup', 'molasses'], '🍯'),
  _VisualRule(['chocolate', 'cocoa'], '🍫'),
  _VisualRule(['vanilla'], '🍦'),

  // Fruits & nuts
  _VisualRule(['apple'], '🍎'),
  _VisualRule(['banana'], '🍌'),
  _VisualRule(['berry', 'strawberry', 'blueberry', 'raspberry'], '🫐'),
  _VisualRule(['orange', 'grapefruit'], '🍊'),
  _VisualRule(['grape'], '🍇'),
  _VisualRule(['pineapple'], '🍍'),
  _VisualRule(['mango'], '🥭'),
  _VisualRule(['peach', 'pear', 'plum', 'cherry'], '🍑'),
  _VisualRule(['coconut'], '🥥'),
  _VisualRule(['almond', 'walnut', 'pecan', 'cashew', 'peanut', 'pistachio'], '🥜'),

  // Other
  _VisualRule(['tofu', 'tempeh'], '🧈'),
  _VisualRule(['coffee', 'espresso'], '☕'),
  _VisualRule(['tea'], '🍵'),
  _VisualRule(['ketchup', 'mustard', 'mayonnaise', 'sauce'], '🥫'),
];
