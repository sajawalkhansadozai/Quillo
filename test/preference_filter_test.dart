import 'package:flutter_test/flutter_test.dart';
import 'package:quillo/models/generated_recipe.dart';
import 'package:quillo/models/user_recipe_preferences.dart';
import 'package:quillo/utils/cooking_skill_labels.dart';
import 'package:quillo/utils/ingredient_amount_scale.dart';
import 'package:quillo/utils/non_food_ingredient_filter.dart';
import 'package:quillo/utils/recipe_preference_filter.dart';

GeneratedRecipe _recipe({
  String title = 'Chicken Stir Fry',
  String difficulty = 'easy',
  int cookTimeMinutes = 20,
  int servings = 2,
  List<String> ingredients = const ['chicken breast', 'rice'],
}) {
  return GeneratedRecipe(
    title: title,
    difficulty: difficulty,
    cookTimeMinutes: cookTimeMinutes,
    servings: servings,
    steps: const [
      RecipeStep(order: 1, instruction: 'Cook the ingredients.'),
    ],
    ingredientsUsed: ingredients
        .map((n) => RecipeIngredientUsed(name: n, amount: '100g'))
        .toList(),
    missingIngredients: const [],
    nutrition: const RecipeNutritionData(
      calories: 400,
      protein: 30,
      carbs: 40,
      fat: 10,
    ),
  );
}

