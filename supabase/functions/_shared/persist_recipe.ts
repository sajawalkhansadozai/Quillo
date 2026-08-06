// Upsert normalised recipes into public.recipes (deduped by source + source_id).

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  type NormalizedSearchRecipe,
  type QuilloRecipePayload,
  type RecipeApiSource,
  normalizedToQuillo,
  prefixedId,
  titleHash,
} from './recipe_types.ts';
import { spoonacularToQuillo } from './spoonacular.ts';
import { isAppHostedRecipeImage } from './gemini_image.ts';

/** Columns returned to the Flutter app. */
export const RECIPE_CLIENT_COLUMNS =
  'id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url, is_public';

export const RECIPE_SELECT_COLUMNS = RECIPE_CLIENT_COLUMNS;

function isMissingColumnError(error: { code?: string; message?: string; details?: string } | null): boolean {
  const text = `${error?.code ?? ''} ${error?.message ?? ''} ${error?.details ?? ''}`.toLowerCase();
  return text.includes('42703') || text.includes("'source'") ||
    (text.includes('column') && text.includes('does not exist'));
}

let _sourceColumnsCache: boolean | null = null;

export async function sourceColumnsAvailable(admin: SupabaseClient): Promise<boolean> {
  if (_sourceColumnsCache !== null) return _sourceColumnsCache;
  const { error } = await admin.from('recipes').select('source').limit(1);
  _sourceColumnsCache = !error || !isMissingColumnError(error);
  if (!_sourceColumnsCache) {
    console.warn('recipes.source missing — run migration 008_system_recipe_seed_support.sql');
  }
  return _sourceColumnsCache;
}

async function normalizedToDbRow(
  recipe: NormalizedSearchRecipe,
  seedUserId: string,
  withSource: boolean,
): Promise<Record<string, unknown>> {
  const quillo = normalizedToQuillo(recipe);
  const base: Record<string, unknown> = {
    user_id: seedUserId,
    scan_id: null,
    title: quillo.title,
    cook_time_minutes: quillo.cook_time_minutes,
    difficulty: quillo.difficulty,
    servings: quillo.servings,
    steps: quillo.steps,
    ingredients_used: quillo.ingredients_used,
    missing_ingredients: quillo.missing_ingredients,
    nutrition: quillo.nutrition,
    image_url: quillo.image_url ?? null,
    is_public: true,
  };

  if (!withSource) return base;

  const licenseMap: Record<string, string> = {
    edamam: 'Imported via Edamam Recipe API',
    bigoven: 'Imported via BigOven API',
    spoonacular: 'Imported via Spoonacular API',
  };

  return {
    ...base,
    is_system: true,
    source: recipe.source,
    source_id: recipe.source_id,
    source_url: recipe.source_url ?? null,
    license: licenseMap[recipe.source] ?? 'Imported via external API',
    title_hash: await titleHash(recipe.title),
  };
}

/** Batch lookup of recipes already stored in Supabase (keyed by prefixed search id). */
export async function findCachedRecipesForSearchResults(
  admin: SupabaseClient,
  recipes: NormalizedSearchRecipe[],
): Promise<Map<string, Record<string, unknown>>> {
  const map = new Map<string, Record<string, unknown>>();
  if (recipes.length === 0) return map;
  if (!(await sourceColumnsAvailable(admin))) return map;

  const bySource = new Map<RecipeApiSource, string[]>();
  for (const recipe of recipes) {
    const ids = bySource.get(recipe.source) ?? [];
    ids.push(recipe.source_id);
    bySource.set(recipe.source, ids);
  }

  for (const [source, sourceIds] of bySource) {
    const uniqueIds = [...new Set(sourceIds)];
    const { data, error } = await admin
      .from('recipes')
      .select(`${RECIPE_CLIENT_COLUMNS}, source, source_id`)
      .eq('source', source)
      .in('source_id', uniqueIds);

    if (error) {
      if (!isMissingColumnError(error)) {
        console.error('findCachedRecipesForSearchResults:', error);
      }
      continue;
    }

    for (const row of data ?? []) {
      const record = row as Record<string, unknown>;
      const sourceId = String(record.source_id);
      map.set(prefixedId(source, sourceId), record);
    }
  }

  return map;
}

export async function findCachedBySourceId(
  admin: SupabaseClient,
  source: string,
  sourceId: string,
): Promise<Record<string, unknown> | null> {
  if (await sourceColumnsAvailable(admin)) {
    const { data, error } = await admin
      .from('recipes')
      .select(RECIPE_CLIENT_COLUMNS)
      .eq('source', source)
      .eq('source_id', sourceId)
      .maybeSingle();

    if (error) {
      if (!isMissingColumnError(error)) console.error('findCachedBySourceId:', error);
      return null;
    }
    return data as Record<string, unknown> | null;
  }

  return null;
}

