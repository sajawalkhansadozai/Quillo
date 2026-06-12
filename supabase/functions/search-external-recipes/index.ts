// Explore recipe search — provider switchable for API evaluation.
//
// Set RECIPE_SEARCH_PROVIDER in Edge secrets (or pass "provider" in request body):
//   edamam | bigoven | spoonacular | edamam+bigoven | all
//
// Recipe images: Gemini 3 Pro Image (GEMINI_API_KEY), cached in recipe-images bucket.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { parseSearchProvider, searchByProvider } from '../_shared/recipe_provider.ts';
import { normalizedToQuillo } from '../_shared/recipe_types.ts';
import { persistNormalizedResults } from '../_shared/persist_recipe.ts';
import { enhanceSearchResultImages } from '../_shared/gemini_image.ts';

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

    const body = await req.json() as { query?: string; limit?: number; provider?: string };
    const query = (body.query ?? '').trim();
    const limit = Math.min(Math.max(body.limit ?? 20, 1), 30);
    const mode = parseSearchProvider(body.provider);

    if (!query) {
      return new Response(JSON.stringify({ recipes: [], provider: mode }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const search = await searchByProvider(query, limit, mode, {
      edamamAppId: Deno.env.get('EDAMAM_APP_ID') ?? undefined,
      edamamAppKey: Deno.env.get('EDAMAM_APP_KEY') ?? undefined,
      bigovenKey: Deno.env.get('BIGOVEN_API_KEY') ?? undefined,
      spoonacularKey: Deno.env.get('SPOONACULAR_API_KEY') ?? undefined,
    });

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

    let merged = search.merged;
    if (geminiKey) {
      try {
        merged = await enhanceSearchResultImages(admin, search.merged, geminiKey);
      } catch (err) {
        console.error('enhanceSearchResultImages:', err);
        warnings.push('Some images could not be enhanced — showing provider thumbnails');
      }
    }

    let recipes: ReturnType<typeof normalizedToQuillo>[];

    if (seedUserId) {
      recipes = await persistNormalizedResults(admin, merged, seedUserId);
    } else {
      recipes = merged.map(normalizedToQuillo);
      warnings.push('SEED_USER_ID not set — results not saved to database');
    }

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
