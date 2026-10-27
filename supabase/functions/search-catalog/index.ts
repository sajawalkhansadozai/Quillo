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
import { searchQueriesForApis } from '../_shared/search_normalise.ts';
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
    shrimp: ['prawn'],
    prawn: ['shrimp'],
    eggplant: ['aubergine'],
    aubergine: ['eggplant'],
  };
  for (const token of related[q] ?? []) {
    if (t.includes(token)) return 60;
  }
  // Token overlap for expanded queries ("prawn shrimp")
  for (const part of q.split(/\s+/).filter((p) => p.length >= 3)) {
    if (t.includes(part)) return 80;
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

async function searchFuzzyCache(
  admin: ReturnType<typeof createClient>,
  query: string,
  limit: number,
): Promise<QuilloRecipePayload[]> {
  const { data, error } = await admin.rpc('search_recipe_cache_fuzzy', {
    p_query: query,
    p_limit: limit,
  });
  if (error) {
    console.warn('search_recipe_cache_fuzzy failed:', error.message);
    return [];
  }
  return (data ?? [])
    .map((row: { recipe_payload?: QuilloRecipePayload }) => row.recipe_payload)
    .filter((r: QuilloRecipePayload | undefined): r is QuilloRecipePayload => !!r?.title);
}

async function recordSearchActivity(
  admin: ReturnType<typeof createClient>,
  userId: string,
  rawTerm: string,
  normalised: string,
  cachedCount: number,
): Promise<void> {
  try {
    await admin.from('user_searches').insert({
      user_id: userId,
      raw_term: rawTerm,
      normalised_term: normalised,
    });
  } catch (err) {
    console.warn('user_searches insert failed:', err);
  }
  try {
    await admin.rpc('record_search_popularity', {
      p_term: normalised,
      p_cached_count: cachedCount,
    });
  } catch (err) {
    console.warn('record_search_popularity failed:', err);
  }
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
    const rawQuery = String(body.query ?? '').trim();
    const { normalised: cacheTerm, expanded: apiQuery } = searchQueriesForApis(rawQuery);
    const query = cacheTerm;
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
    const pageStart = externalOffset + 1;
    const pageEnd = externalOffset + cap;
    const CURSOR_POSITION = 0;

    const isCursorPayload = (payload: unknown): payload is { __cursor?: boolean; next_url?: string } =>
      !!payload && typeof payload === 'object' && (payload as { __cursor?: boolean }).__cursor === true;

    const loadCachePage = async () => {
      const { data: cachedRows } = await admin
        .from('recipe_cache')
        .select('result_position, recipe_payload')
        .eq('normalised_search_term', cacheTerm)
        .gte('result_position', pageStart)
        .lte('result_position', pageEnd)
        .order('result_position', { ascending: true });

      // Fallback for rows written before normalised_search_term existed.
      if (cachedRows && cachedRows.length > 0) return cachedRows;
      const { data: legacyRows } = await admin
        .from('recipe_cache')
        .select('result_position, recipe_payload')
        .eq('search_term', cacheTerm)
        .gte('result_position', pageStart)
        .lte('result_position', pageEnd)
        .order('result_position', { ascending: true });
      return legacyRows ?? [];
    };

    const countCachedBeyond = async (afterPosition: number): Promise<number> => {
      const { count } = await admin
        .from('recipe_cache')
        .select('result_position', { count: 'exact', head: true })
        .eq('normalised_search_term', cacheTerm)
        .gt('result_position', afterPosition);
      if ((count ?? 0) > 0) return count ?? 0;
      const { count: legacyCount } = await admin
        .from('recipe_cache')
        .select('result_position', { count: 'exact', head: true })
        .eq('search_term', cacheTerm)
        .gt('result_position', afterPosition);
      return legacyCount ?? 0;
    };

    const loadEdamamCursor = async (): Promise<string | undefined> => {
      const { data } = await admin
        .from('recipe_cache')
        .select('recipe_payload')
        .eq('normalised_search_term', cacheTerm)
        .eq('result_position', CURSOR_POSITION)
        .maybeSingle();
      const payload = data?.recipe_payload;
      if (isCursorPayload(payload) && typeof payload.next_url === 'string') {
        return payload.next_url;
      }
      return undefined;
    };

    const saveEdamamCursor = async (nextUrl?: string) => {
      try {
        if (!nextUrl) {
          await admin
            .from('recipe_cache')
            .delete()
            .eq('search_term', cacheTerm)
            .eq('result_position', CURSOR_POSITION);
          return;
        }
        await admin.from('recipe_cache').upsert({
          search_term: cacheTerm,
          normalised_search_term: cacheTerm,
          recipe_title: '__edamam_cursor__',
          result_position: CURSOR_POSITION,
          recipe_id: null,
          recipe_payload: { __cursor: true, next_url: nextUrl },
          cached_at: new Date().toISOString(),
        }, { onConflict: 'search_term,result_position' });
      } catch (err) {
        console.warn('edamam cursor save failed:', err);
      }
    };

    // Always try shared recipe_cache first (including load-more with exclude_ids).
    // This is what makes the same search instant across devices.
    //
    // Important: an incomplete FIRST page (e.g. only 11 cached rows for a
    // limit of 20) must NOT be treated as done — fall through to Edamam so
    // users aren't stuck on a short stale page for minutes.
    {
      const exactRows = (await loadCachePage()).filter((row) =>
        !isCursorPayload(row.recipe_payload)
      );
      const remainingInCache = exactRows.length > 0
        ? await countCachedBeyond(pageEnd)
        : 0;
      const cursor = exactRows.length > 0 ? await loadEdamamCursor() : undefined;
      const fullPage = exactRows.length >= cap;
      const loadMorePartial = externalOffset > 0 && exactRows.length > 0;
      const knownComplete =
        exactRows.length > 0 && remainingInCache === 0 && !cursor;

      if (fullPage || loadMorePartial || (knownComplete && externalOffset > 0)) {
        const recipes = exactRows
          .map((row) => row.recipe_payload as QuilloRecipePayload)
          .filter((recipe) => {
            if (!recipe?.title) return false;
            if (recipe.id && excludeIds.has(String(recipe.id))) return false;
            return true;
          });
        const filtered = applyRecipePreferences(recipes, prefs, { limit: cap });
        const hasMore = remainingInCache > 0 || !!cursor || exactRows.length >= cap;
        await recordSearchActivity(admin, user.id, rawQuery, cacheTerm, exactRows.length);
        console.log(
          `search-catalog: cache hit q="${cacheTerm}" page=${pageStart}-${pageEnd} n=${filtered.length} more=${hasMore}`,
        );
        return new Response(
          JSON.stringify({
            recipes: filtered,
            provider: mode,
            catalog_count: 0,
            external_count: filtered.length,
            gemini_image_count: countGeminiImages(filtered),
            provider_image_count: 0,
            images_pending_upgrade: 0,
            has_more: hasMore,
            next_offset: externalOffset + exactRows.length,
            from_cache: true,
            preferences_applied: prefs,
            ...(filtered.length === 0
              ? { warning: 'No preference-compliant recipes in cache for this page' }
              : {}),
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      if (exactRows.length > 0 && externalOffset === 0 && !fullPage) {
        console.log(
          `search-catalog: partial cache q="${cacheTerm}" n=${exactRows.length}/${cap} — topping up from provider`,
        );
      }
    }

    // Fuzzy cache titles as extra local candidates (chick → chicken dishes).
    const fuzzyCached = excludeIds.size === 0
      ? await searchFuzzyCache(admin, query, Math.min(cap, 10))
      : [];
    const fuzzyLocal = fuzzyCached.filter((r) => !excludeIds.has(String(r.id ?? '')));
    const localWithFuzzy = mergeCatalogResults(
      [...localForMerge, ...fuzzyLocal],
      [],
      apiQuery,
      Math.min(cap, 8),
    );

    let externalRecipes: QuilloRecipePayload[] = [];
    const warnings: string[] = [];
    let imagesPendingUpgrade = 0;
    let externalFetched = 0;
    let hasMore = false;
    let edamamNextUrl: string | undefined;

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

      // Edamam v2 pagination needs the saved continuation URL for page 2+.
      const continueUrl = externalOffset > 0 ? await loadEdamamCursor() : undefined;
      // Pull a full provider page (up to 20) so we can cache more for other devices.
      const fetchSize = Math.min(Math.max(cap, 20), 20);

      // Use synonym-expanded query for APIs (prawn → "prawn shrimp").
      let search = await searchByProvider(
        apiQuery,
        fetchSize,
        mode,
        creds,
        preferenceFilters,
        externalOffset,
        spoonFilters,
        continueUrl,
      );
      warnings.push(...search.warnings);
      edamamNextUrl = search.edamamNextUrl;

      // Cuisine-only filters can over-constrain Edamam. Retry WITHOUT cuisine
      // but KEEP dietary + max cook time (hard constraints — never relax).
      if (search.merged.length === 0 && (preferenceFilters || spoonFilters) && externalOffset === 0) {
        const dietOnlyEdamam = mapPreferencesToEdamamFilters(
          [],
          prefs.dietary,
          prefs.max_cook_time_minutes,
        );
        const dietOnlySpoon = mapPreferencesToSpoonacularFilters(
          [],
          prefs.dietary,
          prefs.max_cook_time_minutes,
        );
        const softEdamam = hasAnyEdamamFilter(dietOnlyEdamam) ? dietOnlyEdamam : undefined;
        const softSpoon = hasAnySpoonacularFilter(dietOnlySpoon) ? dietOnlySpoon : undefined;
        if (prefs.cuisines.length > 0 && (softEdamam || softSpoon || softEdamam !== preferenceFilters)) {
          console.warn(
            `search-catalog: ${mode} returned 0 with cuisine filters — retrying with dietary+time only for "${apiQuery}"`,
          );
          const retry = await searchByProvider(
            apiQuery,
            fetchSize,
            mode,
            creds,
            softEdamam,
            0,
            softSpoon,
          );
          warnings.push(...retry.warnings);
          if (retry.merged.length > 0) {
            warnings.push('Relaxed cuisine preference filters (dietary + cook time still applied)');
            search = retry;
            edamamNextUrl = retry.edamamNextUrl;
          }
        }
      }

      externalFetched = search.merged.length;
      console.log(
        `search-catalog: q="${apiQuery}" local=${localWithFuzzy.length} external=${externalFetched} mode=${mode} offset=${externalOffset}`,
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
        hasMore = externalFetched >= fetchSize || !!edamamNextUrl;
      } else if (!creds.edamamAppId || !creds.edamamAppKey) {
        warnings.push('Edamam credentials missing — only database recipes are searchable');
      } else if (externalOffset > 0 && !continueUrl) {
        warnings.push('No more cached pages and no Edamam continuation — end of results');
        hasMore = false;
      }
    }

    // On load-more, prefer newly fetched external recipes only (local already shown).
    const merged = externalOffset > 0
      ? mergeCatalogResults([], externalRecipes, apiQuery, Math.max(externalRecipes.length, cap))
      : mergeCatalogResults(localWithFuzzy, externalRecipes, apiQuery, Math.max(externalRecipes.length, cap));
    // Hard dietary + cook-time + exclusions — never fall back to unfiltered.
    let recipes = applyRecipePreferences(merged, prefs, { limit: Math.max(merged.length, cap) });
    if (recipes.length === 0 && merged.length > 0) {
      warnings.push(
        'All matches violated dietary, cook-time, skill, or excluded-ingredient preferences',
      );
    }
    const byId = new Map(recipes.map((r) => [r.id ?? r.title, r]));
    const ranked = merged.filter((r) => byId.has(r.id ?? r.title));
    if (ranked.length === 0) ranked.push(...byId.values());

    // Persist the full fetched batch into recipe_cache for all users / devices.
    try {
      const upserts = ranked.map((recipe, index) => ({
        search_term: cacheTerm,
        normalised_search_term: cacheTerm,
        recipe_title: recipe.title ?? '',
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
      await saveEdamamCursor(edamamNextUrl);
      await recordSearchActivity(admin, user.id, rawQuery, cacheTerm, upserts.length);
    } catch (cacheErr) {
      console.warn('recipe_cache write failed:', cacheErr);
    }

    recipes = ranked.slice(0, cap);
    hasMore = hasMore || ranked.length > cap || !!edamamNextUrl;

    const catalogCount = externalOffset > 0 ? 0 : localWithFuzzy.length;
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
        has_more: hasMore && recipes.length > 0,
        next_offset: externalOffset + Math.max(ranked.length, externalFetched, recipes.length),
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