/** Insert without source columns (pre-migration 008) or when source upsert fails. */
async function persistLegacyRecipe(
  admin: SupabaseClient,
  recipe: NormalizedSearchRecipe,
  seedUserId: string,
): Promise<QuilloRecipePayload | null> {
  const quillo = normalizedToQuillo(recipe);
  const row = await normalizedToDbRow(recipe, seedUserId, false);

  const { data: existing, error: findError } = await admin
    .from('recipes')
    .select(RECIPE_CLIENT_COLUMNS)
    .eq('user_id', seedUserId)
    .eq('title', recipe.title)
    .maybeSingle();

  if (findError) {
    console.error('persistLegacyRecipe find:', findError);
  } else if (existing) {
    return {
      ...quillo,
      id: String((existing as Record<string, unknown>).id),
    };
  }

  const { data: inserted, error } = await admin
    .from('recipes')
    .insert(row)
    .select(RECIPE_CLIENT_COLUMNS)
    .single();

  if (error) {
    console.error('persistLegacyRecipe insert:', error);
    return null;
  }

  return {
    ...quillo,
    id: String((inserted as Record<string, unknown>).id),
  };
}

/** Persist one recipe; always tries legacy fallback when source upsert is unavailable. */
export async function persistSingleNormalizedRecipe(
  admin: SupabaseClient,
  recipe: NormalizedSearchRecipe,
  seedUserId: string,
): Promise<QuilloRecipePayload> {
  const [result] = await persistNormalizedResults(admin, [recipe], seedUserId);
  if (result.id) return result;

  const legacy = await persistLegacyRecipe(admin, recipe, seedUserId);
  if (legacy?.id) return legacy;

  return normalizedToQuillo(recipe);
}

function stripSourceId(row: Record<string, unknown>): Record<string, unknown> {
  const { source_id: _sid, source: _src, ...recipe } = row;
  return recipe;
}

/** Save merged search results; returns Quillo payloads (with Supabase id when saved). */
export async function persistNormalizedResults(
  admin: SupabaseClient,
  recipes: NormalizedSearchRecipe[],
  seedUserId: string,
): Promise<QuilloRecipePayload[]> {
  if (recipes.length === 0) return [];

  const outputs: QuilloRecipePayload[] = [];

  if (!(await sourceColumnsAvailable(admin))) {
    for (const recipe of recipes) {
      const legacy = await persistLegacyRecipe(admin, recipe, seedUserId);
      outputs.push(legacy ?? normalizedToQuillo(recipe));
    }
    return outputs;
  }

  for (const recipe of recipes) {
    const { data: existing } = await admin
      .from('recipes')
      .select(RECIPE_CLIENT_COLUMNS)
      .eq('source', recipe.source)
      .eq('source_id', recipe.source_id)
      .maybeSingle();

    if (existing) {
      const existingId = String((existing as Record<string, unknown>).id);
      const existingImage = (existing as Record<string, unknown>).image_url as string | undefined;
      const quillo = normalizedToQuillo(recipe);

      if (
        recipe.image_url &&
        isAppHostedRecipeImage(recipe.image_url) &&
        recipe.image_url !== existingImage
      ) {
        await admin
          .from('recipes')
          .update({ image_url: recipe.image_url })
          .eq('id', existingId);
      }

      outputs.push({ ...quillo, id: existingId });
      continue;
    }

    const row = await normalizedToDbRow(recipe, seedUserId, true);
    const { data: inserted, error } = await admin
      .from('recipes')
      .upsert(row, { onConflict: 'source,source_id' })
      .select(RECIPE_CLIENT_COLUMNS)
      .single();

    if (!error && inserted) {
      outputs.push({
        ...normalizedToQuillo(recipe),
        id: String((inserted as Record<string, unknown>).id),
      });
    } else {
      if (error) console.error('persistNormalizedResults upsert:', error);
      const legacy = await persistLegacyRecipe(admin, recipe, seedUserId);
      outputs.push(legacy?.id ? legacy : normalizedToQuillo(recipe));
    }
  }

  return outputs;
}

/** @deprecated Spoonacular-only batch persist */
export async function persistSpoonacularResults(
  admin: SupabaseClient,
  items: Array<Record<string, unknown>>,
  seedUserId: string,
  options?: { includeSteps?: boolean; includeAllIngredients?: boolean },
): Promise<Array<Record<string, unknown>>> {
  const payloads = items.map((item) =>
    spoonacularToQuillo(item, options),
  );
  return payloads as unknown as Array<Record<string, unknown>>;
}

export function mappedPayloadsWithoutDb(
  items: Array<Record<string, unknown>>,
  options?: { includeSteps?: boolean; includeAllIngredients?: boolean },
): QuilloRecipePayload[] {
  return items.map((item) => spoonacularToQuillo(item, options));
}

export type { SupabaseClient };
