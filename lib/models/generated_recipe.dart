// ─────────────────────────────────────────────────────────────────────────────
// GeneratedRecipe — represents an AI-generated recipe returned by the
// generate-recipes Edge Function.
// ─────────────────────────────────────────────────────────────────────────────

class GeneratedRecipe {
  final String? id;
  final String title;
  final String difficulty;
  final int cookTimeMinutes;
  final int servings;
  final List<RecipeStep> steps;
  final List<RecipeIngredientUsed> ingredientsUsed;
  final List<MissingIngredient> missingIngredients;
  final RecipeNutritionData nutrition;
  final String? imageUrl;

  const GeneratedRecipe({
    this.id,
    required this.title,
    required this.difficulty,
    required this.cookTimeMinutes,
    required this.servings,
    required this.steps,
    required this.ingredientsUsed,
    required this.missingIngredients,
    required this.nutrition,
    this.imageUrl,
  });

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) {
    return GeneratedRecipe(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled Recipe',
      difficulty: json['difficulty'] as String? ?? 'medium',
      cookTimeMinutes: (json['cook_time_minutes'] as num?)?.toInt() ?? 30,
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((s) => RecipeStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      ingredientsUsed: (json['ingredients_used'] as List<dynamic>? ?? [])
          .map((i) => RecipeIngredientUsed.fromJson(i as Map<String, dynamic>))
          .toList(),
      missingIngredients: (json['missing_ingredients'] as List<dynamic>? ?? [])
          .map((i) => MissingIngredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      nutrition: RecipeNutritionData.fromJson(
        json['nutrition'] as Map<String, dynamic>? ?? {},
      ),
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'difficulty': difficulty,
        'cook_time_minutes': cookTimeMinutes,
        'servings': servings,
        'steps': steps.map((s) => s.toJson()).toList(),
        'ingredients_used': ingredientsUsed.map((i) => i.toJson()).toList(),
        'missing_ingredients': missingIngredients.map((i) => i.toJson()).toList(),
        'nutrition': nutrition.toJson(),
        if (imageUrl != null) 'image_url': imageUrl,
      };

  String get difficultyLabel {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'hard':
        return 'Hard';
      default:
        return 'Medium';
    }
  }

  String get cookTimeLabel {
    if (cookTimeMinutes < 60) return '$cookTimeMinutes min';
    final h = cookTimeMinutes ~/ 60;
    final m = cookTimeMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class RecipeStep {
  final int order;
  final String instruction;
  final int? durationMinutes;

  const RecipeStep({
    required this.order,
    required this.instruction,
    this.durationMinutes,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        order: (json['order'] as num?)?.toInt() ?? 1,
        instruction: json['instruction'] as String? ?? '',
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'order': order,
        'instruction': instruction,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class RecipeIngredientUsed {
  final String name;
  final String amount;

  const RecipeIngredientUsed({required this.name, required this.amount});

  factory RecipeIngredientUsed.fromJson(Map<String, dynamic> json) =>
      RecipeIngredientUsed(
        name: json['name'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

// ─────────────────────────────────────────────────────────────────────────────

class MissingIngredient {
  final String name;
  final String amount;

  const MissingIngredient({required this.name, required this.amount});

  factory MissingIngredient.fromJson(Map<String, dynamic> json) =>
      MissingIngredient(
        name: json['name'] as String? ?? '',
        amount: json['amount'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

// ─────────────────────────────────────────────────────────────────────────────

class RecipeNutritionData {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const RecipeNutritionData({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory RecipeNutritionData.fromJson(Map<String, dynamic> json) =>
      RecipeNutritionData(
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}
