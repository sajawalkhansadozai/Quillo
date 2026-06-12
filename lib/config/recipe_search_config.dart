// ─────────────────────────────────────────────────────────────────────────────
// Recipe search provider — for API evaluation before picking one winner.
//
// Change [provider] to test a single API, then set the same value in Supabase
// Edge secrets as RECIPE_SEARCH_PROVIDER when you ship.
//
// Options:
//   'edamam'         — Edamam only
//   'bigoven'        — BigOven only
//   'spoonacular'    — Spoonacular only
//   'edamam+bigoven' — Edamam first, BigOven fills gaps (default)
//   'all'            — all three in parallel (compare side by side)
// ─────────────────────────────────────────────────────────────────────────────

class RecipeSearchConfig {
  /// Active provider for Explore web search. Change this line to switch APIs.
  static const String provider = 'edamam';

  /// Label shown in Explore search (derived from provider).
  static String get exploreSearchHint {
    switch (provider) {
      case 'bigoven':
        return 'Searching BigOven';
      case 'spoonacular':
        return 'Searching Spoonacular';
      case 'all':
        return 'Comparing Edamam, BigOven & Spoonacular';
      case 'edamam+bigoven':
        return 'From your catalog & Edamam (BigOven fills gaps)';
      case 'edamam':
      default:
        return 'From your catalog & Edamam';
    }
  }
}
