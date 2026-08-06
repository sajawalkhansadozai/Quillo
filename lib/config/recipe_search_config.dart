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

  /// Max Explore search results: Supabase catalog first, Edamam fills the rest.
  static const int exploreSearchLimit = 5;

  /// Max AI image upgrades per batch (Explore / Home / Saved / scan).
  /// High enough that a full first page (+ prefetch) can all get Gemini images.
  static const int exploreAiImageUpgradeLimit = 25;

  /// Show a skeleton if search is still loading after this delay.
  static const Duration searchSkeletonAfter = Duration(seconds: 2);

  /// Abort / offer retry if search takes longer than this.
  static const Duration searchTimeout = Duration(seconds: 5);

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
