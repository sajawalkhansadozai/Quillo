// Ingredient-specific visuals: app illustration assets first, then food emoji.
// Generated from assets/ingredients/*.png — do not hand-edit the rule list.

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
    assetPath: 'assets/ingredients/spoon.png',
    emoji: '🥄',
  );
}

bool _matchesKeyword(String text, String keyword) {
  final k = keyword.toLowerCase().trim();
  if (k.isEmpty) return false;

  final isPhrase = k.contains(' ') || k.contains('-') || k.startsWith("'");
  if (isPhrase) return text.contains(k);

  final pattern = RegExp('(?<![a-z])${RegExp.escape(k)}(es|s)?(?![a-z])');
  return pattern.hasMatch(text);
}

class _VisualRule {
  final List<String> keywords;
  final String emoji;
  final String? asset;
  const _VisualRule(this.keywords, this.emoji, {this.asset});
}

const _rules = <_VisualRule>[
  _VisualRule(
    ['frozen yorkshire puddings', 'frozen-yorkshire-puddings'],
    '🥄',
    asset: 'assets/ingredients/frozen-yorkshire-puddings.png',
  ),
  _VisualRule(
    ['frozen mixed berries', 'frozen-mixed-berries'],
    '🫐',
    asset: 'assets/ingredients/frozen-mixed-berries.png',
  ),
  _VisualRule(
    [
      'worcestershire sauce',
      'worcestershire-sauce',
      'worchestershire',
      'worcestershire',
    ],
    '🫙',
    asset: 'assets/ingredients/worcestershire-sauce.png',
  ),
  _VisualRule(
    [
      'bicarbonate of soda',
      'bicarbonate-of-soda',
      'baking soda',
      'bicarbonate',
      'bicarb',
    ],
    '🥄',
    asset: 'assets/ingredients/bicarbonate-of-soda.png',
  ),
  _VisualRule(
    ['coconut milk drink', 'coconut-milk-drink'],
    '🥥',
    asset: 'assets/ingredients/coconut-milk-drink.png',
  ),
  _VisualRule(
    ['fruit juice carton', 'fruit-juice-carton'],
    '🧊',
    asset: 'assets/ingredients/fruit-juice-carton.png',
  ),
  _VisualRule(
    ['roast sweet potato', 'roast-sweet-potato'],
    '🍠',
    asset: 'assets/ingredients/roast-sweet-potato.png',
  ),
  _VisualRule(
    [
      'self raising flour',
      'self-raising-flour',
      'self rising flour',
      'self-rising flour',
    ],
    '🍇',
    asset: 'assets/ingredients/self-raising-flour.png',
  ),
  _VisualRule(
    ['chicken drumsticks', 'chicken-drumsticks'],
    '🍗',
    asset: 'assets/ingredients/chicken-drumsticks.png',
  ),
  _VisualRule(
    [
      'desiccated coconut',
      'desiccated-coconut',
      'shredded coconut',
      'dried coconut',
    ],
    '🥥',
    asset: 'assets/ingredients/desiccated-coconut.png',
  ),
  _VisualRule(
    ['generic household', 'generic-household'],
    '🥄',
    asset: 'assets/ingredients/generic-household.png',
  ),
  _VisualRule(
    ['generic vegetable', 'generic-vegetable'],
    '🥄',
    asset: 'assets/ingredients/generic-vegetable.png',
  ),
  _VisualRule(
    ['shortcrust pastry', 'shortcrust-pastry'],
    '🥄',
    asset: 'assets/ingredients/shortcrust-pastry.png',
  ),
  _VisualRule(
    ['coconut milk tin', 'coconut-milk-tin'],
    '🥥',
    asset: 'assets/ingredients/coconut-milk-tin.png',
  ),
  _VisualRule(
    ['generic non food', 'generic-non-food'],
    '🥄',
    asset: 'assets/ingredients/generic-non-food.png',
  ),
  _VisualRule(
    ['mixed frozen veg', 'mixed-frozen-veg'],
    '🥄',
    asset: 'assets/ingredients/mixed-frozen-veg.png',
  ),
  _VisualRule(
    ['balsamic vinegar', 'balsamic-vinegar', 'balsamic'],
    '🫙',
    asset: 'assets/ingredients/balsamic-vinegar.png',
  ),
  _VisualRule(
    ['brussels sprouts', 'brussels-sprouts', 'brussel sprouts', 'brussels'],
    '🥬',
    asset: 'assets/ingredients/brussels-sprouts.png',
  ),
  _VisualRule(
    ['butternut squash', 'butternut-squash', 'winter squash', 'butternut'],
    '🧈',
    asset: 'assets/ingredients/butternut-squash.png',
  ),
  _VisualRule(
    ['generic cupboard', 'generic-cupboard'],
    '🥄',
    asset: 'assets/ingredients/generic-cupboard.png',
  ),
  _VisualRule(
    ['tinned chickpeas', 'tinned-chickpeas'],
    '🫛',
    asset: 'assets/ingredients/tinned-chickpeas.png',
  ),
  _VisualRule(
    ['tinned sweetcorn', 'tinned-sweetcorn'],
    '🌽',
    asset: 'assets/ingredients/tinned-sweetcorn.png',
  ),
  _VisualRule(
    ['fizzy drink can', 'fizzy-drink-can'],
    '🥄',
    asset: 'assets/ingredients/fizzy-drink-can.png',
  ),
  _VisualRule(
    ['chicken nuggets', 'chicken-nuggets'],
    '🍗',
    asset: 'assets/ingredients/chicken-nuggets.png',
  ),
  _VisualRule(
    ['chocolate chips', 'chocolate-chips'],
    '🍫',
    asset: 'assets/ingredients/chocolate-chips.png',
  ),
  _VisualRule(
    ['instant noodles', 'instant-noodles'],
    '🍝',
    asset: 'assets/ingredients/instant-noodles.png',
  ),
  _VisualRule(
    ['sunflower seeds', 'sunflower-seeds', 'sunflower seed'],
    '🥜',
    asset: 'assets/ingredients/sunflower-seeds.png',
  ),
  _VisualRule(
    ['canned sardines', 'tinned sardines', 'tinned-sardines'],
    '🐟',
    asset: 'assets/ingredients/tinned-sardines.png',
  ),
  _VisualRule(
    [
      'chopped tomatoes',
      'canned tomatoes',
      'tinned tomatoes',
      'tinned-tomatoes',
      'tinned tomato',
    ],
    '🍅',
    asset: 'assets/ingredients/tinned-tomatoes.png',
  ),
  _VisualRule(
    ['vanilla essence', 'vanilla extract', 'vanilla-extract', 'vanilla'],
    '🥄',
    asset: 'assets/ingredients/vanilla-extract.png',
  ),
  _VisualRule(
    ['burger patties', 'burger-patties'],
    '🍔',
    asset: 'assets/ingredients/burger-patties.png',
  ),
  _VisualRule(
    ['chicken breasts', 'chicken breast', 'chicken-breast'],
    '🍗',
    asset: 'assets/ingredients/chicken-breast.png',
  ),
  _VisualRule(
    ['chicken thighs', 'chicken-thighs', 'chicken thigh'],
    '🍗',
    asset: 'assets/ingredients/chicken-thighs.png',
  ),
  _VisualRule(
    [
      'coriander seeds',
      'cilantro seeds',
      'coriander seed',
      'coriander-seed',
      'cilantro seed',
    ],
    '🌿',
    asset: 'assets/ingredients/coriander-seed.png',
  ),
  _VisualRule(
    ['cottage cheese', 'cottage-cheese', 'pot cheese'],
    '🧀',
    asset: 'assets/ingredients/cottage-cheese.png',
  ),
  _VisualRule(
    ['dried apricots', 'dried-apricots', 'dried apricot'],
    '🍑',
    asset: 'assets/ingredients/dried-apricots.png',
  ),
  _VisualRule(
    ['food colouring', 'food-colouring'],
    '🥄',
    asset: 'assets/ingredients/food-colouring.png',
  ),
  _VisualRule(
    ['generic bakery', 'generic-bakery'],
    '🥄',
    asset: 'assets/ingredients/generic-bakery.png',
  ),
  _VisualRule(
    ['generic frozen', 'generic-frozen'],
    '🥄',
    asset: 'assets/ingredients/generic-frozen.png',
  ),
  _VisualRule(
    ['glace cherries', 'glace-cherries'],
    '🍒',
    asset: 'assets/ingredients/glace-cherries.png',
  ),
  _VisualRule(
    ['gravy granules', 'gravy-granules', 'gravy mix'],
    '🍲',
    asset: 'assets/ingredients/gravy-granules.png',
  ),
  _VisualRule(
    ['instant coffee', 'instant-coffee'],
    '☕',
    asset: 'assets/ingredients/instant-coffee.png',
  ),
  _VisualRule(
    ['lasagne sheets', 'lasagne-sheets'],
    '🍝',
    asset: 'assets/ingredients/lasagne-sheets.png',
  ),
  _VisualRule(
    ['salad dressing', 'salad-dressing'],
    '🥬',
    asset: 'assets/ingredients/salad-dressing.png',
  ),
  _VisualRule(
    ['seafood sticks', 'seafood-sticks'],
    '🐟',
    asset: 'assets/ingredients/seafood-sticks.png',
  ),
  _VisualRule(
    ['smoked paprika', 'smoked-paprika'],
    '🌶️',
    asset: 'assets/ingredients/smoked-paprika.png',
  ),
  _VisualRule(
    ['sparkling wine', 'sparkling-wine'],
    '🍷',
    asset: 'assets/ingredients/sparkling-wine.png',
  ),
  _VisualRule(
    ['ice cream tub', 'ice-cream-tub'],
    '🥛',
    asset: 'assets/ingredients/ice-cream-tub.png',
  ),
  _VisualRule(
    ['bacon rashers', 'bacon-rashers', 'rashers', 'rasher', 'bacon'],
    '🥓',
    asset: 'assets/ingredients/bacon-rashers.png',
  ),
  _VisualRule(
    ['baking powder', 'baking-powder', 'raising agent'],
    '🫙',
    asset: 'assets/ingredients/baking-powder.png',
  ),
  _VisualRule(
    ['bottled water', 'bottled-water'],
    '🥄',
    asset: 'assets/ingredients/bottled-water.png',
  ),
  _VisualRule(
    ['red pepper flakes', 'chilli flakes', 'chilli-flakes', 'chili flakes'],
    '🌶️',
    asset: 'assets/ingredients/chilli-flakes.png',
  ),
  _VisualRule(
    ['chilli powder', 'chilli-powder', 'chili powder'],
    '🌶️',
    asset: 'assets/ingredients/chilli-powder.png',
  ),
  _VisualRule(
    ['cooked prawns', 'cooked shrimp', 'cooked-prawns', 'cooked prawn'],
    '🦐',
    asset: 'assets/ingredients/cooked-prawns.png',
  ),
  _VisualRule(
    ['dried lentils', 'dried-lentils'],
    '🫘',
    asset: 'assets/ingredients/dried-lentils.png',
  ),
  _VisualRule(
    ['generic dairy', 'generic-dairy'],
    '🥄',
    asset: 'assets/ingredients/generic-dairy.png',
  ),
  _VisualRule(
    ['generic drink', 'generic-drink'],
    '🥄',
    asset: 'assets/ingredients/generic-drink.png',
  ),
  _VisualRule(
    ['generic fruit', 'generic-fruit'],
    '🥄',
    asset: 'assets/ingredients/generic-fruit.png',
  ),
  _VisualRule(
    ['shredded cheese', 'grated cheese', 'grated-cheese'],
    '🧀',
    asset: 'assets/ingredients/grated-cheese.png',
  ),
  _VisualRule(
    ['greek style yoghurt', 'greek yoghurt', 'greek-yoghurt', 'greek yogurt'],
    '🥛',
    asset: 'assets/ingredients/greek-yoghurt.png',
  ),
  _VisualRule(
    ['ground coffee', 'ground-coffee'],
    '☕',
    asset: 'assets/ingredients/ground-coffee.png',
  ),
  _VisualRule(
    ['ground ginger', 'ground-ginger'],
    '🫚',
    asset: 'assets/ingredients/ground-ginger.png',
  ),
  _VisualRule(
    ['passion fruit', 'passion-fruit', 'passionfruit'],
    '🥭',
    asset: 'assets/ingredients/passion-fruit.png',
  ),
  _VisualRule(
    ['peanut butter', 'peanut-butter', 'nut butter'],
    '🫛',
    asset: 'assets/ingredients/peanut-butter.png',
  ),
  _VisualRule(
    ['porridge oats', 'porridge-oats', 'rolled oats', 'oatmeal', 'oats'],
    '🍚',
    asset: 'assets/ingredients/porridge-oats.png',
  ),
  _VisualRule(
    ['pumpkin seeds', 'pumpkin-seeds', 'pepitas'],
    '🥜',
    asset: 'assets/ingredients/pumpkin-seeds.png',
  ),
  _VisualRule(
    ['salmon fillet', 'salmon-fillet'],
    '🐟',
    asset: 'assets/ingredients/salmon-fillet.png',
  ),
  _VisualRule(
    ['smoked salmon', 'smoked-salmon', 'lox'],
    '🐟',
    asset: 'assets/ingredients/smoked-salmon.png',
  ),
  _VisualRule(
    ['collard greens', 'spring greens', 'spring-greens', 'collards'],
    '🥬',
    asset: 'assets/ingredients/spring-greens.png',
  ),
  _VisualRule(
    [
      'spring onions',
      'spring-onions',
      'green onions',
      'salad onions',
      'spring onion',
      'green onion',
      'salad onion',
      'scallions',
      'scallion',
    ],
    '🧅',
    asset: 'assets/ingredients/spring-onions.png',
  ),
  _VisualRule(
    ['sunflower oil', 'sunflower-oil', 'cooking oil'],
    '🫙',
    asset: 'assets/ingredients/sunflower-oil.png',
  ),
  _VisualRule(
    ['sweetcorn cob', 'sweetcorn-cob'],
    '🌽',
    asset: 'assets/ingredients/sweetcorn-cob.png',
  ),
  _VisualRule(
    ['tortilla wrap', 'tortilla-wrap', 'tortilla', 'wrap'],
    '🫓',
    asset: 'assets/ingredients/tortilla-wrap.png',
  ),
  _VisualRule(
    ['uncooked rice', 'uncooked-rice', 'rice'],
    '🍚',
    asset: 'assets/ingredients/uncooked-rice.png',
  ),
  _VisualRule(
    ['vegetable oil', 'vegetable-oil', 'cooking oil', 'neutral oil'],
    '🫙',
    asset: 'assets/ingredients/vegetable-oil.png',
  ),
  _VisualRule(
    ['white vinegar', 'white-vinegar'],
    '🫙',
    asset: 'assets/ingredients/white-vinegar.png',
  ),
  _VisualRule(
    ['whole chicken', 'whole-chicken', 'chicken'],
    '🍗',
    asset: 'assets/ingredients/whole-chicken.png',
  ),
  _VisualRule(
    ['yeast extract', 'yeast-extract', 'vegemite', 'marmite'],
    '🫙',
    asset: 'assets/ingredients/yeast-extract.png',
  ),
  _VisualRule(
    ['blackcurrants'],
    '🥄',
    asset: 'assets/ingredients/blackcurrants.png',
  ),
  _VisualRule(
    ['fish pie mix', 'fish-pie-mix'],
    '🐟',
    asset: 'assets/ingredients/fish-pie-mix.png',
  ),
  _VisualRule(
    ['basmati rice', 'basmati-rice', 'basmati'],
    '🍚',
    asset: 'assets/ingredients/basmati-rice.png',
  ),
  _VisualRule(
    [
      'ground black pepper',
      'cracked pepper',
      'black pepper',
      'black-pepper',
      'peppercorns',
    ],
    '🧂',
    asset: 'assets/ingredients/black-pepper.png',
  ),
  _VisualRule(
    ['breaded fish', 'breaded-fish'],
    '🥖',
    asset: 'assets/ingredients/breaded-fish.png',
  ),
  _VisualRule(
    ['unsweetened cocoa', 'cocoa powder', 'cocoa-powder', 'cocoa'],
    '🍫',
    asset: 'assets/ingredients/cocoa-powder.png',
  ),
  _VisualRule(
    ['coffee beans', 'coffee-beans'],
    '🫘',
    asset: 'assets/ingredients/coffee-beans.png',
  ),
  _VisualRule(
    ['cooked bacon', 'cooked-bacon'],
    '🥓',
    asset: 'assets/ingredients/cooked-bacon.png',
  ),
  _VisualRule(
    ['cream cheese', 'cream-cheese', 'soft cheese'],
    '🧀',
    asset: 'assets/ingredients/cream-cheese.png',
  ),
  _VisualRule(
    ['curry powder', 'curry-powder', 'curry'],
    '🫙',
    asset: 'assets/ingredients/curry-powder.png',
  ),
  _VisualRule(
    ['whipping cream', 'double cream', 'double-cream', 'heavy cream'],
    '🥛',
    asset: 'assets/ingredients/double-cream.png',
  ),
  _VisualRule(
    ['energy drink', 'energy-drink'],
    '🥄',
    asset: 'assets/ingredients/energy-drink.png',
  ),
  _VisualRule(
    ['fish fingers', 'fish-fingers', 'fish sticks'],
    '🐟',
    asset: 'assets/ingredients/fish-fingers.png',
  ),
  _VisualRule(
    ['frozen chips', 'frozen-chips'],
    '🥔',
    asset: 'assets/ingredients/frozen-chips.png',
  ),
  _VisualRule(
    ['frozen pizza', 'frozen-pizza'],
    '🍕',
    asset: 'assets/ingredients/frozen-pizza.png',
  ),
  _VisualRule(
    ['garam masala', 'garam-masala'],
    '🥄',
    asset: 'assets/ingredients/garam-masala.png',
  ),
  _VisualRule(
    ['generic fish', 'generic-fish'],
    '🐟',
    asset: 'assets/ingredients/generic-fish.png',
  ),
  _VisualRule(
    ['generic meat', 'generic-meat'],
    '🥩',
    asset: 'assets/ingredients/generic-meat.png',
  ),
  _VisualRule(
    ['kidney beans', 'kidney-beans', 'red beans'],
    '🫘',
    asset: 'assets/ingredients/kidney-beans.png',
  ),
  _VisualRule(
    [
      'leafy greens',
      'leafy-greens',
      'salad greens',
      'salad leaves',
      'leafy green',
      'arugula',
      'rocket',
    ],
    '🥬',
    asset: 'assets/ingredients/leafy-greens.png',
  ),
  _VisualRule(
    ['plant butter', 'plant-butter'],
    '🧈',
    asset: 'assets/ingredients/plant-butter.png',
  ),
  _VisualRule(
    ['risotto rice', 'risotto-rice'],
    '🍚',
    asset: 'assets/ingredients/risotto-rice.png',
  ),
  _VisualRule(
    ['sesame seeds', 'sesame-seeds', 'sesame'],
    '🥜',
    asset: 'assets/ingredients/sesame-seeds.png',
  ),
  _VisualRule(
    ['single cream', 'single-cream', 'light cream', 'table cream'],
    '🥛',
    asset: 'assets/ingredients/single-cream.png',
  ),
  _VisualRule(
    ['soured cream', 'soured-cream', 'sour cream'],
    '🥛',
    asset: 'assets/ingredients/soured-cream.png',
  ),
  _VisualRule(
    ['sweet potatoes', 'sweet potato', 'sweet-potato', 'yam'],
    '🍠',
    asset: 'assets/ingredients/sweet-potato.png',
  ),
  _VisualRule(
    ['tinned beans', 'tinned-beans'],
    '🫘',
    asset: 'assets/ingredients/tinned-beans.png',
  ),
  _VisualRule(
    ['concentrated tomato', 'tomato paste', 'tomato puree', 'tomato-puree'],
    '🍅',
    asset: 'assets/ingredients/tomato-puree.png',
  ),
  _VisualRule(
    ['ground turkey', 'minced turkey', 'turkey mince', 'turkey-mince'],
    '🍗',
    asset: 'assets/ingredients/turkey-mince.png',
  ),
  _VisualRule(
    ['unknown item', 'unknown-item'],
    '🥄',
    asset: 'assets/ingredients/unknown-item.png',
  ),
  _VisualRule(
    ['plant-based cheese', 'dairy-free cheese', 'vegan cheese', 'vegan-cheese'],
    '🧀',
    asset: 'assets/ingredients/vegan-cheese.png',
  ),
  _VisualRule(
    ['blackberries'],
    '🫐',
    asset: 'assets/ingredients/blackberries.png',
  ),
  _VisualRule(
    ['gooseberries'],
    '🫐',
    asset: 'assets/ingredients/gooseberries.png',
  ),
  _VisualRule(
    ['strawberries'],
    '🍓',
    asset: 'assets/ingredients/strawberries.png',
  ),
  _VisualRule(
    ['cut of meat', 'cut-of-meat'],
    '🥩',
    asset: 'assets/ingredients/cut-of-meat.png',
  ),
  _VisualRule(
    ['almond milk', 'almond-milk', 'alt milk'],
    '🥛',
    asset: 'assets/ingredients/almond-milk.png',
  ),
  _VisualRule(
    ['sweet pepper', 'bell pepper', 'bell-pepper', 'capsicum', 'peppers'],
    '🫑',
    asset: 'assets/ingredients/bell-pepper.png',
  ),
  _VisualRule(
    ['blue cheese', 'blue-cheese', 'gorgonzola', 'roquefort', 'stilton'],
    '🧀',
    asset: 'assets/ingredients/blue-cheese.png',
  ),
  _VisualRule(
    ['strong white flour', 'strong flour', 'bread flour', 'bread-flour'],
    '🥖',
    asset: 'assets/ingredients/bread-flour.png',
  ),
  _VisualRule(
    ['light brown sugar', 'brown sugar', 'brown-sugar', 'demerara'],
    '🫙',
    asset: 'assets/ingredients/brown-sugar.png',
  ),
  _VisualRule(
    ['cereal bowl', 'cereal-bowl'],
    '🥄',
    asset: 'assets/ingredients/cereal-bowl.png',
  ),
  _VisualRule(
    ['cooked rice', 'cooked-rice'],
    '🍚',
    asset: 'assets/ingredients/cooked-rice.png',
  ),
  _VisualRule(
    ['curry paste', 'curry-paste', 'curry'],
    '🫙',
    asset: 'assets/ingredients/curry-paste.png',
  ),
  _VisualRule(
    ['curry sauce', 'curry-sauce'],
    '🫙',
    asset: 'assets/ingredients/curry-sauce.png',
  ),
  _VisualRule(
    ['dried pasta', 'dried-pasta'],
    '🍝',
    asset: 'assets/ingredients/dried-pasta.png',
  ),
  _VisualRule(
    ['active dry yeast', 'instant yeast', 'dried yeast', 'dried-yeast'],
    '🫙',
    asset: 'assets/ingredients/dried-yeast.png',
  ),
  _VisualRule(
    ['lo mein noodles', 'egg noodles', 'egg-noodles'],
    '🥚',
    asset: 'assets/ingredients/egg-noodles.png',
  ),
  _VisualRule(
    ['fresh herbs', 'fresh-herbs', 'herbs', 'herb'],
    '🌿',
    asset: 'assets/ingredients/fresh-herbs.png',
  ),
  _VisualRule(
    ['frozen peas', 'frozen-peas', 'peas'],
    '🫛',
    asset: 'assets/ingredients/frozen-peas.png',
  ),
  _VisualRule(
    ['goat\'s cheese', 'goat cheese', 'goat-cheese', 'chevre', 'chèvre'],
    '🧀',
    asset: 'assets/ingredients/goat-cheese.png',
  ),
  _VisualRule(
    ['granny smith', 'green apple', 'green-apple'],
    '🍏',
    asset: 'assets/ingredients/green-apple.png',
  ),
  _VisualRule(
    ['french beans', 'string beans', 'green beans', 'green-beans'],
    '🫘',
    asset: 'assets/ingredients/green-beans.png',
  ),
  _VisualRule(
    [
      'confectioner\'s sugar',
      'confectioners sugar',
      'powdered sugar',
      'icing sugar',
      'icing-sugar',
    ],
    '🫙',
    asset: 'assets/ingredients/icing-sugar.png',
  ),
  _VisualRule(
    ['dried herbs', 'mixed herbs', 'mixed-herbs'],
    '🌿',
    asset: 'assets/ingredients/mixed-herbs.png',
  ),
  _VisualRule(
    ['pumpkin spice', 'mixed spice', 'mixed-spice'],
    '🫙',
    asset: 'assets/ingredients/mixed-spice.png',
  ),
  _VisualRule(
    ['pitta bread', 'pitta-bread', 'pita bread', 'pitta', 'pita'],
    '🥖',
    asset: 'assets/ingredients/pitta-bread.png',
  ),
  _VisualRule(
    [
      'all purpose flour',
      'all-purpose flour',
      'plain flour',
      'plain-flour',
      'ap flour',
    ],
    '🫙',
    asset: 'assets/ingredients/plain-flour.png',
  ),
  _VisualRule(
    ['puff pastry', 'puff-pastry'],
    '🥄',
    asset: 'assets/ingredients/puff-pastry.png',
  ),
  _VisualRule(
    ['pulled pork', 'pulled-pork'],
    '🥩',
    asset: 'assets/ingredients/pulled-pork.png',
  ),
  _VisualRule(
    ['purple cabbage', 'red cabbage', 'red-cabbage'],
    '🥬',
    asset: 'assets/ingredients/red-cabbage.png',
  ),
  _VisualRule(
    ['sliced loaf', 'sliced-loaf'],
    '🧊',
    asset: 'assets/ingredients/sliced-loaf.png',
  ),
  _VisualRule(
    ['bouillon cubes', 'stock cubes', 'stock-cubes', 'stock cube', 'bouillon'],
    '🍲',
    asset: 'assets/ingredients/stock-cubes.png',
  ),
  _VisualRule(
    ['tinned food', 'tinned-food'],
    '🥄',
    asset: 'assets/ingredients/tinned-food.png',
  ),
  _VisualRule(
    ['tinned soup', 'tinned-soup'],
    '🍲',
    asset: 'assets/ingredients/tinned-soup.png',
  ),
  _VisualRule(
    ['canned tuna', 'tinned tuna', 'tinned-tuna'],
    '🐟',
    asset: 'assets/ingredients/tinned-tuna.png',
  ),
  _VisualRule(
    ['granulated sugar', 'white sugar', 'white-sugar'],
    '🫙',
    asset: 'assets/ingredients/white-sugar.png',
  ),
  _VisualRule(
    ['blueberries'],
    '🫐',
    asset: 'assets/ingredients/blueberries.png',
  ),
  _VisualRule(
    ['breadcrumbs', 'breadcrumb', 'panko'],
    '🥖',
    asset: 'assets/ingredients/breadcrumbs.png',
  ),
  _VisualRule(
    ['cauliflower', 'cauli'],
    '🥦',
    asset: 'assets/ingredients/cauliflower.png',
  ),
  _VisualRule(
    ['cranberries'],
    '🫐',
    asset: 'assets/ingredients/cranberries.png',
  ),
  _VisualRule(
    ['pomegranates', 'pomegranate'],
    '🍇',
    asset: 'assets/ingredients/pomegranate.png',
  ),
  _VisualRule(
    ['raspberries'],
    '🫐',
    asset: 'assets/ingredients/raspberries.png',
  ),
  _VisualRule(
    ['bay leaves', 'bay-leaves', 'bay leaf'],
    '🌿',
    asset: 'assets/ingredients/bay-leaves.png',
  ),
  _VisualRule(
    ['beef joint', 'beef roast', 'beef-joint', 'roast beef'],
    '🥩',
    asset: 'assets/ingredients/beef-joint.png',
  ),
  _VisualRule(
    [
      'ground beef',
      'ground meat',
      'minced beef',
      'beef mince',
      'beef-mince',
      'mince',
    ],
    '🥩',
    asset: 'assets/ingredients/beef-mince.png',
  ),
  _VisualRule(
    ['bread roll', 'bread-roll'],
    '🥖',
    asset: 'assets/ingredients/bread-roll.png',
  ),
  _VisualRule(
    ['chia seeds', 'chia-seeds', 'chia'],
    '🥜',
    asset: 'assets/ingredients/chia-seeds.png',
  ),
  _VisualRule(
    ['fish sauce', 'fish-sauce', 'nam pla'],
    '🐟',
    asset: 'assets/ingredients/fish-sauce.png',
  ),
  _VisualRule(
    ['lamb chops', 'lamb-chops', 'lamb chop'],
    '🥩',
    asset: 'assets/ingredients/lamb-chops.png',
  ),
  _VisualRule(
    ['ground lamb', 'minced lamb', 'lamb mince', 'lamb-mince'],
    '🥩',
    asset: 'assets/ingredients/lamb-mince.png',
  ),
  _VisualRule(
    ['mixed nuts', 'mixed-nuts', 'nuts'],
    '🥜',
    asset: 'assets/ingredients/mixed-nuts.png',
  ),
  _VisualRule(
    ['naan bread', 'naan-bread', 'naan'],
    '🥖',
    asset: 'assets/ingredients/naan-bread.png',
  ),
  _VisualRule(
    ['pork chops', 'pork-chops', 'pork chop'],
    '🥩',
    asset: 'assets/ingredients/pork-chops.png',
  ),
  _VisualRule(
    ['ground pork', 'minced pork', 'pork mince', 'pork-mince'],
    '🥩',
    asset: 'assets/ingredients/pork-mince.png',
  ),
  _VisualRule(
    ['toasted sesame oil', 'sesame oil', 'sesame-oil'],
    '🫙',
    asset: 'assets/ingredients/sesame-oil.png',
  ),
  _VisualRule(
    ['star anise', 'star-anise', 'anise'],
    '🥄',
    asset: 'assets/ingredients/star-anise.png',
  ),
  _VisualRule(
    ['tuna steak', 'tuna-steak', 'tuna'],
    '🐟',
    asset: 'assets/ingredients/tuna-steak.png',
  ),
  _VisualRule(['croissants'], '🥐', asset: 'assets/ingredients/croissants.png'),
  _VisualRule(
    ['pink grapefruit', 'grapefruit'],
    '🍇',
    asset: 'assets/ingredients/grapefruit.png',
  ),
  _VisualRule(
    ['mayonnaise', 'mayo'],
    '🫙',
    asset: 'assets/ingredients/mayonnaise.png',
  ),
  _VisualRule(
    ['fresh mozzarella', 'mozzarella'],
    '🧀',
    asset: 'assets/ingredients/mozzarella.png',
  ),
  _VisualRule(
    ['pistachios', 'pistachio'],
    '🥜',
    asset: 'assets/ingredients/pistachios.png',
  ),
  _VisualRule(
    ['water melon', 'watermelon'],
    '🍈',
    asset: 'assets/ingredients/watermelon.png',
  ),
  _VisualRule(
    ['barbecue sauce', 'barbeque sauce', 'bbq sauce', 'bbq-sauce'],
    '🫙',
    asset: 'assets/ingredients/bbq-sauce.png',
  ),
  _VisualRule(
    ['fried egg', 'fried-egg'],
    '🥚',
    asset: 'assets/ingredients/fried-egg.png',
  ),
  _VisualRule(
    ['honey jar', 'honey-jar'],
    '🍯',
    asset: 'assets/ingredients/honey-jar.png',
  ),
  _VisualRule(
    [
      'chilli sauce',
      'chili sauce',
      'hot sauce',
      'hot-sauce',
      'sriracha',
      'tabasco',
    ],
    '🌶️',
    asset: 'assets/ingredients/hot-sauce.png',
  ),
  _VisualRule(
    ['ice cream', 'ice-cream', 'gelato'],
    '🥛',
    asset: 'assets/ingredients/ice-cream.png',
  ),
  _VisualRule(
    ['juice box', 'juice-box'],
    '🧊',
    asset: 'assets/ingredients/juice-box.png',
  ),
  _VisualRule(
    ['extra virgin olive oil', 'olive oil', 'olive-oil', 'evoo'],
    '🫒',
    asset: 'assets/ingredients/olive-oil.png',
  ),
  _VisualRule(
    ['pine nuts', 'pine-nuts', 'pignoli'],
    '🥜',
    asset: 'assets/ingredients/pine-nuts.png',
  ),
  _VisualRule(
    ['purple onion', 'red onions', 'red onion', 'red-onion'],
    '🧅',
    asset: 'assets/ingredients/red-onion.png',
  ),
  _VisualRule(
    ['rice ball', 'rice-ball'],
    '🍚',
    asset: 'assets/ingredients/rice-ball.png',
  ),
  _VisualRule(
    ['soya sauce', 'soy sauce', 'soy-sauce', 'shoyu'],
    '🫙',
    asset: 'assets/ingredients/soy-sauce.png',
  ),
  _VisualRule(
    ['stock pot', 'stock-pot'],
    '🍲',
    asset: 'assets/ingredients/stock-pot.png',
  ),
  _VisualRule(
    ['anchovies', 'anchovy'],
    '🐟',
    asset: 'assets/ingredients/anchovies.png',
  ),
  _VisualRule(
    ['artichoke hearts', 'artichoke'],
    '🥬',
    asset: 'assets/ingredients/artichoke.png',
  ),
  _VisualRule(
    ['asparagus spears', 'asparagus'],
    '🥬',
    asset: 'assets/ingredients/asparagus.png',
  ),
  _VisualRule(
    ['aubergine', 'eggplants', 'eggplant'],
    '🍆',
    asset: 'assets/ingredients/aubergine.png',
  ),
  _VisualRule(['chestnuts'], '🌰', asset: 'assets/ingredients/chestnuts.png'),
  _VisualRule(['chocolate'], '🍫', asset: 'assets/ingredients/chocolate.png'),
  _VisualRule(
    ['fresh coriander', 'fresh cilantro', 'coriander', 'cilantro'],
    '🌿',
    asset: 'assets/ingredients/coriander.png',
  ),
  _VisualRule(
    ['corn starch', 'cornstarch', 'cornflour'],
    '🌽',
    asset: 'assets/ingredients/cornflour.png',
  ),
  _VisualRule(
    ['courgette', 'zucchinis', 'zucchini'],
    '🥒',
    asset: 'assets/ingredients/courgette.png',
  ),
  _VisualRule(['flatbread'], '🥖', asset: 'assets/ingredients/flatbread.png'),
  _VisualRule(
    ['hazelnuts', 'hazelnut'],
    '🥜',
    asset: 'assets/ingredients/hazelnuts.png',
  ),
  _VisualRule(
    ['meatballs', 'meatball'],
    '🥩',
    asset: 'assets/ingredients/meatballs.png',
  ),
  _VisualRule(['mushrooms'], '🍄', asset: 'assets/ingredients/mushrooms.png'),
  _VisualRule(
    ['nectarine', 'peach'],
    '🍑',
    asset: 'assets/ingredients/nectarine.png',
  ),
  _VisualRule(
    ['pineapples', 'pineapple'],
    '🍍',
    asset: 'assets/ingredients/pineapple.png',
  ),
  _VisualRule(
    ['spaghetti', 'pasta'],
    '🍝',
    asset: 'assets/ingredients/spaghetti.png',
  ),
  _VisualRule(['sprinkles'], '🥄', asset: 'assets/ingredients/sprinkles.png'),
  _VisualRule(['tangerine'], '🍊', asset: 'assets/ingredients/tangerine.png'),
  _VisualRule(
    ['oat milk', 'oat-milk', 'oatmilk'],
    '🥛',
    asset: 'assets/ingredients/oat-milk.png',
  ),
  _VisualRule(
    ['bok choy', 'pac choi', 'pak choi', 'pak-choi', 'bokchoi'],
    '🥬',
    asset: 'assets/ingredients/pak-choi.png',
  ),
  _VisualRule(
    ['pea pods', 'pea-pods'],
    '🫛',
    asset: 'assets/ingredients/pea-pods.png',
  ),
  _VisualRule(
    ['soy milk', 'soy-milk'],
    '🥛',
    asset: 'assets/ingredients/soy-milk.png',
  ),
  _VisualRule(
    ['tea bags', 'tea-bags'],
    '🍵',
    asset: 'assets/ingredients/tea-bags.png',
  ),
  _VisualRule(['baguette'], '🥖', asset: 'assets/ingredients/baguette.png'),
  _VisualRule(
    ['beetroot', 'beets', 'beet'],
    '🥕',
    asset: 'assets/ingredients/beetroot.png',
  ),
  _VisualRule(
    ['biscuits', 'cookies', 'cookie'],
    '🍪',
    asset: 'assets/ingredients/biscuits.png',
  ),
  _VisualRule(
    ['broccolini', 'broccoli'],
    '🥦',
    asset: 'assets/ingredients/broccoli.png',
  ),
  _VisualRule(
    ['cardamom', 'cardamon'],
    '🥄',
    asset: 'assets/ingredients/cardamom.png',
  ),
  _VisualRule(['cherries'], '🍒', asset: 'assets/ingredients/cherries.png'),
  _VisualRule(
    ['ground cinnamon', 'cinnamon stick', 'cinnamon'],
    '🥄',
    asset: 'assets/ingredients/cinnamon.png',
  ),
  _VisualRule(
    ['israeli couscous', 'couscous'],
    '🍚',
    asset: 'assets/ingredients/couscous.png',
  ),
  _VisualRule(['cucumber'], '🥒', asset: 'assets/ingredients/cucumber.png'),
  _VisualRule(
    ['cupcakes', 'cupcake'],
    '🧁',
    asset: 'assets/ingredients/cupcakes.png',
  ),
  _VisualRule(['flaxseed'], '🥜', asset: 'assets/ingredients/flaxseed.png'),
  _VisualRule(
    ['halloumi', 'haloumi'],
    '🧀',
    asset: 'assets/ingredients/halloumi.png',
  ),
  _VisualRule(['marzipan'], '🥄', asset: 'assets/ingredients/marzipan.png'),
  _VisualRule(
    ['pancakes', 'pancake'],
    '🧁',
    asset: 'assets/ingredients/pancakes.png',
  ),
  _VisualRule(
    ['parmigiano-reggiano', 'parmigiano', 'parmesan', 'parm'],
    '🧀',
    asset: 'assets/ingredients/parmesan.png',
  ),
  _VisualRule(
    ['fresh rosemary', 'rosemary'],
    '🌿',
    asset: 'assets/ingredients/rosemary.png',
  ),
  _VisualRule(['sandwich'], '🥪', asset: 'assets/ingredients/sandwich.png'),
  _VisualRule(
    ['sausages', 'bangers', 'sausage'],
    '🌿',
    asset: 'assets/ingredients/sausages.png',
  ),
  _VisualRule(
    ['scallops', 'scallop'],
    '🦐',
    asset: 'assets/ingredients/scallops.png',
  ),
  _VisualRule(['takeaway'], '🥄', asset: 'assets/ingredients/takeaway.png'),
  _VisualRule(
    ['ground turmeric', 'turmeric', 'haldi'],
    '🥄',
    asset: 'assets/ingredients/turmeric.png',
  ),
  _VisualRule(
    ['almonds', 'almond'],
    '🥜',
    asset: 'assets/ingredients/almonds.png',
  ),
  _VisualRule(
    ['apricots', 'apricot'],
    '🍑',
    asset: 'assets/ingredients/apricot.png',
  ),
  _VisualRule(
    ['avocados', 'avocado'],
    '🥑',
    asset: 'assets/ingredients/avocado.png',
  ),
  _VisualRule(['brioche'], '🥄', asset: 'assets/ingredients/brioche.png'),
  _VisualRule(
    ['green cabbage', 'cabbage'],
    '🥬',
    asset: 'assets/ingredients/cabbage.png',
  ),
  _VisualRule(['cashews'], '🥜', asset: 'assets/ingredients/cashews.png'),
  _VisualRule(
    ['cheddar cheese', 'sharp cheddar', 'cheddar'],
    '🧀',
    asset: 'assets/ingredients/cheddar.png',
  ),
  _VisualRule(
    ['mango chutney', 'chutney'],
    '🫙',
    asset: 'assets/ingredients/chutney.png',
  ),
  _VisualRule(['coconut'], '🥥', asset: 'assets/ingredients/coconut.png'),
  _VisualRule(['cordial'], '🥄', asset: 'assets/ingredients/cordial.png'),
  _VisualRule(['crumpet'], '🍷', asset: 'assets/ingredients/crumpet.png'),
  _VisualRule(
    ['creme anglaise', 'custard', 'pudding'],
    '🥄',
    asset: 'assets/ingredients/custard.png',
  ),
  _VisualRule(
    ['granola', 'muesli'],
    '🍚',
    asset: 'assets/ingredients/granola.png',
  ),
  _VisualRule(['ketchup'], '🍅', asset: 'assets/ingredients/ketchup.png'),
  _VisualRule(['lettuce'], '🥬', asset: 'assets/ingredients/lettuce.png'),
  _VisualRule(
    ['mussels', 'mussel'],
    '🦐',
    asset: 'assets/ingredients/mussels.png',
  ),
  _VisualRule(
    ['english mustard', 'yellow mustard', 'mustard'],
    '🫙',
    asset: 'assets/ingredients/mustard.png',
  ),
  _VisualRule(
    ['fresh oregano', 'oregano'],
    '🌿',
    asset: 'assets/ingredients/oregano.png',
  ),
  _VisualRule(
    ['smoked paprika', 'sweet paprika', 'paprika'],
    '🌶️',
    asset: 'assets/ingredients/paprika.png',
  ),
  _VisualRule(
    ['fresh parsley', 'parsley'],
    '🌿',
    asset: 'assets/ingredients/parsley.png',
  ),
  _VisualRule(
    ['parsnips', 'parsnip'],
    '🥕',
    asset: 'assets/ingredients/parsnip.png',
  ),
  _VisualRule(
    ['strained tomatoes', 'sieved tomatoes', 'tomato passata', 'passata'],
    '🍅',
    asset: 'assets/ingredients/passata.png',
  ),
  _VisualRule(
    ['peanuts', 'peanut'],
    '🫛',
    asset: 'assets/ingredients/peanuts.png',
  ),
  _VisualRule(
    ['winter squash', 'pumpkin', 'squash'],
    '🥄',
    asset: 'assets/ingredients/pumpkin.png',
  ),
  _VisualRule(
    ['sultanas', 'raisins'],
    '🍇',
    asset: 'assets/ingredients/raisins.png',
  ),
  _VisualRule(['rhubarb'], '🥄', asset: 'assets/ingredients/rhubarb.png'),
  _VisualRule(
    ['saffron threads', 'saffron'],
    '🥄',
    asset: 'assets/ingredients/saffron.png',
  ),
  _VisualRule(
    ['shallots', 'shallot'],
    '🧅',
    asset: 'assets/ingredients/shallot.png',
  ),
  _VisualRule(
    ['baby spinach', 'spinach'],
    '🥬',
    asset: 'assets/ingredients/spinach.png',
  ),
  _VisualRule(['spirits'], '🥄', asset: 'assets/ingredients/spirits.png'),
  _VisualRule(
    ['walnuts', 'walnut'],
    '🥜',
    asset: 'assets/ingredients/walnuts.png',
  ),
  _VisualRule(
    ['plain yoghurt', 'plain yogurt', 'yoghurt', 'yogurt'],
    '🥛',
    asset: 'assets/ingredients/yoghurt.png',
  ),
  _VisualRule(
    ['bagels', 'bagel'],
    '🥯',
    asset: 'assets/ingredients/bagels.png',
  ),
  _VisualRule(
    ['bananas', 'banana'],
    '🍌',
    asset: 'assets/ingredients/banana.png',
  ),
  _VisualRule(['burger'], '🍔', asset: 'assets/ingredients/burger.png'),
  _VisualRule(
    ['margarine', 'butter', 'ghee'],
    '🧈',
    asset: 'assets/ingredients/butter.png',
  ),
  _VisualRule(
    ['carrots', 'carrot'],
    '🥕',
    asset: 'assets/ingredients/carrot.png',
  ),
  _VisualRule(
    ['celery sticks', 'celery'],
    '🥕',
    asset: 'assets/ingredients/celery.png',
  ),
  _VisualRule(
    ['breakfast cereal', 'cereal'],
    '🥄',
    asset: 'assets/ingredients/cereal.png',
  ),
  _VisualRule(['cheese'], '🧀', asset: 'assets/ingredients/cheese.png'),
  _VisualRule(['chilli'], '🌶️', asset: 'assets/ingredients/chilli.png'),
  _VisualRule(
    ['espresso', 'coffee'],
    '☕',
    asset: 'assets/ingredients/coffee.png',
  ),
  _VisualRule(
    ['fennel bulb', 'fennel'],
    '🥬',
    asset: 'assets/ingredients/fennel.png',
  ),
  _VisualRule(
    ['garlic cloves', 'fresh garlic', 'garlic'],
    '🧄',
    asset: 'assets/ingredients/garlic.png',
  ),
  _VisualRule(
    ['fresh ginger', 'root ginger', 'ginger'],
    '🫚',
    asset: 'assets/ingredients/ginger.png',
  ),
  _VisualRule(['grapes'], '🍇', asset: 'assets/ingredients/grapes.png'),
  _VisualRule(['muffin'], '🧁', asset: 'assets/ingredients/muffin.png'),
  _VisualRule(
    ['ground nutmeg', 'nutmeg'],
    '🥜',
    asset: 'assets/ingredients/nutmeg.png',
  ),
  _VisualRule(
    ['black olives', 'green olives', 'olives', 'olive'],
    '🫒',
    asset: 'assets/ingredients/olives.png',
  ),
  _VisualRule(
    ['oranges', 'orange'],
    '🍊',
    asset: 'assets/ingredients/orange.png',
  ),
  _VisualRule(['paella'], '🥘', asset: 'assets/ingredients/paella.png'),
  _VisualRule(
    ['papaya', 'pawpaw'],
    '🥭',
    asset: 'assets/ingredients/papaya.png',
  ),
  _VisualRule(['pecans'], '🥜', asset: 'assets/ingredients/pecans.png'),
  _VisualRule(
    ['potatoes', 'potato'],
    '🥔',
    asset: 'assets/ingredients/potato.png',
  ),
  _VisualRule(
    ['shrimps', 'prawns', 'shrimp', 'prawn'],
    '🦐',
    asset: 'assets/ingredients/prawns.png',
  ),
  _VisualRule(
    ['quinoa', 'quinua'],
    '🍚',
    asset: 'assets/ingredients/quinoa.png',
  ),
  _VisualRule(
    ['radishes', 'radish'],
    '🥕',
    asset: 'assets/ingredients/radish.png',
  ),
  _VisualRule(
    ['pepperoni', 'salami'],
    '🥩',
    asset: 'assets/ingredients/salami.png',
  ),
  _VisualRule(
    ['tomatoes', 'tomato'],
    '🍅',
    asset: 'assets/ingredients/tomato.png',
  ),
  _VisualRule(['apples', 'apple'], '🍎', asset: 'assets/ingredients/apple.png'),
  _VisualRule(
    ['fresh basil', 'basil'],
    '🌿',
    asset: 'assets/ingredients/basil.png',
  ),
  _VisualRule(['bread'], '🥖', asset: 'assets/ingredients/bread.png'),
  _VisualRule(
    ['ground cumin', 'cumin seeds', 'cumin'],
    '🥄',
    asset: 'assets/ingredients/cumin.png',
  ),
  _VisualRule(
    ['medjool dates', 'dates'],
    '🍇',
    asset: 'assets/ingredients/dates.png',
  ),
  _VisualRule(
    ['clear honey', 'runny honey', 'honey'],
    '🍯',
    asset: 'assets/ingredients/honey.png',
  ),
  _VisualRule(['lemons', 'lemon'], '🍋', asset: 'assets/ingredients/lemon.png'),
  _VisualRule(['liver'], '🥄', asset: 'assets/ingredients/liver.png'),
  _VisualRule(
    ['mangoes', 'mangos', 'mango'],
    '🥭',
    asset: 'assets/ingredients/mango.png',
  ),
  _VisualRule(['melon'], '🍈', asset: 'assets/ingredients/melon.png'),
  _VisualRule(['onions', 'onion'], '🧅', asset: 'assets/ingredients/onion.png'),
  _VisualRule(
    ['nectarine', 'peaches', 'peach'],
    '🫛',
    asset: 'assets/ingredients/peach.png',
  ),
  _VisualRule(
    ['basil pesto', 'green pesto', 'pesto'],
    '🫙',
    asset: 'assets/ingredients/pesto.png',
  ),
  _VisualRule(['pizza'], '🍕', asset: 'assets/ingredients/pizza.png'),
  _VisualRule(
    ['instant noodles', 'ramen'],
    '🍝',
    asset: 'assets/ingredients/ramen.png',
  ),
  _VisualRule(['salad'], '🥬', asset: 'assets/ingredients/salad.png'),
  _VisualRule(['scone'], '🥄', asset: 'assets/ingredients/scone.png'),
  _VisualRule(
    ['calamari', 'squid'],
    '🦐',
    asset: 'assets/ingredients/squid.png',
  ),
  _VisualRule(
    ['beef steak', 'sirloin', 'ribeye', 'steak'],
    '🥩',
    asset: 'assets/ingredients/steak.png',
  ),
  _VisualRule(
    ['rutabaga', 'neeps', 'swede'],
    '🥕',
    asset: 'assets/ingredients/swede.png',
  ),
  _VisualRule(
    ['fresh thyme', 'thyme'],
    '🌿',
    asset: 'assets/ingredients/thyme.png',
  ),
  _VisualRule(
    ['lager', 'beer', 'ale'],
    '🍷',
    asset: 'assets/ingredients/beer.png',
  ),
  _VisualRule(
    ['crab meat', 'crabmeat', 'crab'],
    '🦐',
    asset: 'assets/ingredients/crab.png',
  ),
  _VisualRule(
    ['duck breast', 'duck'],
    '🍗',
    asset: 'assets/ingredients/duck.png',
  ),
  _VisualRule(['eggs', 'egg'], '🥚', asset: 'assets/ingredients/eggs.png'),
  _VisualRule(
    ['feta cheese', 'feta'],
    '🧀',
    asset: 'assets/ingredients/feta.png',
  ),
  _VisualRule(['fish'], '🐟', asset: 'assets/ingredients/fish.png'),
  _VisualRule(
    ['cavolo nero', 'curly kale', 'kale'],
    '🥬',
    asset: 'assets/ingredients/kale.png',
  ),
  _VisualRule(
    ['kiwi fruit', 'kiwifruit', 'kiwi'],
    '🥝',
    asset: 'assets/ingredients/kiwi.png',
  ),
  _VisualRule(['leeks', 'leek'], '🧅', asset: 'assets/ingredients/leek.png'),
  _VisualRule(['limes', 'lime'], '🍋', asset: 'assets/ingredients/lime.png'),
  _VisualRule(['milk'], '🥛', asset: 'assets/ingredients/milk.png'),
  _VisualRule(
    ['fresh mint', 'spearmint', 'mint'],
    '🌿',
    asset: 'assets/ingredients/mint.png',
  ),
  _VisualRule(['pears', 'pear'], '🫛', asset: 'assets/ingredients/pear.png'),
  _VisualRule(['plums', 'plum'], '🍑', asset: 'assets/ingredients/plum.png'),
  _VisualRule(['ribs'], '🥄', asset: 'assets/ingredients/ribs.png'),
  _VisualRule(
    ['fresh sage', 'sage'],
    '🌿',
    asset: 'assets/ingredients/sage.png',
  ),
  _VisualRule(
    ['kosher salt', 'table salt', 'sea salt', 'salt'],
    '🧂',
    asset: 'assets/ingredients/salt.png',
  ),
  _VisualRule(['taco'], '🌮', asset: 'assets/ingredients/taco.png'),
  _VisualRule(
    ['white wine', 'red wine', 'wine'],
    '🍷',
    asset: 'assets/ingredients/wine.png',
  ),
  _VisualRule(['codfish', 'cod'], '🐟', asset: 'assets/ingredients/cod.png'),
  _VisualRule(['figs', 'fig'], '🍇', asset: 'assets/ingredients/fig.png'),
  _VisualRule(['honey ham', 'ham'], '🥓', asset: 'assets/ingredients/ham.png'),
  _VisualRule(['ice cubes', 'ice'], '🧊', asset: 'assets/ingredients/ice.png'),
  _VisualRule(
    ['preserves', 'jelly', 'jam'],
    '🫙',
    asset: 'assets/ingredients/jam.png',
  ),
  _VisualRule(['jar'], '🥄', asset: 'assets/ingredients/jar.png'),
  _VisualRule(['pie'], '🥄', asset: 'assets/ingredients/pie.png'),
  _VisualRule(['black tea', 'tea'], '🍵', asset: 'assets/ingredients/tea.png'),
];
