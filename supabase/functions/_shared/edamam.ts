import {
  type NormalizedIngredient,
  type NormalizedInstruction,
  type NormalizedNutrition,
  type NormalizedSearchRecipe,
  prefixedId,
} from './recipe_types.ts';

function edamamSourceId(uri: string): string {
  if (uri.includes('#recipe_')) return uri.split('#recipe_')[1] ?? uri;
  return uri;
}

function nutrientAmount(nutrients: Record<string, unknown>, key: string): number {
  const entry = nutrients[key] as { quantity?: number } | undefined;
  return Math.round(Number(entry?.quantity ?? 0));
}

function extractEdamamNutrition(recipe: Record<string, unknown>): NormalizedNutrition {
  const nutrients = (recipe.totalNutrients ?? {}) as Record<string, unknown>;
  return {
    calories: nutrientAmount(nutrients, 'ENERC_KCAL'),
    protein: nutrientAmount(nutrients, 'PROCNT'),
    carbs: nutrientAmount(nutrients, 'CHOCDF'),
    fat: nutrientAmount(nutrients, 'FAT'),
  };
}

function parseEdamamInstructions(recipe: Record<string, unknown>): NormalizedInstruction[] {
  const steps: NormalizedInstruction[] = [];
  const instructions = recipe.instructions;

  if (Array.isArray(instructions)) {
    for (const step of instructions) {
      const text = String(step).trim();
      if (text) steps.push({ order: steps.length + 1, instruction: text });
    }
  } else if (typeof instructions === 'string' && instructions.trim()) {
    const chunks = instructions.split('\n').map((s) => s.trim()).filter(Boolean);
    for (const chunk of chunks.slice(0, 20)) {
      steps.push({ order: steps.length + 1, instruction: chunk });
    }
  }

  if (steps.length === 0) {
    const url = String(recipe.url ?? recipe.shareAs ?? '').trim();
    steps.push({
      order: 1,
      instruction: url
        ? `See full instructions at ${url}`
        : 'Follow the linked recipe for full instructions.',
    });
  }

  return steps;
}

export function edamamHitToNormalized(
  hit: Record<string, unknown>,
  query: string,
): NormalizedSearchRecipe | null {
  const recipe = hit.recipe as Record<string, unknown> | undefined;
  if (!recipe) return null;

  const title = String(recipe.label ?? '').trim();
  if (!title) return null;

  const uri = String(recipe.uri ?? '');
  const sourceId = edamamSourceId(uri);
  const ingredients: NormalizedIngredient[] = (recipe.ingredientLines as string[] ?? [])
    .map((line) => ({ name: String(line).trim(), amount: '' }))
    .filter((i) => i.name.length > 0);

  const dietLabels = [
    ...(recipe.dietLabels as string[] ?? []),
    ...(recipe.healthLabels as string[] ?? []),
  ].map((l) => String(l));

  const q = query.toLowerCase();
  const t = title.toLowerCase();
  let relevance = 0;
  if (t === q) relevance += 20;
  else if (t.includes(q)) relevance += 12;
  for (const word of q.split(/\s+/).filter((w) => w.length > 2)) {
    if (t.includes(word)) relevance += 3;
  }

  const nutrition = extractEdamamNutrition(recipe);
  if (nutrition.calories > 0) relevance += 3;

  return {
    id: prefixedId('edamam', sourceId),
    title,
    image_url: recipe.image as string | undefined,
    source: 'edamam',
    cook_time: Math.max(1, Number(recipe.totalTime ?? 30)),
    servings: Math.max(1, Number(recipe.yield ?? 2)),
    cuisine: (recipe.cuisineType as string[] | undefined)?.[0],
    dietary_labels: [...new Set(dietLabels)],
    nutrition,
    ingredients,
    instructions: parseEdamamInstructions(recipe),
    relevance_score: relevance,
    source_count: 1,
    source_id: sourceId,
    source_url: String(recipe.url ?? recipe.shareAs ?? '') || undefined,
  };
}

export async function searchEdamam(
  query: string,
  appId: string,
  appKey: string,
  limit = 20,
): Promise<NormalizedSearchRecipe[]> {
  const count = Math.min(Math.max(limit, 1), 20);
  const url = new URL('https://api.edamam.com/api/recipes/v2');
  url.searchParams.set('type', 'public');
  url.searchParams.set('q', query);
  url.searchParams.set('app_id', appId);
  url.searchParams.set('app_key', appKey);
  url.searchParams.set('from', '0');
  url.searchParams.set('to', String(count - 1));

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      console.error(`Edamam search failed: ${res.status}`);
      return [];
    }
    const data = (await res.json()) as { hits?: Array<Record<string, unknown>> };
    return (data.hits ?? [])
      .map((hit) => edamamHitToNormalized(hit, query))
      .filter((r): r is NormalizedSearchRecipe => r != null);
  } catch (err) {
    console.error('Edamam search error:', err);
    return [];
  }
}

export async function fetchEdamamRecipe(
  sourceId: string,
  appId: string,
  appKey: string,
): Promise<NormalizedSearchRecipe | null> {
  const url = new URL(`https://api.edamam.com/api/recipes/v2/${encodeURIComponent(sourceId)}`);
  url.searchParams.set('type', 'public');
  url.searchParams.set('app_id', appId);
  url.searchParams.set('app_key', appKey);

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      console.error(`Edamam recipe ${sourceId} failed: ${res.status}`);
      return null;
    }
    // Single-recipe endpoint returns { recipe: {...}, _links } — same shape as search hits.
    const data = (await res.json()) as Record<string, unknown>;
    return edamamHitToNormalized(data, '');
  } catch (err) {
    console.error('Edamam fetch error:', err);
    return null;
  }
}
