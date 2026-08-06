import '../models/generated_recipe.dart';
import '../models/user_recipe_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Client-side recipe filtering aligned with onboarding preference labels.
// ─────────────────────────────────────────────────────────────────────────────

class RecipePreferenceFilter {
  RecipePreferenceFilter._();

  static final _cuisineKeywords = <String, List<String>>{
    'italian': ['italian', 'pasta', 'pizza', 'risotto', 'carbonara', 'lasagna', 'pesto', 'gnocchi'],
    'french': ['french', 'croissant', 'ratatouille', 'bouillabaisse', 'quiche'],
    'spanish': ['spanish', 'paella', 'tapas', 'chorizo'],
    'greek': ['greek', 'gyro', 'tzatziki', 'feta', 'souvlaki'],
    'turkish': ['turkish', 'kebab', 'lahmacun', 'baklava'],
    'lebanese': ['lebanese', 'hummus', 'falafel', 'shawarma', 'tabbouleh'],
    'middle eastern': ['middle eastern', 'hummus', 'falafel', 'shawarma', 'tahini'],
    'moroccan': ['moroccan', 'tagine', 'couscous', 'harissa'],
    'persian': ['persian', 'tahdig', 'saffron', 'koobideh'],
    'indian': ['indian', 'curry', 'tikka', 'masala', 'biryani', 'paneer', 'dal', 'naan'],
    'pakistani': ['pakistani', 'biryani', 'karahi', 'nihari', 'achar'],
    'bangladeshi': ['bangladeshi', 'biryani', 'bhuna'],
    'thai': ['thai', 'pad thai', 'tom yum', 'green curry', 'basil'],
    'vietnamese': ['vietnamese', 'pho', 'banh mi', 'spring roll'],
    'chinese': ['chinese', 'stir fry', 'dim sum', 'wonton', 'fried rice'],
    'japanese': ['japanese', 'ramen', 'sushi', 'miso', 'teriyaki', 'udon'],
    'korean': ['korean', 'kimchi', 'bibimbap', 'bulgogi', 'gochujang'],
    'indonesian': ['indonesian', 'nasi goreng', 'satay', 'rendang'],
    'malaysian': ['malaysian', 'laksa', 'nasi lemak'],
    'filipino': ['filipino', 'adobo', 'lumpia'],
    'singaporean': ['singapore', 'chilli crab', 'laksa'],
    'mexican': ['mexican', 'taco', 'burrito', 'enchilada', 'quesadilla', 'salsa'],
    'tex-mex': ['tex-mex', 'tex mex', 'fajita', 'nachos'],
    'caribbean': ['caribbean', 'jerk', 'plantain', 'ackee'],
    'brazilian': ['brazilian', 'feijoada', 'pao de queijo'],
    'peruvian': ['peruvian', 'ceviche', 'aji'],
    'argentinian': ['argentinian', 'asado', 'empanada', 'chimichurri'],
    'american': ['american', 'burger', 'bbq', 'mac and cheese', 'wings'],
    'southern us': ['southern', 'gumbo', 'biscuit', 'grits'],
    'cajun / creole': ['cajun', 'creole', 'jambalaya'],
    'british': ['british', 'fish and chips', 'shepherd', 'bangers'],
    'irish': ['irish', 'colcannon', 'soda bread'],
    'german': ['german', 'schnitzel', 'bratwurst', 'sauerkraut'],
    'scandinavian': ['scandinavian', 'smorrebrod', 'gravlax'],
    'polish': ['polish', 'pierogi', 'kielbasa'],
    'russian': ['russian', 'borscht', 'pelmeni'],
    'hungarian': ['hungarian', 'goulash', 'paprika'],
    'ethiopian': ['ethiopian', 'injera', 'berbere'],
    'west african': ['west african', 'jollof', 'egusi'],
    'south african': ['south african', 'bobotie', 'biltong'],
    'australian': ['australian', 'lamington', 'pavlova'],
    'fusion': ['fusion'],
    'international': ['international'],
  };

