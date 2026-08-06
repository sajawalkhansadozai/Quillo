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
import {
  ensureGeminiRecipeImage,
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
      source?: string;
      source_id?: string;
      recipe_id?: string;
    };
    const source = (body.source ?? 'edamam').trim();
    const sourceId = (body.source_id ?? '').trim();
    const recipeId = (body.recipe_id ?? '').trim();

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const geminiKey = Deno.env.get('GEMINI_API_KEY');

    async function withGeminiImage(
      row: Record<string, unknown>,
      source?: string,
      sourceId?: string,
    ): Promise<Record<string, unknown>> {
      const imageUrl = row.image_url as string | undefined;
      if (!geminiKey || !needsGeminiRecipeImage(imageUrl)) return row;

      const ingredients = (row.ingredients_used as Array<{ name: string }> | undefined) ?? [];
      const geminiUrl = await ensureGeminiRecipeImage(admin, geminiKey, {
        title: String(row.title ?? ''),
        source: source ?? 'edamam',
        source_id: sourceId ?? '',
        image_url: imageUrl,
        ingredients,
      });

      if (!geminiUrl || geminiUrl === imageUrl) return row;

      const id = row.id as string | undefined;
      if (id) {
        await admin.from('recipes').update({ image_url: geminiUrl }).eq('id', id);
      }
      return { ...row, image_url: geminiUrl };
    }

    if (recipeId) {
      const baseSelect =
        'id, title, difficulty, cook_time_minutes, servings, steps, ingredients_used, missing_ingredients, nutrition, image_url, is_public';
      let record: Record<string, unknown> | null = null;

      const { data: withSource, error: sourceError } = await admin
        .from('recipes')
        .select(`${baseSelect}, source, source_id`)
        .eq('id', recipeId)
        .maybeSingle();

      if (!sourceError && withSource) {
        record = withSource as Record<string, unknown>;
      } else {
        const { data: withoutSource, error: baseError } = await admin
          .from('recipes')
          .select(baseSelect)
          .eq('id', recipeId)
          .maybeSingle();
        if (!baseError && withoutSource) {
          record = withoutSource as Record<string, unknown>;
        }
      }

      if (record) {
        const rowSource = (record.source as string | undefined) ?? source;
        const rowSourceId =
          (record.source_id as string | undefined) ?? sourceId ?? recipeId;
        const upgraded = await withGeminiImage(record, rowSource, rowSourceId);
        return new Response(JSON.stringify({
          recipe: {
            ...upgraded,
            external_source: upgraded.source ?? rowSource,
            external_id: upgraded.source_id ?? rowSourceId,
          },
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response(JSON.stringify({ error: 'Recipe not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!sourceId) {
      return new Response(JSON.stringify({ error: 'source_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const cached = await findCachedBySourceId(admin, source, sourceId);
    if (cached) {
      const upgraded = await withGeminiImage(cached, source, sourceId);
      return new Response(JSON.stringify({
        recipe: {
          ...upgraded,
          external_source: upgraded.source ?? source,
          external_id: upgraded.source_id ?? sourceId,
        },
      }), {
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

    if (geminiKey && needsGeminiRecipeImage(normalized.image_url)) {
      const geminiUrl = await ensureGeminiRecipeImage(admin, geminiKey, {
        title: normalized.title,
        source: normalized.source,
        source_id: normalized.source_id,
        image_url: normalized.image_url,
        ingredients: normalized.ingredients,
      });
      if (geminiUrl) normalized = { ...normalized, image_url: geminiUrl };
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
