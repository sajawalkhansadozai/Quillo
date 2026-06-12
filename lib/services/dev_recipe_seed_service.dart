import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DevRecipeSeedResult {
  final int insertedCount;
  final int skippedCount;

  const DevRecipeSeedResult({
    required this.insertedCount,
    required this.skippedCount,
  });
}

class DevRecipeSeedService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<DevRecipeSeedResult> seedPublicRecipes() async {
    if (!kDebugMode) {
      throw StateError('Recipe seeding is only available in debug mode.');
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to seed recipes.');
    }

    final recipes = _seedRecipes
        .map(
          (recipe) => <String, dynamic>{
            ...recipe,
            'user_id': user.id,
            'is_public': true,
          },
        )
        .toList(growable: false);

    final titles = recipes.map((r) => r['title'] as String).toList(growable: false);

    final existingRows = await _client
        .from('recipes')
        .select('title')
        .inFilter('title', titles);

    final existingTitles = (existingRows as List<dynamic>)
        .map((row) => row['title'] as String?)
        .whereType<String>()
        .toSet();

    final rowsToInsert = recipes
        .where((recipe) => !existingTitles.contains(recipe['title']))
        .toList(growable: false);

    if (rowsToInsert.isNotEmpty) {
      await _client.from('recipes').insert(rowsToInsert);
    }

