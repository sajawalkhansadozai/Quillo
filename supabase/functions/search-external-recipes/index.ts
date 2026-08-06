// Explore recipe search — provider switchable for API evaluation.
//
// Set RECIPE_SEARCH_PROVIDER in Edge secrets (or pass "provider" in request body):
//   edamam | bigoven | spoonacular | edamam+bigoven | all
//
// Recipe images: return provider thumbnails immediately. Client upgrades via
// fetch-external-recipe in the background (Gemini cached in recipe-images).

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { parseSearchProvider, searchByProvider } from '../_shared/recipe_provider.ts';
import { normalizedToQuillo } from '../_shared/recipe_types.ts';
import { applyRecipePreferences } from '../_shared/recipe_preference_filter.ts';
import {
  hasAnyEdamamFilter,
  mapPreferencesToEdamamFilters,
} from '../_shared/preference_filters.ts';
import {
  findCachedRecipesForSearchResults,
  persistNormalizedResults,
} from '../_shared/persist_recipe.ts';
import { resolveUserPreferences } from '../_shared/user_preferences.ts';
import {
  isAppHostedRecipeImage,
  needsGeminiRecipeImage,
} from '../_shared/gemini_image.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

    const body = await req.json() as {
      query?: string;
      limit?: number;
      provider?: string;
      cuisines?: string[];
      dietary?: string[];
      preferences?: Record<string, unknown>;
    };
    const query = (body.query ?? '').trim();
    const limit = Math.min(Math.max(body.limit ?? 20, 1), 30);
    const mode = parseSearchProvider(body.provider);
    const prefs = await resolveUserPreferences(userClient, user.id, body);

    if (!query) {
      return new Response(JSON.stringify({ recipes: [], provider: mode }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const edamamFilters = mapPreferencesToEdamamFilters(
      prefs.cuisines,
      prefs.dietary,
    );

    const search = await searchByProvider(query, limit, mode, {
      edamamAppId: Deno.env.get('EDAMAM_APP_ID') ?? undefined,
      edamamAppKey: Deno.env.get('EDAMAM_APP_KEY') ?? undefined,
      bigovenKey: Deno.env.get('BIGOVEN_API_KEY') ?? undefined,
      spoonacularKey: Deno.env.get('SPOONACULAR_API_KEY') ?? undefined,
    }, hasAnyEdamamFilter(edamamFilters) ? edamamFilters : undefined);

    const warnings = [...search.warnings];

    if (search.merged.length === 0) {
      return new Response(
        JSON.stringify({
          recipes: [],
          provider: mode,
          warning: warnings.join('; ') || `No results from ${mode}`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // Reuse cached AI images from DB; otherwise keep fast provider thumbnails.
    const cachedInDb = await findCachedRecipesForSearchResults(admin, search.merged);
    const merged = search.merged.map((recipe) => {
      const dbRow = cachedInDb.get(recipe.id);
      const dbImage = dbRow?.image_url as string | undefined;
      if (dbImage && isAppHostedRecipeImage(dbImage)) {
        return { ...recipe, image_url: dbImage };
      }
      return recipe;
    });

    const imagesPendingUpgrade = geminiKey
      ? merged.filter((r) => needsGeminiRecipeImage(r.image_url)).length
      : 0;

    let recipes: ReturnType<typeof normalizedToQuillo>[];

    if (seedUserId) {
      recipes = await persistNormalizedResults(admin, merged, seedUserId);
    } else {
      recipes = merged.map(normalizedToQuillo);
      warnings.push('SEED_USER_ID not set — results not saved to database');
    }

    recipes = applyRecipePreferences(recipes, prefs, { limit });

    return new Response(
      JSON.stringify({
        recipes,
        provider: mode,
        saved: recipes.filter((r) => r.id != null).length,
        sources: {
          edamam: search.edamam.length,
          bigoven: search.bigoven.length,
          spoonacular: search.spoonacular.length,
          merged: search.merged.length,
        },
        ...(hasAnyEdamamFilter(edamamFilters)
          ? { applied_filters: edamamFilters }
          : {}),
        preferences_applied: prefs,
        ...(imagesPendingUpgrade > 0
          ? { images_pending_upgrade: imagesPendingUpgrade }
          : {}),
        ...(warnings.length > 0 ? { warning: warnings.join('; ') } : {}),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('search-external-recipes error:', err);
    return new Response(JSON.stringify({ error: 'Search failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