void main() {
  group('CookingSkillLabels', () {
    test('normalizes onboarding titles to profile values', () {
      expect(CookingSkillLabels.normalize('Beginner'), 'Beginner');
      expect(CookingSkillLabels.normalize('Home Cook'), 'Intermediate');
      expect(CookingSkillLabels.normalize('Confident Cook'), 'Advanced');
      expect(CookingSkillLabels.normalize('Pro Chef'), 'Expert');
      expect(CookingSkillLabels.normalize('unknown'), 'Intermediate');
    });
  });

  group('NonFoodIngredientFilter', () {
    test('keeps food items', () {
      expect(NonFoodIngredientFilter.isFoodName('Chicken Breast'), isTrue);
      expect(NonFoodIngredientFilter.isFoodName('Whole Milk'), isTrue);
    });

    test('rejects bags, cleaning, medicine', () {
      expect(NonFoodIngredientFilter.isFoodName('Carrier Bag Charge'), isFalse);
      expect(NonFoodIngredientFilter.isFoodName('Bleach Cleaner'), isFalse);
      expect(NonFoodIngredientFilter.isFoodName('Paracetamol'), isFalse);
      expect(NonFoodIngredientFilter.isFoodName('Pet Food'), isFalse);
    });

    test('filters a list by name', () {
      final items = ['Chicken', 'Carrier Bag', 'Rice', 'Toilet Roll'];
      final kept = NonFoodIngredientFilter.filter(items, (s) => s);
      expect(kept, ['Chicken', 'Rice']);
    });
  });

  group('IngredientAmountScale', () {
    test('doubles simple amounts', () {
      expect(IngredientAmountScale.scale('100g', 2), '200 g');
      expect(IngredientAmountScale.scale('1 cup', 2), '2 cup');
    });

    test('scales fractions', () {
      expect(IngredientAmountScale.scale('1/2 cup', 2), '1 cup');
    });

    test('leaves non-scalable phrases alone', () {
      expect(IngredientAmountScale.scale('to taste', 2), 'to taste');
      expect(IngredientAmountScale.scale('a pinch', 3), 'a pinch');
    });
  });

  group('GeneratedRecipe.scaledToServings', () {
    test('scales household from 2 to 4', () {
      final base = _recipe(
        servings: 2,
        ingredients: const ['chicken'],
      ).copyWith(
        ingredientsUsed: const [
          RecipeIngredientUsed(name: 'chicken', amount: '200g'),
        ],
      );
      final scaled = base.scaledToServings(4);
      expect(scaled.servings, 4);
      expect(scaled.ingredientsUsed.first.amount, '400 g');
    });
  });

  group('RecipePreferenceFilter hard constraints', () {
    const halal = UserRecipePreferences(
      dietary: ['Halal'],
      maxCookTimeMinutes: 45,
      cookingSkill: 'Intermediate',
    );

    const vegan = UserRecipePreferences(
      dietary: ['Vegan'],
      maxCookTimeMinutes: 45,
      cookingSkill: 'Intermediate',
    );

    const quick = UserRecipePreferences(
      maxCookTimeMinutes: 20,
      cookingSkill: 'Intermediate',
    );

    const beginner = UserRecipePreferences(
      maxCookTimeMinutes: 45,
      cookingSkill: 'Beginner',
    );

    test('halal rejects pork and alcohol', () {
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Pork Belly Roast', ingredients: ['pork belly']),
          halal,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Chicken Wine Sauce', ingredients: ['chicken', 'wine']),
          halal,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Grilled Chicken', ingredients: ['chicken']),
          halal,
        ),
        isTrue,
      );
    });

    test('vegan rejects meat and dairy', () {
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Beef Stew', ingredients: ['beef']),
          vegan,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Cheese Pasta', ingredients: ['pasta', 'cheese']),
          vegan,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Lentil Salad', ingredients: ['lentil', 'tomato']),
          vegan,
        ),
        isTrue,
      );
    });

    test('cook-time ceiling is hard', () {
      expect(
        RecipePreferenceFilter.matches(
          _recipe(cookTimeMinutes: 45),
          quick,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(cookTimeMinutes: 20),
          quick,
        ),
        isTrue,
      );
      // Unknown / zero cook time must fail when a ceiling is set
      expect(
        RecipePreferenceFilter.matches(
          _recipe(cookTimeMinutes: 0),
          quick,
        ),
        isFalse,
      );
    });

    test('beginner skill rejects hard recipes', () {
      expect(
        RecipePreferenceFilter.matches(
          _recipe(difficulty: 'hard'),
          beginner,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(difficulty: 'easy'),
          beginner,
        ),
        isTrue,
      );
    });

    test('excluded ingredients are hard bans', () {
      const prefs = UserRecipePreferences(
        excludedIngredients: ['shellfish', 'peanut'],
        maxCookTimeMinutes: 45,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Peanut Sauce Noodles', ingredients: ['peanut butter']),
          prefs,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(
            title: 'Shellfish Bisque',
            ingredients: ['shellfish stock'],
          ),
          prefs,
        ),
        isFalse,
      );
      expect(
        RecipePreferenceFilter.matches(
          _recipe(title: 'Chicken Rice', ingredients: ['chicken', 'rice']),
          prefs,
        ),
        isTrue,
      );
    });

    test('apply drops violators and keeps compliant', () {
      final recipes = [
        _recipe(title: 'Quick Salad', cookTimeMinutes: 15),
        _recipe(title: 'Slow Roast', cookTimeMinutes: 90),
        _recipe(title: 'Pork Tacos', ingredients: ['pork']),
      ];
      final filtered = RecipePreferenceFilter.apply(recipes, halal.copyWithMax(20));
      expect(filtered.map((r) => r.title), ['Quick Salad']);
    });

    test('cuisine is ranking not hard filter', () {
      const italianPref = UserRecipePreferences(
        cuisines: ['Italian'],
        maxCookTimeMinutes: 60,
      );
      final thai = _recipe(title: 'Pad Thai', ingredients: ['noodles', 'tofu']);
      final pasta = _recipe(
        title: 'Spaghetti Carbonara',
        ingredients: ['pasta', 'egg'],
      );
      // Both can match hard constraints; Thai is not excluded
      expect(RecipePreferenceFilter.matches(thai, italianPref), isTrue);
      final ranked = RecipePreferenceFilter.apply([thai, pasta], italianPref);
      expect(ranked.first.title, 'Spaghetti Carbonara');
    });
  });
}

extension on UserRecipePreferences {
  UserRecipePreferences copyWithMax(int minutes) => UserRecipePreferences(
        dietary: dietary,
        cuisines: cuisines,
        maxCookTimeMinutes: minutes,
        cookingSkill: cookingSkill,
        householdSize: householdSize,
        excludedIngredients: excludedIngredients,
      );
}
