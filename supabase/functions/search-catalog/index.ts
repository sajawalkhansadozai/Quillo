// Unified catalog search: Supabase public recipes + external APIs, filtered by preferences.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  hasAnyEdamamFilter,
  hasAnySpoonacularFilter,
  mapPreferencesToEdamamFilters,
  mapPreferencesToSpoonacularFilters,
} from '../_shared/preference_filters.ts';
import {
  findCachedRecipesForSearchResults,
  persistNormalizedResults,
} from '../_shared/persist_recipe.ts';
import { applyRecipePreferences } from '../_shared/recipe_preference_filter.ts';
import { parseSearchProvider, searchByProvider } from '../_shared/recipe_provider.ts';
import {
  parseRequestBody,
  searchPublicRecipesByTitle,
} from '../_shared/recipe_query.ts';
import {
  isAppHostedRecipeImage,
  needsGeminiRecipeImage,
} from '../_shared/gemini_image.ts';
import type { QuilloRecipePayload } from '../_shared/recipe_types.ts';
import { normalizedToQuillo } from '../_shared/recipe_types.ts';
import { resolveUserPreferences } from '../_shared/user_preferences.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function titleRelevance(title: string, query: string): number {
  const t = title.trim().toLowerCase();
  const q = query.trim().toLowerCase();
  if (!t || !q) return 0;
  if (t === q) return 300;
  if (t.startsWith(q)) return 200;
  if (t.includes(q)) return 100;
  // Soft related tokens so "steak" still elevates "sirloin"/"ribeye" titles.
  const related: Record<string, string[]> = {
    steak: ['sirloin', 'ribeye', 'rib-eye', 'striploin', 'filet', 'fillet', 'beef'],
    chicken: ['poultry', 'hen'],
    pasta: ['spaghetti', 'penne', 'linguine', 'noodle'],
  };
  for (const token of related[q] ?? []) {
    if (t.includes(token)) return 60;
  }
  return 0;
}

function mergeCatalogResults(
  local: QuilloRecipePayload[],
  external: QuilloRecipePayload[],
  query: string,
  limit: number,
): QuilloRecipePayload[] {
  const seenIds = new Set<string>();
  const seenTitles = new Set<string>();
  const merged: Array<QuilloRecipePayload & { _score: number }> = [];

  const add = (recipe: QuilloRecipePayload, sourceBoost: number) => {
    if (recipe.id) {
      if (seenIds.has(recipe.id)) return;
      seenIds.add(recipe.id);
    }
    const key = recipe.title.trim().toLowerCase();
    if (!key || seenTitles.has(key)) return;
    seenTitles.add(key);
    const score = titleRelevance(recipe.title, query) + sourceBoost;
    // Drop weak ingredient-only local hits when the title is unrelated.
    if (score < 60 && sourceBoost < 50) return;
    merged.push({ ...recipe, _score: score });
  };

  // External API results get a boost so relevant Edamam hits beat noisy DB rows.
  for (const recipe of external) add(recipe, 50);
  for (const recipe of local) add(recipe, 0);

  merged.sort((a, b) => {
    if (b._score !== a._score) return b._score - a._score;
    return (a.title || '').localeCompare(b.title || '');
  });

  return merged.slice(0, limit).map(({ _score, ...recipe }) => recipe);
}

function countGeminiImages(recipes: QuilloRecipePayload[]): number {
  return recipes.filter((r) => r.image_url?.includes('/recipe-images/')).length;
}

