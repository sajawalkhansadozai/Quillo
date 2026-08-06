// ─────────────────────────────────────────────────────────────────────────────
// GeneratedRecipe — represents an AI-generated recipe returned by the
// generate-recipes Edge Function.
// ─────────────────────────────────────────────────────────────────────────────

import '../utils/recipe_image_source.dart';
import '../utils/ingredient_amount_scale.dart';

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
  final bool isPublic;
  /// Provider when the recipe is not stored in Supabase yet (e.g. spoonacular).
  final String? externalSource;
  final String? externalId;

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
    this.isPublic = false,
    this.externalSource,
    this.externalId,
  });

  bool get isExternal =>
      externalSource != null &&
      externalSource!.isNotEmpty &&
      externalId != null &&
      externalId!.isNotEmpty;

  /// True when steps are missing or only a source-URL placeholder (e.g. Edamam).
  bool get needsGeneratedInstructions {
    if (steps.isEmpty) return true;
    if (steps.length > 1) return false;
    final text = steps.first.instruction.toLowerCase();
    return text.contains('see full instructions at') ||
        text.contains('follow the linked recipe') ||
        text.startsWith('http');
  }

  factory GeneratedRecipe.fromJson(Map<String, dynamic> json) {
    var id = json['id']?.toString();
    var externalSource =
        json['external_source'] as String? ?? json['source'] as String?;
    var externalId =
        json['external_id']?.toString() ?? json['source_id']?.toString();

    if (id != null && !isSupabaseRecipeId(id)) {
      final prefixed = parsePrefixedProviderId(id);
      if (prefixed != null) {
        externalSource ??= prefixed.source;
        externalId ??= prefixed.sourceId;
      }
      id = null;
    }

    return GeneratedRecipe(
      id: id,
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
      isPublic: json['is_public'] as bool? ?? false,
      externalSource: externalSource,
      externalId: externalId,
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
        'is_public': isPublic,
        if (externalSource != null) 'external_source': externalSource,
        if (externalId != null) 'external_id': externalId,
      };

  GeneratedRecipe copyWith({
    String? id,
    String? title,
    String? difficulty,
    int? cookTimeMinutes,
    int? servings,
    List<RecipeStep>? steps,
    List<RecipeIngredientUsed>? ingredientsUsed,
    List<MissingIngredient>? missingIngredients,
    RecipeNutritionData? nutrition,
    String? imageUrl,
    bool? isPublic,
    String? externalSource,
    String? externalId,
  }) {
    return GeneratedRecipe(
      id: id ?? this.id,
      title: title ?? this.title,
      difficulty: difficulty ?? this.difficulty,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      servings: servings ?? this.servings,
      steps: steps ?? this.steps,
      ingredientsUsed: ingredientsUsed ?? this.ingredientsUsed,
      missingIngredients: missingIngredients ?? this.missingIngredients,
      nutrition: nutrition ?? this.nutrition,
      imageUrl: imageUrl ?? this.imageUrl,
      isPublic: isPublic ?? this.isPublic,
      externalSource: externalSource ?? this.externalSource,
      externalId: externalId ?? this.externalId,
    );
  }

  /// Returns a copy with ingredient amounts adjusted for [servings].
  GeneratedRecipe scaledToServings(int servings) {
    final base = this.servings > 0 ? this.servings : servings;
    if (servings == base) return this;
    final factor = servings / base;
    return copyWith(
      servings: servings,
      ingredientsUsed: ingredientsUsed
          .map(
            (i) => RecipeIngredientUsed(
              name: i.name,
              amount: IngredientAmountScale.scale(i.amount, factor),
            ),
          )
          .toList(),
      missingIngredients: missingIngredients
          .map(
            (i) => MissingIngredient(
              name: i.name,
              amount: IngredientAmountScale.scale(i.amount, factor),
            ),
          )
          .toList(),
    );
  }

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
    final mins = effectiveCookTimeMinutes;
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Sum of per-step [durationMinutes] when present.
  static int sumStepDurations(List<RecipeStep> steps) {
    var total = 0;
    for (final step in steps) {
      final d = step.durationMinutes;
      if (d != null && d > 0) total += d;
    }
    return total;
  }

  /// Prefer step durations when they exceed the stored cook time (e.g. 30 min
  /// placeholder vs 60+ min in generated instructions).
  int get effectiveCookTimeMinutes {
    final fromSteps = sumStepDurations(steps);
    if (fromSteps > cookTimeMinutes) return fromSteps;
    return cookTimeMinutes;
  }

  /// Total ingredients in the recipe (from scan + still needed).
  int get ingredientCount =>
      ingredientsUsed.length + missingIngredients.length;

  /// Share of recipe ingredients already covered by the user's scan (0–100).
  int get matchPercent {
    if (ingredientCount == 0) return 100;
    return ((ingredientsUsed.length / ingredientCount) * 100).round();
  }

  String get matchLabel =>
      matchPercent >= 100 ? '100% match' : '$matchPercent% match';

  static int compareByIngredientMatch(GeneratedRecipe a, GeneratedRecipe b) =>
      b.matchPercent.compareTo(a.matchPercent);

  static List<GeneratedRecipe> sortedByIngredientMatch(
    List<GeneratedRecipe> recipes,
  ) {
    final list = List<GeneratedRecipe>.from(recipes);
    list.sort(compareByIngredientMatch);
    return list;
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
