// Sync BigOven recipe ingredients to BigOven cloud grocery list.
// Secrets: BIGOVEN_API_KEY, BIGOVEN_USER_EMAIL, BIGOVEN_USER_PASSWORD
//
// Uses POST /grocerylist/recipe then GET /grocerylist (BigOven v2 API).
// Grocery list requires Basic Auth with a BigOven user account.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { syncBigOvenGroceryList } from '../_shared/bigoven.ts';

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
    const bigovenKey = Deno.env.get('BIGOVEN_API_KEY');
    const bigovenEmail = Deno.env.get('BIGOVEN_USER_EMAIL');
    const bigovenPassword = Deno.env.get('BIGOVEN_USER_PASSWORD');

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

    const body = await req.json() as { recipe_id?: string; scale?: number };
    const recipeId = (body.recipe_id ?? '').trim();
    const scale = Number(body.scale ?? 1);

    if (!recipeId) {
      return new Response(JSON.stringify({ error: 'recipe_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!bigovenKey || !bigovenEmail || !bigovenPassword) {
      return new Response(
        JSON.stringify({
          error: 'BigOven grocery sync not configured',
          hint: 'Set BIGOVEN_API_KEY, BIGOVEN_USER_EMAIL, BIGOVEN_USER_PASSWORD in Edge secrets',
        }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const items = await syncBigOvenGroceryList(
      recipeId,
      bigovenKey,
      bigovenEmail,
      bigovenPassword,
      scale,
    );

    return new Response(
      JSON.stringify({
        items: items.map((i) => ({
          name: i.name,
          amount: i.amount,
          department: i.department,
        })),
        synced: items.length,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('sync-bigoven-grocery error:', err);
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : 'Grocery sync failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
