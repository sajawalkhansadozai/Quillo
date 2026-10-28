// Unified catalog search: Supabase public recipes + external APIs, filtered by preferences.
//
// Results for a search are kept in `recipe_cache` as one ordered, de-duplicated
// stream per (provider, term, preference set). Position 0 holds the stream's
// meta row (provider cursor, exhausted flag, created time). Page N is simply
// positions offset+1..offset+limit; when the stream is too short we pull the
// next provider page and append to it. Every device searching the same term
// with the same preferences reads the same stream.

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
import {
  parseSearchProvider,
  searchByProvider,
  type SearchProviderMode,
} from '../_shared/recipe_provider.ts';
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
import type { UserRecipePreferences } from '../_shared/user_preferences.ts';
import { resolveUserPreferences } from '../_shared/user_preferences.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/** Cached streams older than this are rebuilt on the next first-page search. */
const CACHE_TTL_MS = 3 * 24 * 60 * 60 * 1000;
/** Bumping this invalidates every cached stream (old keys are never read). */
const CACHE_VERSION = 'v2';
const META_POSITION = 0;
const PROVIDER_PAGE_SIZE = 20;
/** Upper bound on provider calls per request so search stays responsive. */
const MAX_PROVIDER_CALLS = 2;

interface StreamMeta {
  __cursor: true;
  /** Provider continuation URL with credentials stripped. */
  next_url?: string;
  provider_offset: number;
  exhausted: boolean;
  created_at: string;
}

function isStreamMeta(payload: unknown): payload is StreamMeta {
  return !!payload && typeof payload === 'object' &&
    (payload as { __cursor?: boolean }).__cursor === true;
}

/** Title key used to collapse "Chicken" / "chicken!" / "Chícken" into one card. */
function titleKey(title: string | undefined): string {
  return (title ?? '')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}

function titleRelevance(title: string, query: string): number {
  const t = titleKey(title);
  const q = titleKey(query);
  if (!t || !q) return 0;
  // A title that is only the search word ("Chicken") is usually a bare,
  // low-effort entry — keep it, but rank real dishes above it.
  if (t === q) return 40;
  if (t.startsWith(q)) return 110;
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
): QuilloRecipePayload[] {
  const seenIds = new Set<string>();
  const seenTitles = new Set<string>();
  const merged: Array<QuilloRecipePayload & { _score: number; _order: number }> = [];

  const add = (recipe: QuilloRecipePayload, sourceBoost: number) => {
    if (recipe.id) {
      if (seenIds.has(recipe.id)) return;
      seenIds.add(recipe.id);
    }
    const key = titleKey(recipe.title);
    if (!key || seenTitles.has(key)) return;
    seenTitles.add(key);
    const score = titleRelevance(recipe.title, query) + sourceBoost;
    // Drop weak ingredient-only local hits when the title is unrelated.
    if (score < 60 && sourceBoost < 50) return;
    merged.push({ ...recipe, _score: score, _order: merged.length });
  };

  // External API results get a boost so relevant Edamam hits beat noisy DB rows.
  for (const recipe of external) add(recipe, 50);
  for (const recipe of local) add(recipe, 0);

  // Stable: equal scores keep the provider's own relevance order.
  merged.sort((a, b) => b._score - a._score || a._order - b._order);

  return merged.map(({ _score, _order, ...recipe }) => recipe);
}

function countGeminiImages(recipes: QuilloRecipePayload[]): number {
  return recipes.filter((r) => isAppHostedRecipeImage(r.image_url)).length;
}