  static final _dietaryExclusions = <String, List<String>>{
    'vegan': [
      'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak',
      'fish', 'salmon', 'tuna', 'prawn', 'shrimp', 'crab', 'milk', 'cheese',
      'butter', 'cream', 'yogurt', 'egg', 'honey',
    ],
    'vegetarian': [
      'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak',
      'fish', 'salmon', 'tuna', 'prawn', 'shrimp', 'crab',
    ],
    'pescatarian': [
      'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak',
    ],
    'halal': ['pork', 'bacon', 'ham', 'wine', 'beer', 'alcohol', 'lard'],
    'kosher': ['pork', 'bacon', 'ham', 'shellfish', 'prawn', 'shrimp', 'crab'],
    'gluten-free': ['wheat', 'flour', 'bread', 'pasta', 'noodle', 'barley', 'rye'],
    'wheat-free': ['wheat', 'flour', 'bread', 'pasta', 'semolina'],
    'dairy-free': ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'whey'],
    'lactose-free': ['milk', 'cheese', 'butter', 'cream', 'yogurt'],
    'egg-free': ['egg', 'mayonnaise', 'meringue'],
    'nut-free': ['almond', 'walnut', 'cashew', 'pecan', 'hazelnut', 'pistachio'],
    'peanut-free': ['peanut', 'groundnut'],
    'tree nut-free': ['almond', 'walnut', 'cashew', 'pecan', 'hazelnut', 'pistachio'],
    'soy-free': ['soy', 'tofu', 'tempeh', 'edamame', 'miso'],
    'sesame-free': ['sesame', 'tahini'],
    'shellfish-free': ['prawn', 'shrimp', 'crab', 'lobster', 'mussel', 'clam', 'oyster'],
    'fish-free': ['fish', 'salmon', 'tuna', 'cod', 'anchovy'],
    'no alcohol': ['wine', 'beer', 'vodka', 'rum', 'whisky', 'sake', 'alcohol'],
    'no red meat': ['beef', 'lamb', 'pork', 'bacon', 'steak', 'veal'],
    'no pork': ['pork', 'bacon', 'ham', 'prosciutto', 'chorizo', 'lard'],
    'low fodmap': ['garlic', 'onion', 'wheat', 'apple', 'honey'],
    'low-carb': [],
    'high-protein': [],
    'high-fibre': [],
    'low-sodium': [],
    'keto': ['rice', 'pasta', 'bread', 'potato', 'sugar'],
    'paleo': ['rice', 'pasta', 'bread', 'beans', 'lentil', 'dairy', 'cheese'],
  };

  static String _recipeText(GeneratedRecipe recipe) {
    final parts = <String>[
      recipe.title,
      ...recipe.ingredientsUsed.map((i) => i.name),
      ...recipe.missingIngredients.map((i) => i.name),
      ...recipe.steps.map((s) => s.instruction),
    ];
    return parts.join(' ').toLowerCase();
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n)) return true;
    }
    return false;
  }

  static int _maxDifficultyRank(String skill) {
    switch (skill.toLowerCase()) {
      case 'beginner':
        return 1; // easy only
      case 'intermediate':
      case 'home cook':
        return 2; // easy + medium
      case 'advanced':
      case 'confident':
        return 3;
      default:
        return 3;
    }
  }

  static int _difficultyRank(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 1;
      case 'hard':
        return 3;
      default:
        return 2;
    }
  }

  /// Returns false when the recipe clearly violates saved preferences.
  static bool matches(GeneratedRecipe recipe, UserRecipePreferences prefs) {
    if (prefs.maxCookTimeMinutes > 0 &&
        recipe.cookTimeMinutes > prefs.maxCookTimeMinutes) {
      return false;
    }

    final maxRank = _maxDifficultyRank(prefs.cookingSkill);
    if (_difficultyRank(recipe.difficulty) > maxRank) return false;

    final text = _recipeText(recipe);
    for (final label in prefs.dietary) {
      final key = label.toLowerCase();
      final banned = _dietaryExclusions[key];
      if (banned != null && banned.isNotEmpty && _containsAny(text, banned)) {
        return false;
      }
    }
    return true;
  }

  /// True when the recipe has no meat, poultry, or seafood (vegetarian-friendly).
  static bool isVegetarian(GeneratedRecipe recipe) {
    const exclusions = [
      'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak', 'veal',
      'duck', 'turkey', 'venison', 'rabbit', 'prosciutto', 'chorizo', 'pepperoni',
      'fish', 'salmon', 'tuna', 'cod', 'anchovy', 'trout', 'haddock',
      'prawn', 'shrimp', 'crab', 'lobster', 'mussel', 'clam', 'oyster', 'shellfish',
      'scallop', 'squid', 'calamari', 'octopus', 'crayfish', 'crawfish',
    ];
    return !_containsAny(_recipeText(recipe), exclusions);
  }

  /// True when the recipe text matches a cuisine label (e.g. Greek, Italian).
  static bool matchesCuisine(GeneratedRecipe recipe, String cuisine) {
    final key = cuisine.toLowerCase().trim();
    if (key.isEmpty) return false;
    final keywords = _cuisineKeywords[key] ?? [key];
    return _containsAny(_recipeText(recipe), keywords);
  }

  /// Higher = better fit for the user's cuisines and constraints.
  static int score(GeneratedRecipe recipe, UserRecipePreferences prefs) {
    if (!matches(recipe, prefs)) return -1;

    var points = 0;

    for (final cuisine in prefs.cuisines) {
      if (matchesCuisine(recipe, cuisine)) points += 10;
    }

    if (prefs.maxCookTimeMinutes > 0) {
      final slack = prefs.maxCookTimeMinutes - recipe.cookTimeMinutes;
      if (slack >= 0) points += 2;
      if (slack >= 15) points += 1;
    }

    points += recipe.matchPercent ~/ 10;
    return points;
  }

  static List<GeneratedRecipe> apply(
    List<GeneratedRecipe> recipes,
    UserRecipePreferences prefs, {
    bool strictCuisine = false,
  }) {
    if (!prefs.hasAny) return List<GeneratedRecipe>.from(recipes);

    var filtered = recipes.where((r) => matches(r, prefs)).toList();

    if (strictCuisine && prefs.cuisines.isNotEmpty) {
      final cuisineMatched = filtered
          .where((r) => prefs.cuisines.any((c) => matchesCuisine(r, c)))
          .toList();
      if (cuisineMatched.isNotEmpty) filtered = cuisineMatched;
    }

    filtered.sort((a, b) {
      final sa = score(a, prefs);
      final sb = score(b, prefs);
      if (sa != sb) return sb.compareTo(sa);
      return GeneratedRecipe.compareByIngredientMatch(a, b);
    });
    return filtered;
  }

  static GeneratedRecipe? pickFeatured(
    List<GeneratedRecipe> recipes,
    UserRecipePreferences prefs,
  ) {
    final pool = apply(recipes, prefs);
    if (pool.isEmpty) return null;
    final dayIndex = DateTime.now().day % pool.length;
    return pool[dayIndex];
  }
}
