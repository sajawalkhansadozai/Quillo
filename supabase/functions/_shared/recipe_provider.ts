// Switch which recipe API(s) power Explore search.
//
// Set RECIPE_SEARCH_PROVIDER in Supabase Edge secrets (or pass "provider" in the request body):
//   edamam          — Edamam only
//   bigoven         — BigOven only
//   spoonacular     — Spoonacular only
//   edamam+bigoven  — Edamam first, BigOven fills gaps (default)
//   all             — all three in parallel (compare during evaluation)

import { searchEdamam } from './edamam.ts';
import { searchBigOven } from './bigoven.ts';
import { searchSpoonacular } from './spoonacular.ts';
import { mergeAndRankRecipes } from './recipe_search_merge.ts';
import type { NormalizedSearchRecipe, RecipeApiSource } from './recipe_types.ts';
import type { EdamamSearchFilters, SpoonacularSearchFilters } from './preference_filters.ts';

export type SearchProviderMode =
  | 'edamam'
  | 'bigoven'
  | 'spoonacular'
  | 'edamam+bigoven'
  | 'all';

export function parseSearchProvider(
  requestOverride?: string,
): SearchProviderMode {
  const raw = (requestOverride ?? Deno.env.get('RECIPE_SEARCH_PROVIDER') ?? 'edamam+bigoven')
    .trim()
    .toLowerCase()
    .replace(/_/g, '+');

  switch (raw) {
    case 'edamam':
    case 'bigoven':
    case 'spoonacular':
    case 'edamam+bigoven':
    case 'all':
      return raw;
    default:
      return 'edamam+bigoven';
  }
}

export interface ProviderCredentials {
  edamamAppId?: string;
  edamamAppKey?: string;
  bigovenKey?: string;
  spoonacularKey?: string;
}

export interface ProviderSearchResult {
  mode: SearchProviderMode;
  edamam: NormalizedSearchRecipe[];
  bigoven: NormalizedSearchRecipe[];
  spoonacular: NormalizedSearchRecipe[];
  merged: NormalizedSearchRecipe[];
  warnings: string[];
}

export async function searchByProvider(
  query: string,
  limit: number,
  mode: SearchProviderMode,
  creds: ProviderCredentials,
  edamamFilters?: EdamamSearchFilters,
  offset = 0,
  spoonacularFilters?: SpoonacularSearchFilters,
): Promise<ProviderSearchResult> {
  const warnings: string[] = [];
  let edamam: NormalizedSearchRecipe[] = [];
  let bigoven: NormalizedSearchRecipe[] = [];
  let spoonacular: NormalizedSearchRecipe[] = [];

  const hasEdamam = !!(creds.edamamAppId && creds.edamamAppKey);
  const hasBigOven = !!creds.bigovenKey;
  const hasSpoonacular = !!creds.spoonacularKey;

  const runEdamam = async () => {
    if (!hasEdamam) {
      warnings.push('Edamam not configured (EDAMAM_APP_ID, EDAMAM_APP_KEY)');
      return;
    }
    edamam = await searchEdamam(query, creds.edamamAppId!, creds.edamamAppKey!, limit, edamamFilters, offset);
    if (edamam.length === 0) warnings.push('Edamam returned no results');
  };

  const runBigOven = async () => {
    if (!hasBigOven) {
      warnings.push('BigOven not configured (BIGOVEN_API_KEY)');
      return;
    }
    bigoven = await searchBigOven(query, creds.bigovenKey!, limit, offset);
    if (bigoven.length === 0) warnings.push('BigOven returned no results');
  };

  const runSpoonacular = async () => {
    if (!hasSpoonacular) {
      warnings.push('Spoonacular not configured (SPOONACULAR_API_KEY)');
      return;
    }
    spoonacular = await searchSpoonacular(
      query,
      creds.spoonacularKey!,
      limit,
      offset,
      spoonacularFilters,
    );
    if (spoonacular.length === 0) warnings.push('Spoonacular returned no results');
  };

  switch (mode) {
    case 'edamam':
      await runEdamam();
      break;
    case 'bigoven':
      await runBigOven();
      break;
    case 'spoonacular':
      await runSpoonacular();
      break;
    case 'edamam+bigoven':
      await runEdamam();
      if (edamam.length < limit) await runBigOven();
      break;
    case 'all':
      await Promise.all([runEdamam(), runBigOven(), runSpoonacular()]);
      break;
  }

  const batches = [edamam, bigoven, spoonacular].filter((b) => b.length > 0);
  const primary: RecipeApiSource = mode === 'bigoven'
    ? 'bigoven'
    : mode === 'spoonacular'
    ? 'spoonacular'
    : 'edamam';

  const merged = batches.length > 0
    ? mergeAndRankRecipes(batches, query, limit, primary)
    : [];

  return { mode, edamam, bigoven, spoonacular, merged, warnings };
}
