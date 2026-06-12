// Load full recipe: Edamam (default) → BigOven fallback. Spoonacular opt-in only.
// Secrets: EDAMAM_APP_ID, EDAMAM_APP_KEY, BIGOVEN_API_KEY, SEED_USER_ID

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { fetchEdamamRecipe } from '../_shared/edamam.ts';
import { fetchBigOvenRecipe } from '../_shared/bigoven.ts';
import { fetchSpoonacularNormalized } from '../_shared/spoonacular.ts';
import { normalizedToQuillo } from '../_shared/recipe_types.ts';
import {
  findCachedBySourceId,
  persistSingleNormalizedRecipe,
} from '../_shared/persist_recipe.ts';

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
      source?: string;
      source_id?: string;
      recipe_id?: string;
    };
    const source = (body.source ?? 'edamam').trim();
    const sourceId = (body.source_id ?? '').trim();
    const recipeId = (body.recipe_id ?? '').trim();

    const admin = createClient(supabaseUrl, serviceRoleKey);

    if (recipeId) {
      const { data: row, error } = await admin
        .from('recipes')
        .select('id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url, is_public')
        .eq('id', recipeId)
        .maybeSingle();

      if (!error && row) {
        return new Response(JSON.stringify({ recipe: row }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    if (!sourceId) {
      return new Response(JSON.stringify({ error: 'source_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const cached = await findCachedBySourceId(admin, source, sourceId);
    if (cached) {
      return new Response(JSON.stringify({ recipe: cached }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let normalized = null;

    if (source === 'edamam') {
      const appId = Deno.env.get('EDAMAM_APP_ID');
      const appKey = Deno.env.get('EDAMAM_APP_KEY');
      if (appId && appKey) {
        normalized = await fetchEdamamRecipe(sourceId, appId, appKey);
      }
    } else if (source === 'bigoven') {
      const apiKey = Deno.env.get('BIGOVEN_API_KEY');
      if (apiKey) {
        normalized = await fetchBigOvenRecipe(sourceId, apiKey);
      }
    } else if (source === 'spoonacular') {
      const apiKey = Deno.env.get('SPOONACULAR_API_KEY');
      if (apiKey) {
        normalized = await fetchSpoonacularNormalized(sourceId, apiKey);
      }
    }

    if (!normalized) {
      return new Response(JSON.stringify({ error: 'Recipe not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (seedUserId) {
      const saved = await persistSingleNormalizedRecipe(admin, normalized, seedUserId);
      if (saved.id) {
        return new Response(JSON.stringify({ recipe: saved }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    return new Response(JSON.stringify({ recipe: normalizedToQuillo(normalized) }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('fetch-external-recipe error:', err);
    return new Response(JSON.stringify({ error: 'Failed to load recipe' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
