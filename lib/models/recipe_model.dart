import 'package:flutter/material.dart';
import 'package:quillo/theme/app_theme.dart';

class RecipeModel {
  final String id;
  final String name;
  final String emoji;
  final int time;
  final int servings;
  final String difficulty;
  final String cuisine;
  final double rating;
  final int reviews;
  final int calories;
  final String tag;
  final Color color;
  final String chef;
  final List<IngredientModel> ingredients;
  final List<InstructionModel> instructions;
  final NutritionModel nutrition;
  final List<String> tags;
  final bool isSaved;

  const RecipeModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.time,
    required this.servings,
    required this.difficulty,
    required this.cuisine,
    required this.rating,
    required this.reviews,
    required this.calories,
    required this.tag,
    required this.color,
    required this.chef,
    required this.ingredients,
    required this.instructions,
    required this.nutrition,
    required this.tags,
    this.isSaved = false,
  });

  static RecipeModel get featured => const RecipeModel(
        id: '1',
        name: 'Spiced Ramen Bowl',
        emoji: '🍜',
        time: 20,
        servings: 2,
        difficulty: 'Medium',
        cuisine: 'Japanese',
        rating: 4.9,
        reviews: 2341,
        calories: 490,
        tag: "Chef's Pick",
        color: AppColors.primary,
        chef: 'Chef Maria R.',
        tags: ['Italian', 'Easy', 'AI Pick'],
        ingredients: [
          IngredientModel(name: 'Penne', amount: '300g', emoji: '🍝'),
          IngredientModel(name: 'Parmesan', amount: '80g', emoji: '🧀'),
          IngredientModel(name: 'Lemon', amount: '1 whole', emoji: '🍋'),
          IngredientModel(name: 'Garlic', amount: '3 cloves', emoji: '🧄'),
          IngredientModel(name: 'Olive Oil', amount: '3 tbsp', emoji: '🫒'),
          IngredientModel(name: 'Fresh Broccoli', amount: '200g', emoji: '🥦'),
        ],
        instructions: [
          InstructionModel(
            step: 1,
            title: 'Boil the pasta',
            description:
                'Bring a large pot of generously salted water to a rolling boil. Cook penne until al dente, usually 1 minute less than the pack says. Reserve a cup of pasta water before draining.',
            durationMins: 8,
          ),
          InstructionModel(
            step: 2,
            title: 'Make the sauce',
            description:
                'Warm olive oil in a wide pan over medium heat. Add minced garlic and chili flakes, sauté 60 seconds until fragrant. Grate in lemon zest and squeeze in the juice. Don\'t let garlic brown.',
            durationMins: 3,
          ),
          InstructionModel(
            step: 3,
            title: 'Bring it together',
            description:
                'Add drained pasta to the pan with a splash of pasta water. Toss vigorously off the heat. Add cold butter in cubes and keep tossing until it glows. Add more pasta water if needed to loosen.',
            durationMins: 4,
          ),
          InstructionModel(
            step: 4,
            title: 'Finish and plate',
            description:
                'Fold in half the parmesan. Season well with salt and cracked black pepper. Divide between warm bowls, shower with remaining parmesan and tear over fresh basil leaves. Serve immediately.',
            durationMins: 2,
          ),
        ],
        nutrition: NutritionModel(calories: 490, protein: 22, carbs: 58, fat: 14),
      );

  static const List<RecipeModel> suggested = [
    RecipeModel(
      id: '2', name: 'Lemon Butter Pasta', emoji: '🍝', time: 30, servings: 2,
      difficulty: 'Easy', cuisine: 'Italian', rating: 4.7, reviews: 890, calories: 420,
      tag: 'QUICK', color: Color(0xFFFF9800), chef: 'Chef Luca',
      tags: ['Quick', 'Italian'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 420, protein: 15, carbs: 52, fat: 18),
    ),
    RecipeModel(
      id: '3', name: 'Avocado Buddha Bowl', emoji: '🥗', time: 15, servings: 1,
      difficulty: 'Easy', cuisine: 'Healthy', rating: 4.8, reviews: 1240, calories: 380,
      tag: 'VEGAN', color: Color(0xFF4CAF50), chef: 'Chef Aria',
      tags: ['Vegan', 'Healthy'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 380, protein: 12, carbs: 45, fat: 16),
    ),
    RecipeModel(
      id: '4', name: 'Chicken Tikka Masala', emoji: '🍛', time: 45, servings: 3,
      difficulty: 'Medium', cuisine: 'Indian', rating: 4.9, reviews: 2100, calories: 510,
      tag: 'DINNER', color: Color(0xFFE91E63), chef: 'Chef Priya',
      tags: ['Dinner', 'Indian'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 510, protein: 32, carbs: 28, fat: 22),
    ),
    RecipeModel(
      id: '5', name: 'Strawberry Mousse', emoji: '🍓', time: 30, servings: 3,
      difficulty: 'Medium', cuisine: 'Dessert', rating: 4.6, reviews: 670, calories: 280,
      tag: 'DESSERT', color: Color(0xFFE91E63), chef: 'Chef Sophie',
      tags: ['Dessert', 'Sweet'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 280, protein: 5, carbs: 38, fat: 12),
    ),
  ];

  static const List<RecipeModel> saved = [
    RecipeModel(
      id: '6', name: 'Fluffy Pancakes', emoji: '🥞', time: 20, servings: 2,
      difficulty: 'Easy', cuisine: 'American', rating: 4.8, reviews: 990, calories: 340,
      tag: '', color: AppColors.accent, chef: 'Chef Tom',
      tags: ['Breakfast'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 340, protein: 10, carbs: 48, fat: 14),
    ),
    RecipeModel(
      id: '7', name: 'Spring Green Salad', emoji: '🥗', time: 10, servings: 2,
      difficulty: 'Easy', cuisine: 'Healthy', rating: 4.5, reviews: 450, calories: 180,
      tag: '', color: Color(0xFF4CAF50), chef: 'Chef Eva',
      tags: ['Salad'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 180, protein: 6, carbs: 22, fat: 8),
    ),
    RecipeModel(
      id: '8', name: 'Tofu Stir Fry', emoji: '🥘', time: 25, servings: 2,
      difficulty: 'Easy', cuisine: 'Asian', rating: 4.6, reviews: 720, calories: 290,
      tag: '', color: AppColors.primary, chef: 'Chef Mei',
      tags: ['Vegan'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 290, protein: 18, carbs: 30, fat: 10),
    ),
  ];

  static const List<RecipeModel> savedAll = [
    RecipeModel(
      id: 's1', name: 'Spiced Ramen Bowl', emoji: '🍜', time: 20, servings: 2,
      difficulty: 'Medium', cuisine: 'Japanese', rating: 4.9, reviews: 2341, calories: 490,
      tag: "CHEF'S PICK", color: Color(0xFF6C63FF), chef: 'Chef Maria R.',
      tags: ['Japanese', 'Spicy'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 490, protein: 22, carbs: 58, fat: 14), isSaved: true,
    ),
    RecipeModel(
      id: 's2', name: 'Lemon Butter Pasta', emoji: '🍝', time: 30, servings: 2,
      difficulty: 'Easy', cuisine: 'Italian', rating: 4.7, reviews: 890, calories: 420,
      tag: 'QUICK', color: Color(0xFFFF9800), chef: 'Chef Luca',
      tags: ['Quick', 'Italian'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 420, protein: 15, carbs: 52, fat: 18), isSaved: true,
    ),
    RecipeModel(
      id: 's3', name: 'Avocado Buddha Bowl', emoji: '🥗', time: 15, servings: 1,
      difficulty: 'Easy', cuisine: 'Healthy', rating: 4.8, reviews: 1240, calories: 380,
      tag: 'VEGAN', color: Color(0xFF4CAF50), chef: 'Chef Aria',
      tags: ['Vegan', 'Healthy'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 380, protein: 12, carbs: 45, fat: 16), isSaved: true,
    ),
    RecipeModel(
      id: 's4', name: 'Chicken Tikka Masala', emoji: '🍛', time: 45, servings: 3,
      difficulty: 'Medium', cuisine: 'Indian', rating: 4.9, reviews: 2100, calories: 510,
      tag: 'DINNER', color: Color(0xFFE91E63), chef: 'Chef Priya',
      tags: ['Dinner', 'Indian'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 510, protein: 32, carbs: 28, fat: 22), isSaved: true,
    ),
    RecipeModel(
      id: 's5', name: 'Strawberry Mousse', emoji: '🍓', time: 30, servings: 3,
      difficulty: 'Medium', cuisine: 'Dessert', rating: 4.6, reviews: 670, calories: 280,
      tag: 'DESSERT', color: Color(0xFFE91E63), chef: 'Chef Sophie',
      tags: ['Dessert', 'Sweet'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 280, protein: 5, carbs: 38, fat: 12), isSaved: true,
    ),
    RecipeModel(
      id: 's6', name: 'Fluffy Fluffy Pancakes', emoji: '🥞', time: 20, servings: 2,
      difficulty: 'Easy', cuisine: 'American', rating: 4.8, reviews: 990, calories: 340,
      tag: 'BREAKFAST', color: Color(0xFFFFC107), chef: 'Chef Tom',
      tags: ['Breakfast'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 340, protein: 10, carbs: 48, fat: 14), isSaved: true,
    ),
    RecipeModel(
      id: 's7', name: 'Garlic Lemon Risotto', emoji: '🍚', time: 35, servings: 2,
      difficulty: 'Medium', cuisine: 'Italian', rating: 4.7, reviews: 543, calories: 460,
      tag: 'LUNCH', color: Color(0xFF6C63FF), chef: 'Chef Marco',
      tags: ['Italian', 'Lunch'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 460, protein: 14, carbs: 62, fat: 16), isSaved: true,
    ),
    RecipeModel(
      id: 's8', name: 'Spring Green Salad', emoji: '🥗', time: 10, servings: 2,
      difficulty: 'Easy', cuisine: 'Healthy', rating: 4.5, reviews: 450, calories: 180,
      tag: 'LIGHT', color: Color(0xFF4CAF50), chef: 'Chef Eva',
      tags: ['Salad', 'Light'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 180, protein: 6, carbs: 22, fat: 8), isSaved: true,
    ),
    RecipeModel(
      id: 's9', name: 'Carrot Ginger Soup', emoji: '🥣', time: 25, servings: 3,
      difficulty: 'Easy', cuisine: 'Healthy', rating: 4.6, reviews: 380, calories: 210,
      tag: 'SOUP', color: Color(0xFFFF9800), chef: 'Chef Nora',
      tags: ['Soup', 'Healthy'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 210, protein: 5, carbs: 32, fat: 7), isSaved: true,
    ),
    RecipeModel(
      id: 's10', name: 'Mango Coconut Ice Cream', emoji: '🍨', time: 15, servings: 4,
      difficulty: 'Easy', cuisine: 'Dessert', rating: 4.8, reviews: 720, calories: 240,
      tag: 'DESSERT', color: Color(0xFFFFEB3B), chef: 'Chef Mei',
      tags: ['Dessert', 'Vegan'], ingredients: [], instructions: [],
      nutrition: NutritionModel(calories: 240, protein: 3, carbs: 36, fat: 10), isSaved: true,
    ),
  ];
}

class IngredientModel {
  final String name;
  final String amount;
  final String emoji;
  final bool isMissing;

  const IngredientModel({
    required this.name,
    required this.amount,
    required this.emoji,
    this.isMissing = false,
  });
}

class InstructionModel {
  final int step;
  final String title;
  final String description;
  final int durationMins;

  const InstructionModel({
    required this.step,
    required this.title,
    required this.description,
    required this.durationMins,
  });
}

class NutritionModel {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const NutritionModel({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

extension RecipeModelExtension on RecipeModel {
  List<IngredientModel> get missingItems => ingredients.where((i) => i.isMissing).toList();
}
