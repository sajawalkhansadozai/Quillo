import {
  type NormalizedIngredient,
  type NormalizedInstruction,
  type NormalizedNutrition,
  type NormalizedSearchRecipe,
  prefixedId,
} from './recipe_types.ts';

function parseBigOvenInstructions(text: string): NormalizedInstruction[] {
  const chunks = text
    .replace(/\r\n/g, '\n')
    .split(/\n+/)
    .map((s) => s.trim())
    .filter(Boolean);

  if (chunks.length === 0) return [];
  return chunks.slice(0, 30).map((instruction, i) => ({ order: i + 1, instruction }));
}

function bigOvenListItemToNormalized(
  item: Record<string, unknown>,
  query: string,
): NormalizedSearchRecipe | null {
  const recipeId = item.RecipeID ?? item.recipeId;
  const title = String(item.Title ?? item.title ?? '').trim();
  if (!recipeId || !title) return null;

  const sourceId = String(recipeId);
  const q = query.toLowerCase();
  const t = title.toLowerCase();
  let relevance = 0;
  if (t === q) relevance += 20;
  else if (t.includes(q)) relevance += 12;
  for (const word of q.split(/\s+/).filter((w) => w.length > 2)) {
    if (t.includes(word)) relevance += 3;
  }

  return {
    id: prefixedId('bigoven', sourceId),
    title,
    image_url: (item.PhotoUrl ?? item.ImageURL ?? item.ImageUrl) as string | undefined,
    source: 'bigoven',
    cook_time: Number(item.TotalMinutes ?? item.ActiveMinutes ?? 45),
    servings: Math.max(1, Number(item.Servings ?? 4)),
    cuisine: String(item.Cuisine ?? item.Category ?? '').trim() || undefined,
    dietary_labels: [],
    nutrition: { calories: 0, protein: 0, carbs: 0, fat: 0 },
    ingredients: [],
    instructions: [],
    relevance_score: relevance,
    source_count: 1,
    source_id: sourceId,
    source_url: String(item.WebURL ?? item.WebUrl ?? '') || undefined,
  };
}

export function bigOvenDetailToNormalized(
  detail: Record<string, unknown>,
): NormalizedSearchRecipe | null {
  const recipeId = detail.RecipeID ?? detail.RecipeId;
  const title = String(detail.Title ?? '').trim();
  if (!recipeId || !title) return null;

  const sourceId = String(recipeId);
  const ingredients: NormalizedIngredient[] = [];
  for (const ing of (detail.Ingredients as Array<Record<string, unknown>> ?? [])) {
    if (ing.IsHeading) continue;
    const name = String(ing.Name ?? ing.HTMLName ?? '').trim();
    if (!name) continue;
    const qty = String(ing.DisplayQuantity ?? ing.Quantity ?? '').trim();
    const unit = String(ing.Unit ?? '').trim();
    const amount = [qty, unit].filter(Boolean).join(' ') || 'to taste';
    ingredients.push({ name, amount });
  }

  const instructions = parseBigOvenInstructions(String(detail.Instructions ?? ''));
  const nutritionInfo = detail.NutritionInfo as Record<string, unknown> | undefined;

  return {
    id: prefixedId('bigoven', sourceId),
    title,
    image_url: detail.ImageURL as string | undefined,
    source: 'bigoven',
    cook_time: Math.max(1, Number(detail.TotalMinutes ?? 45)),
    servings: Math.max(1, Number(detail.YieldNumber ?? detail.Servings ?? 4)),
    cuisine: String(detail.Cuisine ?? '').trim() || undefined,
    dietary_labels: [],
    nutrition: {
      calories: Math.round(Number(nutritionInfo?.Calories ?? 0)),
      protein: 0,
      carbs: 0,
      fat: Math.round(Number(nutritionInfo?.TotalFat ?? 0)),
    },
    ingredients,
    instructions,
    relevance_score: 0,
    source_count: 1,
    source_id: sourceId,
    source_url: String(detail.WebURL ?? '') || undefined,
  };
}

