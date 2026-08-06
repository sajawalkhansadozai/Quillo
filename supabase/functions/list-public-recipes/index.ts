// Browse the public recipe catalog filtered by user preferences.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { applyRecipePreferences } from '../_shared/recipe_preference_filter.ts';
import { listPublicRecipes, parseRequestBody } from '../_shared/recipe_query.ts';
import { resolveUserPreferences } from '../_shared/user_preferences.ts';

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
    const limit = Math.min(Math.max(Number(body.limit) || 100, 1), 100);
    const prefs = await resolveUserPreferences(userClient, user.id, body);

    const { data: parsed, error } = await listPublicRecipes(userClient, limit * 3);
    if (error) {
      console.error('list-public-recipes query error:', error);
      return new Response(
        JSON.stringify({ error: 'Failed to load catalog', detail: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const recipes = applyRecipePreferences(parsed, prefs, { limit });
    const forYou = applyRecipePreferences(parsed, prefs, {
      strictCuisine: true,
      limit: 12,
    });

    return new Response(
      JSON.stringify({
        recipes,
        for_you: forYou,
        preferences_applied: prefs,
        total_before_filter: parsed.length,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('list-public-recipes error:', err);
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: 'Failed to load catalog', detail: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
