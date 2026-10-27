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
  return const IngredientVisual(
    assetPath: 'assets/food_3d/spoon.png',
    emoji: '🥄',
  );
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
  _VisualRule(['tomato', 'marinara', 'passata'], '🍅', asset: 'assets/food_3d/tomato.png'),
  _VisualRule(['garlic'], '🧄', asset: 'assets/food_3d/garlic.png'),
  _VisualRule(['lemon', 'lime', 'citrus'], '🍋', asset: 'assets/food_3d/lemon.png'),
  _VisualRule(['broccoli', 'cauliflower'], '🥦', asset: 'assets/food_3d/broccoli.png'),
  _VisualRule(['bell pepper', 'capsicum'], '🫑', asset: 'assets/food_3d/bell_pepper.png'),
  _VisualRule(
    ['jalape', 'habanero', 'chili', 'chilli', 'cayenne', 'paprika', 'hot pepper'],
    '🌶️',
    asset: 'assets/food_3d/hot_pepper.png',
  ),
  _VisualRule(['ginger'], '🫚', asset: 'assets/food_3d/ginger_root.png'),
  _VisualRule(['avocado'], '🥑', asset: 'assets/food_3d/avocado.png'),
  _VisualRule(['bacon'], '🥓', asset: 'assets/food_3d/bacon.png'),
  _VisualRule(['bagel'], '🥯', asset: 'assets/food_3d/bagel.png'),
  _VisualRule(['baguette'], '🥖', asset: 'assets/food_3d/baguette_bread.png'),
  _VisualRule(['croissant'], '🥐', asset: 'assets/food_3d/croissant.png'),
  _VisualRule(['banana'], '🍌', asset: 'assets/food_3d/banana.png'),
  _VisualRule(['pea', 'peas'], '🫛', asset: 'assets/food_3d/pea_pod.png'),
  _VisualRule(['bean', 'lentil', 'chickpea'], '🫘', asset: 'assets/food_3d/beans.png'),
  _VisualRule(['butter', 'ghee', 'margarine'], '🧈', asset: 'assets/food_3d/butter.png'),
  _VisualRule(['carrot', 'parsnip'], '🥕', asset: 'assets/food_3d/carrot.png'),
  _VisualRule(['cheese', 'parmesan', 'mozzarella', 'feta', 'cheddar', 'ricotta'], '🧀', asset: 'assets/food_3d/cheese_wedge.png'),
  _VisualRule(['cherry'], '🍒', asset: 'assets/food_3d/cherries.png'),
  _VisualRule(['chestnut'], '🌰', asset: 'assets/food_3d/chestnut.png'),
  _VisualRule(['chocolate', 'cocoa'], '🍫', asset: 'assets/food_3d/chocolate_bar.png'),
  _VisualRule(['olive oil', 'sesame oil', 'coconut oil', 'vegetable oil', 'canola oil', 'oil'], '🫒', asset: 'assets/food_3d/olive.png'),
  _VisualRule(['coconut'], '🥥', asset: 'assets/food_3d/coconut.png'),
  _VisualRule(['cookie', 'biscuit'], '🍪', asset: 'assets/food_3d/cookie.png'),
  _VisualRule(['cucumber', 'zucchini', 'pickle'], '🥒', asset: 'assets/food_3d/cucumber.png'),
  _VisualRule(['cupcake', 'cake'], '🧁', asset: 'assets/food_3d/cupcake.png'),
  _VisualRule(['corn', 'maize'], '🌽', asset: 'assets/food_3d/ear_of_corn.png'),
  _VisualRule(['egg'], '🥚', asset: 'assets/food_3d/egg.png'),
  _VisualRule(['eggplant', 'aubergine'], '🍆', asset: 'assets/food_3d/eggplant.png'),
  _VisualRule(['shrimp', 'prawn', 'crab', 'lobster', 'scallop'], '🦐', asset: 'assets/food_3d/shrimp.png'),
  _VisualRule(['fish', 'salmon', 'tuna', 'cod', 'trout', 'anchovy'], '🐟', asset: 'assets/food_3d/fish.png'),
  _VisualRule(['pita', 'naan', 'tortilla', 'flatbread', 'wrap'], '🫓', asset: 'assets/food_3d/flatbread.png'),
  _VisualRule(['milk', 'buttermilk', 'cream'], '🥛', asset: 'assets/food_3d/glass_of_milk.png'),
  _VisualRule(['grape'], '🍇', asset: 'assets/food_3d/grapes.png'),
  _VisualRule(['green apple'], '🍏', asset: 'assets/food_3d/green_apple.png'),
  _VisualRule(['salad', 'lettuce'], '🥗', asset: 'assets/food_3d/green_salad.png'),
  _VisualRule(['burger', 'hamburger'], '🍔', asset: 'assets/food_3d/hamburger.png'),
  _VisualRule(
    ['parsley', 'basil', 'cilantro', 'coriander', 'thyme', 'rosemary', 'dill', 'oregano', 'sage', 'mint', 'herb'],
    '🌿',
    asset: 'assets/food_3d/herb.png',
  ),
  _VisualRule(['honey'], '🍯', asset: 'assets/food_3d/honey_pot.png'),
  _VisualRule(['coffee', 'espresso'], '☕', asset: 'assets/food_3d/hot_beverage.png'),
  _VisualRule(['ice cream', 'gelato'], '🍦', asset: 'assets/food_3d/soft_ice_cream.png'),
  _VisualRule(['kiwi'], '🥝', asset: 'assets/food_3d/kiwi_fruit.png'),
  _VisualRule(['spinach', 'kale', 'cabbage', 'arugula', 'rocket'], '🥬', asset: 'assets/food_3d/leafy_green.png'),
  _VisualRule(['mango'], '🥭', asset: 'assets/food_3d/mango.png'),
  _VisualRule(['melon', 'cantaloupe'], '🍈', asset: 'assets/food_3d/melon.png'),
  _VisualRule(['mushroom'], '🍄', asset: 'assets/food_3d/mushroom.png'),
  _VisualRule(['olive', 'caper'], '🫒', asset: 'assets/food_3d/olive.png'),
  _VisualRule(['onion', 'shallot', 'leek', 'scallion'], '🧅', asset: 'assets/food_3d/onion.png'),
  _VisualRule(['pancake'], '🥞', asset: 'assets/food_3d/pancakes.png'),
  _VisualRule(['peach', 'nectarine'], '🍑', asset: 'assets/food_3d/peach.png'),
  _VisualRule(['almond', 'walnut', 'pecan', 'cashew', 'peanut', 'pistachio', 'nut'], '🥜', asset: 'assets/food_3d/peanuts.png'),
  _VisualRule(['pear'], '🍐', asset: 'assets/food_3d/pear.png'),
  _VisualRule(['pineapple'], '🍍', asset: 'assets/food_3d/pineapple.png'),
  _VisualRule(['pizza'], '🍕', asset: 'assets/food_3d/pizza.png'),
  _VisualRule(['sweet potato', 'yam'], '🍠', asset: 'assets/food_3d/roasted_sweet_potato.png'),
  _VisualRule(['potato'], '🥔', asset: 'assets/food_3d/potato.png'),
  _VisualRule(['chicken', 'turkey', 'duck', 'poultry'], '🍗', asset: 'assets/food_3d/poultry_leg.png'),
  _VisualRule(['beef', 'steak', 'veal', 'lamb', 'pork', 'ham', 'sausage', 'chorizo', 'meat', 'mince'], '🥩', asset: 'assets/food_3d/cut_of_meat.png'),
  _VisualRule(['apple'], '🍎', asset: 'assets/food_3d/red_apple.png'),
  _VisualRule(['sushi', 'onigiri'], '🍙', asset: 'assets/food_3d/rice_ball.png'),
  _VisualRule(['rice', 'quinoa', 'couscous'], '🍚', asset: 'assets/food_3d/cooked_rice.png'),
  _VisualRule(['salt', 'peppercorn', 'black pepper', 'white pepper', 'pepper'], '🧂', asset: 'assets/food_3d/salt.png'),
  _VisualRule(['sandwich'], '🥪', asset: 'assets/food_3d/sandwich.png'),
  _VisualRule(['pasta', 'spaghetti', 'noodle', 'macaroni'], '🍝', asset: 'assets/food_3d/spaghetti.png'),
  _VisualRule(['soup', 'broth', 'stock', 'stew', 'ramen'], '🍲', asset: 'assets/food_3d/steaming_bowl.png'),
  _VisualRule(['strawberry'], '🍓', asset: 'assets/food_3d/strawberry.png'),
  _VisualRule(['blueberry', 'raspberry', 'berry'], '🫐', asset: 'assets/food_3d/blueberries.png'),
  _VisualRule(['taco'], '🌮', asset: 'assets/food_3d/taco.png'),
  _VisualRule(['orange', 'tangerine', 'mandarin', 'clementine', 'grapefruit'], '🍊', asset: 'assets/food_3d/tangerine.png'),
  _VisualRule(['tea'], '🍵', asset: 'assets/food_3d/teacup_without_handle.png'),
  _VisualRule(['watermelon'], '🍉', asset: 'assets/food_3d/watermelon.png'),
  _VisualRule(['wine', 'beer', 'champagne', 'sake'], '🍷', asset: 'assets/food_3d/bottle_with_popping_cork.png'),
  _VisualRule(['bread', 'bun', 'roll'], '🍞', asset: 'assets/food_3d/bread.png'),
  _VisualRule(['vinegar', 'balsamic', 'ketchup', 'mustard', 'mayonnaise', 'jam', 'sauce', 'flour', 'sugar', 'spice', 'seasoning'], '🫙', asset: 'assets/food_3d/jar.png'),
  _VisualRule(['yogurt', 'yoghurt'], '🥣', asset: 'assets/food_3d/bowl_with_spoon.png'),
  _VisualRule(['ice'], '🧊', asset: 'assets/food_3d/ice.png'),
  _VisualRule(['curry', 'casserole'], '🥘', asset: 'assets/food_3d/shallow_pan_of_food.png'),
];
