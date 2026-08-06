// Spoonacular API client — primarily HD images + recipe search.

import {
  type NormalizedIngredient,
  type NormalizedInstruction,
  type NormalizedNutrition,
  type NormalizedSearchRecipe,
  prefixedId,
} from './recipe_types.ts';

import { normalizedToQuillo as toQuillo } from './recipe_types.ts';

export type { QuilloRecipePayload } from './recipe_types.ts';
export { normalizedToQuillo, difficultyFromMinutes } from './recipe_types.ts';

function formatIngredientAmount(item: Record<string, unknown>): string {
  const amount = item.amount;
  const unit = (item.unit as string) || '';
  if (amount == null) return unit.trim() || 'to taste';
  const amountText =
    typeof amount === 'number'
      ? Number.isInteger(amount)
        ? String(amount)
        : amount.toFixed(2).replace(/\.?0+$/, '')
      : String(amount);
  return `${amountText} ${unit}`.trim();
}

function extractSpoonacularNutrition(
  nutrition: Record<string, unknown> | undefined,
): NormalizedNutrition {
  const nutrients = (nutrition?.nutrients as Array<Record<string, unknown>>) ?? [];
  const values = { calories: 0, protein: 0, carbs: 0, fat: 0 };
  for (const n of nutrients) {
    const name = String(n.name ?? '').toLowerCase();
    const amount = Math.round(Number(n.amount ?? 0));
    if (name === 'calories') values.calories = amount;
    else if (name === 'protein') values.protein = amount;
    else if (name === 'carbohydrates') values.carbs = amount;
    else if (name === 'fat') values.fat = amount;
  }
  return values;
}

function parseSpoonacularSteps(item: Record<string, unknown>): NormalizedInstruction[] {
  const instructions = (item.analyzedInstructions as Array<Record<string, unknown>>) ?? [];
  const primarySteps = instructions.length > 0
    ? (instructions[0].steps as Array<Record<string, unknown>>) ?? []
    : [];

  const steps: NormalizedInstruction[] = [];
  for (const step of primarySteps) {
    const text = String(step.step ?? '').trim();
    if (!text) continue;
    steps.push({ order: steps.length + 1, instruction: text });
  }

  if (steps.length === 0) {
    const summary = String(item.summary ?? '').replace(/<[^>]+>/g, '').trim();
    if (summary) {
      steps.push({ order: 1, instruction: summary.slice(0, 240) });
    }
  }

  return steps;
}

export function spoonacularItemToNormalized(
  item: Record<string, unknown>,
  query: string,
): NormalizedSearchRecipe | null {
  const title = String(item.title ?? '').trim();
  const sourceId = String(item.id ?? '').trim();
  if (!title || !sourceId) return null;

  const q = query.toLowerCase();
  const t = title.toLowerCase();
  let relevance = 0;
  if (t === q) relevance += 20;
  else if (t.includes(q)) relevance += 12;
  for (const word of q.split(/\s+/).filter((w) => w.length > 2)) {
    if (t.includes(word)) relevance += 3;
  }
  if (item.image) relevance += 5;

  const extIngredients = (item.extendedIngredients as Array<Record<string, unknown>>) ?? [];
  const ingredients: NormalizedIngredient[] = extIngredients
    .map((ing) => {
      const name = String(ing.nameClean ?? ing.name ?? '').trim();
      if (!name) return null;
      return { name, amount: formatIngredientAmount(ing) };
    })
    .filter((x): x is NormalizedIngredient => x != null);

  const nutrition = extractSpoonacularNutrition(item.nutrition as Record<string, unknown> | undefined);
  if (nutrition.calories > 0) relevance += 2;

  return {
    id: prefixedId('spoonacular', sourceId),
    title,
    image_url: item.image as string | undefined,
    source: 'spoonacular',
    cook_time: Math.max(1, Number(item.readyInMinutes ?? 30)),
    servings: Math.max(1, Number(item.servings ?? 2)),
    cuisine: (item.cuisines as string[] | undefined)?.[0],
    dietary_labels: (item.diets as string[] ?? []).map(String),
    nutrition,
    ingredients,
    instructions: parseSpoonacularSteps(item),
    relevance_score: relevance,
    source_count: 1,
    source_id: sourceId,
    source_url: (item.sourceUrl ?? item.spoonacularSourceUrl) as string | undefined,
  };
}