async function sha1Hex(value: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** Cache key: one stream per provider + term + everything that filters results. */
async function streamKey(
  mode: SearchProviderMode,
  term: string,
  prefs: UserRecipePreferences,
): Promise<string> {
  const sorted = (values: string[] | undefined) =>
    [...(values ?? [])].map((v) => v.trim().toLowerCase()).filter(Boolean).sort();
  const prefsKey = JSON.stringify({
    d: sorted(prefs.dietary),
    c: sorted(prefs.cuisines),
    t: prefs.max_cook_time_minutes || 0,
    s: (prefs.cooking_skill ?? '').trim().toLowerCase(),
    x: sorted(prefs.excluded_ingredients),
  });
  const hash = (await sha1Hex(prefsKey)).slice(0, 12);
  return `${CACHE_VERSION}|${mode}|${term}|${hash}`;
}

/** recipe_cache is readable by every signed-in user — never store API keys there. */
function stripCredentials(url: string | undefined): string | undefined {
  if (!url) return undefined;
  try {
    const parsed = new URL(url);
    parsed.searchParams.delete('app_id');
    parsed.searchParams.delete('app_key');
    return parsed.toString();
  } catch {
    return undefined;
  }
}

function withEdamamCredentials(
  url: string | undefined,
  appId?: string,
  appKey?: string,
): string | undefined {
  if (!url || !appId || !appKey) return undefined;
  try {
    const parsed = new URL(url);
    parsed.searchParams.set('app_id', appId);
    parsed.searchParams.set('app_key', appKey);
    return parsed.toString();
  } catch {
    return undefined;
  }
}

async function searchLocalCatalog(
  client: ReturnType<typeof createClient>,
  query: string,
  limit: number,
): Promise<QuilloRecipePayload[]> {
  const term = query.trim();
  if (!term) return [];

  const { data: rpcRows, error } = await client.rpc('search_public_recipes', {
    p_query: term,
    p_limit: limit,
  });

  if (!error && rpcRows) return (rpcRows as QuilloRecipePayload[]).slice(0, limit);
  if (error) {
    console.warn('search_public_recipes RPC failed, using title filter:', error.message);
  }
  return await searchPublicRecipesByTitle(client, term, limit);
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

/** Swap expired provider image URLs for the AI image saved on the recipe row. */
async function refreshImages(
  admin: ReturnType<typeof createClient>,
  recipes: QuilloRecipePayload[],
): Promise<QuilloRecipePayload[]> {
  const ids = recipes
    .filter((r) => r.id && !isAppHostedRecipeImage(r.image_url))
    .map((r) => String(r.id))
    .filter((id) => /^[0-9a-f-]{36}$/i.test(id));
  if (ids.length === 0) return recipes;

  const { data, error } = await admin
    .from('recipes')
    .select('id, image_url')
    .in('id', ids);
  if (error) {
    console.warn('refreshImages failed:', error.message);
    return recipes;
  }
  const images = new Map<string, string>();
  for (const row of data ?? []) {
    const url = (row as { image_url?: string }).image_url;
    if (isAppHostedRecipeImage(url)) images.set(String((row as { id: string }).id), url!);
  }
  return recipes.map((r) => {
    const url = r.id ? images.get(String(r.id)) : undefined;
    return url ? { ...r, image_url: url } : r;
  });
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return jsonResponse({ error: 'Unauthorized' }, 401);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const seedUserId = Deno.env.get('SEED_USER_ID');

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) return jsonResponse({ error: 'Unauthorized' }, 401);

    const body = await parseRequestBody(req);
    const rawQuery = String(body.query ?? '').trim();
    const { normalised: cacheTerm, expanded: apiQuery } = searchQueriesForApis(rawQuery);
    const query = cacheTerm;
    const cap = Math.min(Math.max(Number(body.limit) || 50, 1), 50);
    const offset = Math.max(Math.floor(Number(body.offset) || 0), 0);
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
      return jsonResponse({
        recipes: [],
        provider: mode,
        has_more: false,
        next_offset: 0,
        warning: 'Search term has no letters or numbers',
      });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const key = await streamKey(mode, cacheTerm, prefs);
    const pageStart = offset + 1;
    const pageEnd = offset + cap;
    const warnings: string[] = [];

    // ── Load the stream's meta row and existing positions ──────────────────
    const { data: metaRow } = await admin
      .from('recipe_cache')
      .select('recipe_payload')
      .eq('search_term', key)
      .eq('result_position', META_POSITION)
      .maybeSingle();
    let meta: StreamMeta | null = isStreamMeta(metaRow?.recipe_payload)
      ? metaRow!.recipe_payload as StreamMeta
      : null;

    if (meta && offset === 0 && Date.now() - Date.parse(meta.created_at) > CACHE_TTL_MS) {
      await admin.from('recipe_cache').delete().eq('search_term', key);
      meta = null;
    }

    const { data: indexRows } = await admin
      .from('recipe_cache')
      .select('result_position, recipe_title, recipe_id')
      .eq('search_term', key)
      .gt('result_position', META_POSITION)
      .order('result_position', { ascending: true });
    const seenTitles = new Set<string>();
    const seenIds = new Set<string>();
    let lastPosition = 0;
    for (const row of indexRows ?? []) {
      const r = row as { result_position: number; recipe_title?: string; recipe_id?: string };
      const tk = titleKey(r.recipe_title);
      if (tk) seenTitles.add(tk);
      if (r.recipe_id) seenIds.add(String(r.recipe_id));
      lastPosition = Math.max(lastPosition, r.result_position);
    }
    // A meta-less stream with rows is from an interrupted fill; start over.
    if (!meta && lastPosition > 0) {
      await admin.from('recipe_cache').delete().eq('search_term', key);
      seenTitles.clear();
      seenIds.clear();
      lastPosition = 0;
    }

    // ── Top up the stream from the provider until this page is full ────────
    const creds = {
      edamamAppId: Deno.env.get('EDAMAM_APP_ID') ?? undefined,
      edamamAppKey: Deno.env.get('EDAMAM_APP_KEY') ?? undefined,
      bigovenKey: Deno.env.get('BIGOVEN_API_KEY') ?? undefined,
      spoonacularKey: Deno.env.get('SPOONACULAR_API_KEY') ?? undefined,
    };
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
    const geminiKey = Deno.env.get('GEMINI_API_KEY');

    let providerCalls = 0;
    let catalogAdded = 0;
    while (lastPosition < pageEnd && !(meta?.exhausted) && providerCalls < MAX_PROVIDER_CALLS) {
      providerCalls++;
      const isFirstFill = !meta;
      const providerOffset = meta?.provider_offset ?? 0;
      const continueUrl = withEdamamCredentials(
        meta?.next_url,
        creds.edamamAppId,
        creds.edamamAppKey,
      );

      if (!isFirstFill && mode === 'edamam' && !continueUrl) {
        meta = { ...meta!, exhausted: true };
        break;
      }

      const preferenceFilters = hasAnyEdamamFilter(edamamFilters) ? edamamFilters : undefined;
      const spoonFilters = hasAnySpoonacularFilter(spoonacularFilters)
        ? spoonacularFilters
        : undefined;

      let search = await searchByProvider(
        apiQuery,
        PROVIDER_PAGE_SIZE,
        mode,
        creds,
        preferenceFilters,
        providerOffset,
        spoonFilters,
        continueUrl,
      );
      warnings.push(...search.warnings);

      // Cuisine-only filters can over-constrain Edamam. Retry WITHOUT cuisine
      // but KEEP dietary + max cook time (hard constraints — never relax).
      if (search.merged.length === 0 && isFirstFill && prefs.cuisines.length > 0) {
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
        const retry = await searchByProvider(
          apiQuery,
          PROVIDER_PAGE_SIZE,
          mode,
          creds,
          hasAnyEdamamFilter(dietOnlyEdamam) ? dietOnlyEdamam : undefined,
          0,
          hasAnySpoonacularFilter(dietOnlySpoon) ? dietOnlySpoon : undefined,
        );
        warnings.push(...retry.warnings);
        if (retry.merged.length > 0) {
          warnings.push('Relaxed cuisine preference filters (dietary + cook time still applied)');
          search = retry;
        }
      }

      // Persist provider hits so they have stable ids and can get AI images.
      let external: QuilloRecipePayload[] = [];
      if (search.merged.length > 0) {
        const cachedInDb = await findCachedRecipesForSearchResults(admin, search.merged);
        const providerMerged = search.merged.map((recipe) => {
          const dbImage = cachedInDb.get(recipe.id)?.image_url as string | undefined;
          return dbImage && isAppHostedRecipeImage(dbImage)
            ? { ...recipe, image_url: dbImage }
            : recipe;
        });
        if (seedUserId) {
          external = await persistNormalizedResults(admin, providerMerged, seedUserId);
        } else {
          external = providerMerged.map(normalizedToQuillo);
          warnings.push('SEED_USER_ID not set — external results not saved to database');
        }
      }

      // First fill also mixes in strong title hits from our own catalog.
      let local: QuilloRecipePayload[] = [];
      if (isFirstFill) {
        const dbHits = await searchLocalCatalog(userClient, query, 10);
        const fuzzy = await searchFuzzyCache(admin, query, 10);
        local = [...dbHits, ...fuzzy].filter((r) => titleRelevance(r.title, apiQuery) >= 60);
      }

      const merged = mergeCatalogResults(local, external, apiQuery);
      // Hard dietary + cook-time + exclusions — keep merged (relevance) order.
      const allowed = new Set(
        applyRecipePreferences(merged, prefs).map((r) => r.id ?? r.title),
      );
      const fresh = merged.filter((r) => {
        if (!allowed.has(r.id ?? r.title)) return false;
        const tk = titleKey(r.title);
        if (!tk || seenTitles.has(tk)) return false;
        if (r.id && seenIds.has(String(r.id))) return false;
        seenTitles.add(tk);
        if (r.id) seenIds.add(String(r.id));
        return true;
      });
      if (merged.length > 0 && allowed.size === 0) {
        warnings.push('All matches violated dietary, cook-time, skill, or excluded-ingredient preferences');
      }

      const nextUrl = search.edamamNextUrl;
      const exhausted = search.merged.length === 0 ||
        (mode === 'edamam' && !nextUrl) ||
        ((mode === 'bigoven' || mode === 'spoonacular') &&
          search.merged.length < PROVIDER_PAGE_SIZE);

      const now = new Date().toISOString();
      const upserts = fresh.map((recipe, index) => ({
        search_term: key,
        normalised_search_term: cacheTerm,
        recipe_title: recipe.title ?? '',
        result_position: lastPosition + index + 1,
        recipe_id: recipe.id && /^[0-9a-f-]{36}$/i.test(String(recipe.id)) ? recipe.id : null,
        recipe_payload: recipe,
        cached_at: now,
      }));
      meta = {
        __cursor: true,
        next_url: stripCredentials(nextUrl),
        provider_offset: providerOffset + PROVIDER_PAGE_SIZE,
        exhausted,
        created_at: meta?.created_at ?? now,
      };
      upserts.push({
        search_term: key,
        normalised_search_term: cacheTerm,
        recipe_title: '__stream_meta__',
        result_position: META_POSITION,
        recipe_id: null,
        recipe_payload: meta as unknown as QuilloRecipePayload,
        cached_at: now,
      });
      const { error: writeError } = await admin
        .from('recipe_cache')
        .upsert(upserts, { onConflict: 'search_term,result_position' });
      if (writeError) console.warn('recipe_cache write failed:', writeError.message);

      if (isFirstFill) {
        const localIds = new Set(local.map((r) => r.id ?? r.title));
        catalogAdded = fresh.filter((r) => localIds.has(r.id ?? r.title)).length;
      }
      lastPosition += fresh.length;
      console.log(
        `search-catalog: fill q="${apiQuery}" mode=${mode} fetched=${search.merged.length} ` +
          `added=${fresh.length} stream=${lastPosition} exhausted=${exhausted}`,
      );
    }

    // ── Serve the requested page from the stream ───────────────────────────
    const { data: pageRows } = await admin
      .from('recipe_cache')
      .select('result_position, recipe_payload')
      .eq('search_term', key)
      .gte('result_position', pageStart)
      .lte('result_position', pageEnd)
      .order('result_position', { ascending: true });

    let recipes: QuilloRecipePayload[] = ((pageRows ?? []) as Array<{ recipe_payload: unknown }>)
      .map((row) => row.recipe_payload as QuilloRecipePayload)
      .filter((r) => !!r?.title && !isStreamMeta(r))
      .filter((r) => {
        if (r.id && excludeIds.has(String(r.id))) return false;
        if (r.external_source && r.external_id &&
          excludeIds.has(`${r.external_source}:${r.external_id}`)) return false;
        return true;
      });
    recipes = await refreshImages(admin, recipes);

    const hasMore = lastPosition > pageEnd || (!!meta && !meta.exhausted);
    const nextOffset = Math.max(offset, Math.min(pageEnd, lastPosition));

    if (offset === 0) {
      await recordSearchActivity(admin, user.id, rawQuery, cacheTerm, lastPosition);
    }

    const geminiImageCount = countGeminiImages(recipes);
    console.log(
      `search-catalog: q="${cacheTerm}" page=${pageStart}-${pageEnd} n=${recipes.length} ` +
        `calls=${providerCalls} more=${hasMore}`,
    );

    return jsonResponse({
      recipes,
      provider: mode,
      catalog_count: offset === 0 ? catalogAdded : 0,
      external_count: Math.max(0, recipes.length - (offset === 0 ? catalogAdded : 0)),
      gemini_image_count: geminiImageCount,
      provider_image_count: recipes.length - geminiImageCount,
      images_pending_upgrade: geminiKey
        ? recipes.filter((r) => needsGeminiRecipeImage(r.image_url)).length
        : 0,
      has_more: hasMore,
      next_offset: nextOffset,
      from_cache: providerCalls === 0,
      preferences_applied: prefs,
      ...(hasAnyEdamamFilter(edamamFilters) ? { applied_filters: edamamFilters } : {}),
      ...(recipes.length === 0 && warnings.length > 0 ? { warning: [...new Set(warnings)].join('; ') } : {}),
    });
  } catch (err) {
    console.error('search-catalog error:', err);
    return jsonResponse({ error: 'Search failed' }, 500);
  }
});