    return DevRecipeSeedResult(
      insertedCount: rowsToInsert.length,
      skippedCount: recipes.length - rowsToInsert.length,
    );
  }

  static const List<Map<String, dynamic>> _seedRecipes = [
    {
      'title': 'Creamy Tomato Pasta',
      'difficulty': 'easy',
      'cook_time_minutes': 20,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Boil pasta until al dente.'},
        {'order': 2, 'instruction': 'Saute garlic in olive oil for 1 minute.'},
        {'order': 3, 'instruction': 'Add tomato sauce and simmer for 5 minutes.'},
        {'order': 4, 'instruction': 'Stir in cream, then toss with pasta.'},
      ],
      'ingredients_used': [
        {'name': 'Pasta', 'amount': '200 g'},
        {'name': 'Tomato sauce', 'amount': '1 cup'},
        {'name': 'Garlic', 'amount': '2 cloves'},
        {'name': 'Cream', 'amount': '1/4 cup'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 520, 'protein': 14, 'carbs': 72, 'fat': 18},
      'image_url': 'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5',
    },
    {
      'title': 'Quick Chicken Stir Fry',
      'difficulty': 'easy',
      'cook_time_minutes': 18,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Slice chicken and vegetables.'},
        {'order': 2, 'instruction': 'Cook chicken in hot pan until golden.'},
        {'order': 3, 'instruction': 'Add vegetables and stir fry for 4 minutes.'},
        {'order': 4, 'instruction': 'Add soy sauce and serve with rice.'},
      ],
      'ingredients_used': [
        {'name': 'Chicken breast', 'amount': '250 g'},
        {'name': 'Bell pepper', 'amount': '1'},
        {'name': 'Broccoli', 'amount': '1 cup'},
        {'name': 'Soy sauce', 'amount': '2 tbsp'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 430, 'protein': 35, 'carbs': 22, 'fat': 18},
      'image_url': 'https://images.unsplash.com/photo-1512058564366-18510be2db19',
    },
    {
      'title': 'Mediterranean Chickpea Salad',
      'difficulty': 'easy',
      'cook_time_minutes': 15,
      'servings': 3,
      'steps': [
        {'order': 1, 'instruction': 'Rinse chickpeas and chop vegetables.'},
        {'order': 2, 'instruction': 'Mix olive oil, lemon juice, salt, and pepper.'},
        {'order': 3, 'instruction': 'Toss everything together and chill briefly.'},
      ],
      'ingredients_used': [
        {'name': 'Chickpeas', 'amount': '1 can'},
        {'name': 'Cucumber', 'amount': '1'},
        {'name': 'Cherry tomatoes', 'amount': '1 cup'},
        {'name': 'Lemon', 'amount': '1'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 320, 'protein': 11, 'carbs': 38, 'fat': 13},
      'image_url': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd',
    },
    {
      'title': 'Classic Mushroom Risotto',
      'difficulty': 'medium',
      'cook_time_minutes': 40,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Cook onion in butter until soft.'},
        {'order': 2, 'instruction': 'Toast arborio rice for 2 minutes.'},
        {'order': 3, 'instruction': 'Add stock gradually while stirring.'},
        {'order': 4, 'instruction': 'Fold in mushrooms and parmesan.'},
      ],
      'ingredients_used': [
        {'name': 'Arborio rice', 'amount': '1 cup'},
        {'name': 'Mushrooms', 'amount': '200 g'},
        {'name': 'Vegetable stock', 'amount': '4 cups'},
        {'name': 'Parmesan', 'amount': '1/3 cup'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 540, 'protein': 15, 'carbs': 67, 'fat': 20},
      'image_url': 'https://images.unsplash.com/photo-1476124369491-e7addf5db371',
    },
    {
      'title': 'Homestyle Beef Tacos',
      'difficulty': 'easy',
      'cook_time_minutes': 25,
      'servings': 4,
      'steps': [
        {'order': 1, 'instruction': 'Cook minced beef with taco spices.'},
        {'order': 2, 'instruction': 'Warm taco shells in oven.'},
        {'order': 3, 'instruction': 'Fill shells with beef and toppings.'},
      ],
      'ingredients_used': [
        {'name': 'Minced beef', 'amount': '400 g'},
        {'name': 'Taco shells', 'amount': '8'},
        {'name': 'Lettuce', 'amount': '1 cup'},
        {'name': 'Cheddar', 'amount': '1/2 cup'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 610, 'protein': 28, 'carbs': 45, 'fat': 33},
      'image_url': 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47',
    },
    {
      'title': 'Herbed Grilled Salmon',
      'difficulty': 'medium',
      'cook_time_minutes': 22,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Season salmon with herbs and lemon.'},
        {'order': 2, 'instruction': 'Grill skin-side down for 5 to 6 minutes.'},
        {'order': 3, 'instruction': 'Flip briefly and serve with greens.'},
      ],
      'ingredients_used': [
        {'name': 'Salmon fillet', 'amount': '2 pieces'},
        {'name': 'Lemon', 'amount': '1'},
        {'name': 'Olive oil', 'amount': '1 tbsp'},
        {'name': 'Mixed herbs', 'amount': '1 tsp'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 460, 'protein': 38, 'carbs': 4, 'fat': 31},
      'image_url': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288',
    },
    {
      'title': 'Spinach and Feta Omelette',
      'difficulty': 'easy',
      'cook_time_minutes': 12,
      'servings': 1,
      'steps': [
        {'order': 1, 'instruction': 'Whisk eggs with salt and pepper.'},
        {'order': 2, 'instruction': 'Saute spinach for 1 minute.'},
        {'order': 3, 'instruction': 'Add eggs, then feta, and fold omelette.'},
      ],
      'ingredients_used': [
        {'name': 'Eggs', 'amount': '3'},
        {'name': 'Spinach', 'amount': '1 cup'},
        {'name': 'Feta', 'amount': '40 g'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 360, 'protein': 24, 'carbs': 4, 'fat': 27},
      'image_url': 'https://images.unsplash.com/photo-1510693206972-df098062cb71',
    },
    {
      'title': 'Thai Coconut Curry',
      'difficulty': 'medium',
      'cook_time_minutes': 30,
      'servings': 3,
      'steps': [
        {'order': 1, 'instruction': 'Cook curry paste in oil for 1 minute.'},
        {'order': 2, 'instruction': 'Add coconut milk and simmer.'},
        {'order': 3, 'instruction': 'Add vegetables and protein and cook through.'},
        {'order': 4, 'instruction': 'Finish with lime juice and basil.'},
      ],
      'ingredients_used': [
        {'name': 'Coconut milk', 'amount': '400 ml'},
        {'name': 'Curry paste', 'amount': '2 tbsp'},
        {'name': 'Chicken', 'amount': '300 g'},
        {'name': 'Mixed vegetables', 'amount': '2 cups'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 540, 'protein': 30, 'carbs': 19, 'fat': 37},
      'image_url': 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd',
    },
    {
      'title': 'Rainbow Veggie Wrap',
      'difficulty': 'easy',
      'cook_time_minutes': 10,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Warm wraps lightly.'},
        {'order': 2, 'instruction': 'Spread hummus and add chopped vegetables.'},
        {'order': 3, 'instruction': 'Roll tightly and slice in half.'},
      ],
      'ingredients_used': [
        {'name': 'Whole wheat wraps', 'amount': '2'},
        {'name': 'Hummus', 'amount': '4 tbsp'},
        {'name': 'Carrot', 'amount': '1'},
        {'name': 'Bell pepper', 'amount': '1/2'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 340, 'protein': 11, 'carbs': 46, 'fat': 13},
      'image_url': 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f',
    },
    {
      'title': 'One Pot Lentil Soup',
      'difficulty': 'easy',
      'cook_time_minutes': 35,
      'servings': 4,
      'steps': [
        {'order': 1, 'instruction': 'Cook onion, carrot, and celery until soft.'},
        {'order': 2, 'instruction': 'Add lentils, tomatoes, and stock.'},
        {'order': 3, 'instruction': 'Simmer for 25 minutes and season.'},
      ],
      'ingredients_used': [
        {'name': 'Red lentils', 'amount': '1 cup'},
        {'name': 'Carrot', 'amount': '1'},
        {'name': 'Celery', 'amount': '1 stalk'},
        {'name': 'Vegetable stock', 'amount': '4 cups'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 280, 'protein': 15, 'carbs': 40, 'fat': 6},
      'image_url': 'https://images.unsplash.com/photo-1547592166-23ac45744acd',
    },
    {
      'title': 'Garlic Butter Shrimp Rice',
      'difficulty': 'medium',
      'cook_time_minutes': 25,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Cook rice according to package.'},
        {'order': 2, 'instruction': 'Saute shrimp in garlic butter until pink.'},
        {'order': 3, 'instruction': 'Serve shrimp over rice with herbs.'},
      ],
      'ingredients_used': [
        {'name': 'Shrimp', 'amount': '250 g'},
        {'name': 'Rice', 'amount': '1 cup'},
        {'name': 'Garlic', 'amount': '3 cloves'},
        {'name': 'Butter', 'amount': '1 tbsp'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 500, 'protein': 30, 'carbs': 50, 'fat': 18},
      'image_url': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8',
    },
    {
      'title': 'Banana Oat Pancakes',
      'difficulty': 'easy',
      'cook_time_minutes': 16,
      'servings': 2,
      'steps': [
        {'order': 1, 'instruction': 'Blend oats, banana, eggs, and milk.'},
        {'order': 2, 'instruction': 'Cook small pancakes on a nonstick pan.'},
        {'order': 3, 'instruction': 'Serve with fruit or honey.'},
      ],
      'ingredients_used': [
        {'name': 'Oats', 'amount': '1 cup'},
        {'name': 'Banana', 'amount': '1'},
        {'name': 'Eggs', 'amount': '2'},
        {'name': 'Milk', 'amount': '1/3 cup'},
      ],
      'missing_ingredients': [],
      'nutrition': {'calories': 390, 'protein': 16, 'carbs': 52, 'fat': 12},
      'image_url': 'https://images.unsplash.com/photo-1528207776546-365bb710ee93',
    },
  ];
}