async function searchLocalCatalog(
  client: ReturnType<typeof createClient>,
  query: string,
  limit: number,
  excludeIds: Set<string>,
): Promise<QuilloRecipePayload[]> {
  const term = query.trim();
  if (!term) return [];

  const overFetch = Math.min(limit + excludeIds.size, 100);

  const { data: rpcRows, error } = await client.rpc('search_public_recipes', {
    p_query: term,
    p_limit: overFetch,
  });

  let rows: QuilloRecipePayload[];
  if (!error && rpcRows) {
    rows = rpcRows as QuilloRecipePayload[];
  } else {
    if (error) {
      console.warn('search_public_recipes RPC failed, using title filter:', error.message);
    }
    rows = await searchPublicRecipesByTitle(client, term, overFetch);
  }

  return rows
    .filter((r) => !excludeIds.has(String(r.id ?? '')))
    .slice(0, limit);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const seedUserId = Deno.env.get('SEED_USER_ID');

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await parseRequestBody(req);
    const query = String(body.query ?? '').trim();
    const cap = Math.min(Math.max(Number(body.limit) || 50, 1), 50);
    const externalOffset = Math.max(Number(body.offset) || 0, 0);
    const excludeIds = new Set<string>(
      (Array.isArray(body.exclude_ids) ? body.exclude_ids : [])
        .map((id) => String(id).trim())
        .filter(Boolean),
    );
    const mode = parseSearchProvider(
      typeof body.provider === 'string' ? body.provider : undefined,
    );
    const prefs = await resolveUserPreferences(userClient, user.id, body);

    if (!query) {
      return new Response(JSON.stringify({ recipes: [], provider: mode }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Prefer title hits from the DB; keep a small local pool so weak ingredient
    // matches can't fill the whole page and block Edamam.
    const local = await searchLocalCatalog(
      userClient,
      query,
      Math.min(cap, 5),
      excludeIds,
    );
    const titleLocal = local.filter((r) => titleRelevance(r.title, query) >= 100);
    const localForMerge = titleLocal.length > 0 ? titleLocal : local.slice(0, 2);

    const edamamFilters = mapPreferencesToEdamamFilters(
      prefs.cuisines,
      prefs.dietary,
      prefs.max_cook_time_minutes,
    );
    const spoonacularFilters = mapPreferencesToSpoonacularFilters(
      prefs.cuisines,
      prefs.dietary,
      prefs.max_cook_time_minutes,
    );

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const cacheTerm = query.trim().toLowerCase();
    const pageStart = externalOffset + 1;
    const pageEnd = externalOffset + cap;

    // Serve from shared recipe_cache when a full page is already stored.
    if (excludeIds.size === 0) {
      const { data: cachedRows } = await admin
        .from('recipe_cache')
        .select('result_position, recipe_payload')
        .eq('search_term', cacheTerm)
        .gte('result_position', pageStart)
        .lte('result_position', pageEnd)
        .order('result_position', { ascending: true });

      if (cachedRows && cachedRows.length >= Math.min(cap, 3)) {
        const recipes = cachedRows
          .map((row) => row.recipe_payload as QuilloRecipePayload)
          .filter(Boolean);
        const filtered = applyRecipePreferences(recipes, prefs, { limit: cap });
        await admin.from('search_popularity').upsert({
          search_term: cacheTerm,
          hit_count: 1,
          last_searched_at: new Date().toISOString(),
          cached_count: cachedRows.length,
        }, { onConflict: 'search_term' });
        console.log(
          `search-catalog: cache hit q="${cacheTerm}" page=${pageStart}-${pageEnd} n=${filtered.length}`,
        );
        return new Response(
          JSON.stringify({
            recipes: filtered.length > 0 ? filtered : recipes.slice(0, cap),
            provider: mode,
            catalog_count: 0,
            external_count: filtered.length,
            gemini_image_count: countGeminiImages(filtered),
            provider_image_count: 0,
            images_pending_upgrade: 0,
            has_more: cachedRows.length >= cap,
            next_offset: externalOffset + cachedRows.length,
            from_cache: true,
            preferences_applied: prefs,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    let externalRecipes: QuilloRecipePayload[] = [];
    const warnings: string[] = [];
    let imagesPendingUpgrade = 0;
    let externalFetched = 0;
    let hasMore = false;

    // Always query the external provider for Explore text search so DB noise
    // (receipt ingredient leftovers) can't crowd out real matches.
    {
      const creds = {
        edamamAppId: Deno.env.get('EDAMAM_APP_ID') ?? undefined,
        edamamAppKey: Deno.env.get('EDAMAM_APP_KEY') ?? undefined,
        bigovenKey: Deno.env.get('BIGOVEN_API_KEY') ?? undefined,
        spoonacularKey: Deno.env.get('SPOONACULAR_API_KEY') ?? undefined,
      };
      const preferenceFilters = hasAnyEdamamFilter(edamamFilters)
        ? edamamFilters
        : undefined;
      const spoonFilters = hasAnySpoonacularFilter(spoonacularFilters)
        ? spoonacularFilters
        : undefined;

      let search = await searchByProvider(
        query,
        cap,
        mode,
        creds,
        preferenceFilters,
        externalOffset,
        spoonFilters,
      );
      warnings.push(...search.warnings);

      // Preference cuisine/health filters can over-constrain Edamam (e.g. diet AND
      // cuisine). Retry once with the raw query so Explore isn't DB-only.
      if (search.merged.length === 0 && (preferenceFilters || spoonFilters)) {
        console.warn(
          `search-catalog: ${mode} returned 0 with preference filters — retrying unfiltered for "${query}"`,
        );
        const retry = await searchByProvider(
          query,
          cap,
          mode,
          creds,
          undefined,
          externalOffset,
          undefined,
        );
        warnings.push(...retry.warnings);
        if (retry.merged.length > 0) {
          warnings.push('Relaxed preference filters to find matching recipes');
          search = retry;
        }
      }

      externalFetched = search.merged.length;
      console.log(
        `search-catalog: q="${query}" local=${localForMerge.length} external=${externalFetched} mode=${mode}`,
      );

      if (search.merged.length > 0) {
        const geminiKey = Deno.env.get('GEMINI_API_KEY');
        const cachedInDb = await findCachedRecipesForSearchResults(admin, search.merged);
        const providerMerged = search.merged
          .filter((recipe) => !excludeIds.has(recipe.id))
          .map((recipe) => {
          const dbRow = cachedInDb.get(recipe.id);
          const dbImage = dbRow?.image_url as string | undefined;
          if (dbImage && isAppHostedRecipeImage(dbImage)) {
            return { ...recipe, image_url: dbImage };
          }
          return recipe;
        });

        imagesPendingUpgrade = geminiKey
          ? providerMerged.filter((r) => needsGeminiRecipeImage(r.image_url)).length
          : 0;

        if (seedUserId) {
          externalRecipes = await persistNormalizedResults(admin, providerMerged, seedUserId);
        } else {
          externalRecipes = providerMerged.map(normalizedToQuillo);
          warnings.push('SEED_USER_ID not set — external results not saved to database');
        }

        externalRecipes = externalRecipes
          .filter((r) => !excludeIds.has(String(r.id ?? '')));
        hasMore = externalFetched >= cap;
      } else if (!creds.edamamAppId || !creds.edamamAppKey) {
        warnings.push('Edamam credentials missing — only database recipes are searchable');
      }
    }

    const merged = mergeCatalogResults(localForMerge, externalRecipes, query, cap);
    let recipes = applyRecipePreferences(merged, prefs, { limit: cap });
    // Don't let soft preference scoring wipe an otherwise successful search.
    if (recipes.length === 0 && merged.length > 0) {
      warnings.push('Preferences filtered all matches — showing unfiltered results');
      recipes = merged.slice(0, cap);
    }
    // Prefer relevance order from merge over preference reordering for text search.
    const byId = new Map(recipes.map((r) => [r.id ?? r.title, r]));
    recipes = merged
      .filter((r) => byId.has(r.id ?? r.title))
      .slice(0, cap);
    if (recipes.length === 0) recipes = [...byId.values()].slice(0, cap);

    // Persist this page into recipe_cache for all users.
    try {
      const upserts = recipes.map((recipe, index) => ({
        search_term: cacheTerm,
        result_position: externalOffset + index + 1,
        recipe_id: recipe.id ?? null,
        recipe_payload: recipe,
        cached_at: new Date().toISOString(),
      }));
      if (upserts.length > 0) {
        await admin.from('recipe_cache').upsert(upserts, {
          onConflict: 'search_term,result_position',
        });
      }
      await admin.from('search_popularity').upsert({
        search_term: cacheTerm,
        hit_count: 1,
        last_searched_at: new Date().toISOString(),
        cached_count: upserts.length,
      }, { onConflict: 'search_term' });
    } catch (cacheErr) {
      console.warn('recipe_cache write failed:', cacheErr);
    }

    const catalogCount = localForMerge.length;
    const geminiImageCount = countGeminiImages(recipes);

    return new Response(
      JSON.stringify({
        recipes,
        provider: mode,
        catalog_count: catalogCount,
        external_count: Math.max(0, recipes.length - Math.min(catalogCount, recipes.length)),
        gemini_image_count: geminiImageCount,
        provider_image_count: recipes.length - geminiImageCount,
        images_pending_upgrade: imagesPendingUpgrade,
        has_more: hasMore,
        next_offset: externalOffset + externalFetched,
        preferences_applied: prefs,
        ...(hasAnyEdamamFilter(edamamFilters) ? { applied_filters: edamamFilters } : {}),
        ...(warnings.length > 0 ? { warning: warnings.join('; ') } : {}),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('search-catalog error:', err);
    return new Response(JSON.stringify({ error: 'Search failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
