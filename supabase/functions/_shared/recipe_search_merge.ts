import { type NormalizedSearchRecipe, type RecipeApiSource } from './recipe_types.ts';

function normalizeTitle(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function nutritionScore(n: NormalizedSearchRecipe['nutrition']): number {
  let score = 0;
  if (n.calories > 0) score += 4;
  if (n.protein > 0) score += 1;
  if (n.carbs > 0) score += 1;
  if (n.fat > 0) score += 1;
  return score;
}

function imageScore(source: RecipeApiSource, hasImage: boolean): number {
  if (!hasImage) return 0;
  if (source === 'edamam') return 10;
  if (source === 'bigoven') return 7;
  if (source === 'spoonacular') return 8;
  return 4;
}

function pickBetter(
  current: NormalizedSearchRecipe,
  candidate: NormalizedSearchRecipe,
): NormalizedSearchRecipe {
  const curImg = imageScore(current.source, !!current.image_url);
  const candImg = imageScore(candidate.source, !!candidate.image_url);

  const merged: NormalizedSearchRecipe = { ...current };

  // Image: prefer Spoonacular HD, then any with image
  if (candImg > curImg || (!merged.image_url && candidate.image_url)) {
    merged.image_url = candidate.image_url ?? merged.image_url;
  }

  // Nutrition: prefer Edamam, then fuller data
  const curNut = nutritionScore(current.nutrition);
  const candNut = nutritionScore(candidate.nutrition);
  const preferCandNut =
    (candidate.source === 'edamam' && current.source !== 'edamam') ||
    (candNut > curNut && candidate.source === 'edamam') ||
    (candNut > curNut + 2);

  if (preferCandNut) merged.nutrition = { ...candidate.nutrition };

  // Dietary labels: union (Edamam)
  merged.dietary_labels = [
    ...new Set([...merged.dietary_labels, ...candidate.dietary_labels]),
  ];

  // Ingredients: prefer more complete list
  if (candidate.ingredients.length > merged.ingredients.length) {
    merged.ingredients = candidate.ingredients;
  }

  // Instructions: prefer longer
  if (candidate.instructions.length > merged.instructions.length) {
    merged.instructions = candidate.instructions;
  }

  // Cuisine
  if (!merged.cuisine && candidate.cuisine) merged.cuisine = candidate.cuisine;

  // Servings / cook time: keep non-default values
  if (merged.cook_time <= 1 && candidate.cook_time > 1) {
    merged.cook_time = candidate.cook_time;
  }
  if (candidate.servings > 0) merged.servings = candidate.servings;

  // Primary id/source: prefer edamam (nutrition), then bigoven
  const curPrimary = current.source === 'edamam' ? 3 : current.source === 'bigoven' ? 2 : 1;
  const candPrimary = candidate.source === 'edamam' ? 3 : candidate.source === 'bigoven' ? 2 : 1;
  if (candPrimary > curPrimary) {
    merged.id = candidate.id;
    merged.source = candidate.source;
    merged.source_id = candidate.source_id;
    merged.source_url = candidate.source_url ?? merged.source_url;
  }

  merged.relevance_score = Math.max(merged.relevance_score, candidate.relevance_score);
  merged.source_count += 1;

  return merged;
}

/**
 * Merge results from all APIs, dedupe by title, boost multi-source hits.
 */
export function mergeAndRankRecipes(
  batches: NormalizedSearchRecipe[][],
  query: string,
  limit: number,
  primarySource: RecipeApiSource = 'edamam',
): NormalizedSearchRecipe[] {
  const flat = batches.flat();
  const groups = new Map<string, NormalizedSearchRecipe>();

  for (const recipe of flat) {
    const key = normalizeTitle(recipe.title);
    if (!key) continue;

    const existing = groups.get(key);
    if (!existing) {
      groups.set(key, { ...recipe, source_count: 1 });
    } else {
      groups.set(key, pickBetter(existing, recipe));
    }
  }

  const q = query.toLowerCase().trim();
  const merged = [...groups.values()].map((r) => {
    let score = r.relevance_score;

    // Multi-database boost — popular, well-tested recipes
    if (r.source_count >= 2) score += 15 * (r.source_count - 1);
    if (r.source_count >= 3) score += 10;

    if (r.image_url) score += 5;
    score += nutritionScore(r.nutrition);
    if (r.ingredients.length >= 5) score += 2;
    if (r.instructions.length >= 3) score += 2;
    if (r.source === primarySource) score += 8;
    if (r.dietary_labels.length > 0) score += 3;

    const t = r.title.toLowerCase();
    if (q && t === q) score += 25;
    else if (q && t.startsWith(q)) score += 15;
    else if (q && t.includes(q)) score += 8;

    return { ...r, relevance_score: score };
  });

  merged.sort((a, b) => b.relevance_score - a.relevance_score);
  return merged.slice(0, limit);
}
