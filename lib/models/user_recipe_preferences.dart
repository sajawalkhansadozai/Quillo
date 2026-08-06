// ─────────────────────────────────────────────────────────────────────────────
// UserRecipePreferences — saved dietary, cuisine, and cooking constraints
// ─────────────────────────────────────────────────────────────────────────────

class UserRecipePreferences {
  final List<String> dietary;
  final List<String> cuisines;
  final int maxCookTimeMinutes;
  final String cookingSkill;
  final int householdSize;

  const UserRecipePreferences({
    this.dietary = const [],
    this.cuisines = const [],
    this.maxCookTimeMinutes = 45,
    this.cookingSkill = 'Intermediate',
    this.householdSize = 2,
  });

  bool get hasAny =>
      dietary.isNotEmpty ||
      cuisines.isNotEmpty ||
      maxCookTimeMinutes > 0 ||
      cookingSkill.isNotEmpty;

  static const empty = UserRecipePreferences();

  Map<String, dynamic> toJson() => {
        'dietary': dietary,
        'cuisines': cuisines,
        'max_cook_time_minutes': maxCookTimeMinutes,
        'cooking_skill': cookingSkill,
        'household_size': householdSize,
      };
}
