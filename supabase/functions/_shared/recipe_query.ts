import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { QuilloRecipePayload } from './recipe_types.ts';

export const RECIPE_COLUMNS_BASE =
  'id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url, is_public';

export const RECIPE_COLUMNS_WITH_SOURCE =
  `${RECIPE_COLUMNS_BASE}, source, source_id`;

function isMissingSourceColumnError(error: { code?: string; message?: string }): boolean {
  return error.code === '42703' &&
    (error.message?.includes('source') ?? false);
}

export async function listPublicRecipes(
  client: SupabaseClient,
  limit: number,
): Promise<{ data: QuilloRecipePayload[]; error: { code?: string; message?: string } | null }> {
  let result = await client
    .from('recipes')
    .select(RECIPE_COLUMNS_WITH_SOURCE)
    .eq('is_public', true)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (result.error && isMissingSourceColumnError(result.error)) {
    console.warn('recipes.source columns missing — using base recipe columns');
    result = await client
      .from('recipes')
      .select(RECIPE_COLUMNS_BASE)
      .eq('is_public', true)
      .order('created_at', { ascending: false })
      .limit(limit);
  }

  return {
    data: (result.data ?? []) as QuilloRecipePayload[],
    error: result.error,
  };
}

export async function searchPublicRecipesByTitle(
  client: SupabaseClient,
  term: string,
  limit: number,
): Promise<QuilloRecipePayload[]> {
  let result = await client
    .from('recipes')
    .select(RECIPE_COLUMNS_WITH_SOURCE)
    .eq('is_public', true)
    .ilike('title', `%${term}%`)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (result.error && isMissingSourceColumnError(result.error)) {
    result = await client
      .from('recipes')
      .select(RECIPE_COLUMNS_BASE)
      .eq('is_public', true)
      .ilike('title', `%${term}%`)
      .order('created_at', { ascending: false })
      .limit(limit);
  }

  return (result.data ?? []) as QuilloRecipePayload[];
}

export async function parseRequestBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const text = await req.text();
    if (!text.trim()) return {};
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    return {};
  }
}