export async function searchBigOven(
  query: string,
  apiKey: string,
  limit = 20,
  offset = 0,
): Promise<NormalizedSearchRecipe[]> {
  const rpp = Math.min(Math.max(limit, 1), 25);
  const page = Math.floor(Math.max(0, offset) / rpp) + 1;
  const skipInPage = Math.max(0, offset) % rpp;
  const url = new URL('https://api2.bigoven.com/recipes');
  url.searchParams.set('pg', String(page));
  url.searchParams.set('rpp', String(rpp + skipInPage));
  url.searchParams.set('any_kw', query);
  url.searchParams.set('isbookmark', '0');
  url.searchParams.set('api_key', apiKey);

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      console.error(`BigOven search failed: ${res.status}`);
      return [];
    }
    const data = (await res.json()) as { Results?: Array<Record<string, unknown>> };
    return (data.Results ?? [])
      .map((item) => bigOvenListItemToNormalized(item, query))
      .filter((r): r is NormalizedSearchRecipe => r != null)
      .slice(skipInPage, skipInPage + rpp);
  } catch (err) {
    console.error('BigOven search error:', err);
    return [];
  }
}

export async function fetchBigOvenRecipe(
  sourceId: string,
  apiKey: string,
): Promise<NormalizedSearchRecipe | null> {
  const url = new URL(`https://api2.bigoven.com/recipe/${sourceId}`);
  url.searchParams.set('api_key', apiKey);

  try {
    const res = await fetch(url.toString(), { signal: AbortSignal.timeout(8000) });
    if (!res.ok) {
      console.error(`BigOven recipe ${sourceId} failed: ${res.status}`);
      return null;
    }
    const data = (await res.json()) as Record<string, unknown>;
    return bigOvenDetailToNormalized(data);
  } catch (err) {
    console.error('BigOven fetch error:', err);
    return null;
  }
}

export interface BigOvenGroceryItem {
  name: string;
  amount: string;
  department?: string;
  guid?: string;
  recipe_id?: number;
}

/** Add recipe to BigOven cloud grocery list and return synced items. */
export async function syncBigOvenGroceryList(
  recipeId: string,
  apiKey: string,
  userEmail: string,
  userPassword: string,
  scale = 1,
): Promise<BigOvenGroceryItem[]> {
  const basicAuth = btoa(`${userEmail}:${userPassword}`);
  const headers = {
    Authorization: `Basic ${basicAuth}`,
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  const addRes = await fetch('https://api2.bigoven.com/grocerylist/recipe', {
    method: 'POST',
    headers,
    body: new URLSearchParams({
      recipeId: String(recipeId),
      scale: String(scale),
      markAsPending: 'false',
    }),
    signal: AbortSignal.timeout(10000),
  });

  if (!addRes.ok) {
    const body = await addRes.text();
    throw new Error(`BigOven grocerylist/recipe failed (${addRes.status}): ${body}`);
  }

  const listRes = await fetch(
    `https://api2.bigoven.com/grocerylist?api_key=${encodeURIComponent(apiKey)}`,
    { headers: { Authorization: basicAuth }, signal: AbortSignal.timeout(10000) },
  );

  if (!listRes.ok) {
    const body = await listRes.text();
    throw new Error(`BigOven grocerylist GET failed (${listRes.status}): ${body}`);
  }

  const list = (await listRes.json()) as { Items?: Array<Record<string, unknown>> };
  return (list.Items ?? []).map((item) => ({
    name: String(item.Name ?? '').trim(),
    amount: String(item.DisplayQuantity ?? '').trim() || '1',
    department: String(item.Department ?? '').trim() || undefined,
    guid: String(item.GUID ?? '') || undefined,
    recipe_id: Number(item.RecipeID ?? 0) || undefined,
  })).filter((i) => i.name.length > 0);
}