/** @deprecated Use spoonacularItemToNormalized + normalizedToQuillo */
export function spoonacularToQuillo(
  item: Record<string, unknown>,
  options?: { includeSteps?: boolean; includeAllIngredients?: boolean },
) {
  const normalized = spoonacularItemToNormalized(item, '');
  if (!normalized) {
    return toQuillo({
      id: 'spoon_0',
      title: 'Untitled Recipe',
      source: 'spoonacular',
      cook_time: 30,
      servings: 2,
      dietary_labels: [],
      nutrition: { calories: 0, protein: 0, carbs: 0, fat: 0 },
      ingredients: [],
      instructions: [],
      relevance_score: 0,
      source_count: 1,
      source_id: '0',
    });
  }

  if (options?.includeAllIngredients === false) {
    normalized.ingredients = normalized.ingredients.slice(0, 12);
  }
  if (options?.includeSteps === false) {
    normalized.instructions = [];
  }

  return toQuillo(normalized);
}

export async function fetchSpoonacularById(
  recipeId: string,
  apiKey: string,
): Promise<Record<string, unknown> | null> {
  const url = new URL(`https://api.spoonacular.com/recipes/${recipeId}/information`);
  url.searchParams.set('apiKey', apiKey);
  url.searchParams.set('includeNutrition', 'true');

  const res = await fetch(url.toString(), { signal: AbortSignal.timeout(8000) });
  if (!res.ok) {
    console.error(`Spoonacular recipe ${recipeId} failed: ${res.status}`);
    return null;
  }
  return (await res.json()) as Record<string, unknown>;
}

export async function searchSpoonacular(
  query: string,
  apiKey: string,
  limit: number,
  offset = 0,
  filters?: {
    diet?: string;
    intolerances?: string[];
    cuisine?: string[];
    maxReadyTime?: number;
  },
): Promise<NormalizedSearchRecipe[]> {
  const url = new URL('https://api.spoonacular.com/recipes/complexSearch');
  url.searchParams.set('apiKey', apiKey);
  url.searchParams.set('query', query);
  url.searchParams.set('number', String(Math.min(Math.max(limit, 1), 30)));
  url.searchParams.set('offset', String(Math.max(0, offset)));
  url.searchParams.set('addRecipeInformation', 'true');
  url.searchParams.set('addRecipeNutrition', 'true');
  url.searchParams.set('fillIngredients', 'true');
  url.searchParams.set('instructionsRequired', 'false');
  if (filters?.diet) url.searchParams.set('diet', filters.diet);
  if (filters?.intolerances?.length) {
    url.searchParams.set('intolerances', filters.intolerances.join(','));
  }
  if (filters?.cuisine?.length) {
    url.searchParams.set('cuisine', filters.cuisine.join(','));
  }
  if (filters?.maxReadyTime && filters.maxReadyTime > 0) {
    url.searchParams.set('maxReadyTime', String(filters.maxReadyTime));
  }

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      console.error(`Spoonacular search failed: ${res.status}`);
      return [];
    }
    const data = (await res.json()) as { results?: Array<Record<string, unknown>> };
    return (data.results ?? [])
      .map((item) => spoonacularItemToNormalized(item, query))
      .filter((r): r is NormalizedSearchRecipe => r != null);
  } catch (err) {
    console.error('Spoonacular search error:', err);
    return [];
  }
}

export async function fetchSpoonacularNormalized(
  sourceId: string,
  apiKey: string,
): Promise<NormalizedSearchRecipe | null> {
  const item = await fetchSpoonacularById(sourceId, apiKey);
  if (!item) return null;
  return spoonacularItemToNormalized(item, '');
}
