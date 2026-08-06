// Fast Gemini hero image upgrade for Explore cards (no full recipe fetch).
// Secrets: GEMINI_API_KEY, GEMINI_IMAGE_MODEL (optional)

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  ensureGeminiRecipeImageResult,
  isAppHostedRecipeImage,
  isGeminiImageErrorRetriable,
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

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) {
      return new Response(JSON.stringify({ error: 'GEMINI_API_KEY not configured' }), {
        status: 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json() as {
      recipe_id?: string;
      source?: string;
      source_id?: string;
      title?: string;
      image_url?: string;
      ingredients?: Array<{ name?: string }>;
    };

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const started = Date.now();
    const recipeId = (body.recipe_id ?? '').trim();
    let title = (body.title ?? '').trim();
    let source = (body.source ?? 'edamam').trim();
    let sourceId = (body.source_id ?? '').trim();
    let imageUrl = body.image_url?.trim();
    let ingredients = (body.ingredients ?? [])
      .map((i) => ({ name: String(i.name ?? '').trim() }))
      .filter((i) => i.name.length > 0);
    let dbRecipeId: string | null = null;

    const uuidPattern =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

    if (recipeId && uuidPattern.test(recipeId)) {
      const baseSelect = 'id, title, image_url, ingredients_used';
      let row: Record<string, unknown> | null = null;

      const { data: withSource, error: sourceError } = await admin
        .from('recipes')
        .select(`${baseSelect}, source, source_id`)
        .eq('id', recipeId)
        .maybeSingle();

      if (!sourceError && withSource) {
        row = withSource as Record<string, unknown>;
      } else {
        const { data: withoutSource } = await admin
          .from('recipes')
          .select(baseSelect)
          .eq('id', recipeId)
          .maybeSingle();
        if (withoutSource) row = withoutSource as Record<string, unknown>;
      }

      if (row) {
        dbRecipeId = recipeId;
        title = String(row.title ?? title);
        const dbSource = row.source as string | undefined;
        const dbSourceId = row.source_id as string | undefined;
        if (dbSource) source = dbSource;
        if (dbSourceId) {
          sourceId = dbSourceId;
        } else {
          source = 'catalog';
          sourceId = recipeId;
        }
        imageUrl = (row.image_url as string | undefined) ?? imageUrl;
        const fromDb = (row.ingredients_used as Array<{ name?: string }> | undefined) ?? [];
        if (fromDb.length > 0) {
          ingredients = fromDb
            .map((i) => ({ name: String(i.name ?? '').trim() }))
            .filter((i) => i.name.length > 0);
        }
      }
    }

    if (!title) {
      return new Response(JSON.stringify({ error: 'title required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!sourceId && recipeId && uuidPattern.test(recipeId)) {
      source = 'catalog';
      sourceId = recipeId;
    }

    if (!sourceId) {
      return new Response(JSON.stringify({ error: 'source_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (imageUrl && isAppHostedRecipeImage(imageUrl) && !needsGeminiRecipeImage(imageUrl)) {
      // Still ensure recipe_images row exists (checklist 2.6)
      await ensureGeminiRecipeImageResult(admin, geminiKey, {
        title,
        source,
        source_id: sourceId,
        image_url: imageUrl,
        ingredients,
        recipe_id: dbRecipeId,
      });
      return new Response(JSON.stringify({ image_url: imageUrl, upgraded: false }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const geminiResult = await ensureGeminiRecipeImageResult(admin, geminiKey, {
      title,
      source,
      source_id: sourceId,
      image_url: imageUrl,
      ingredients,
      recipe_id: dbRecipeId,
    });

    if (!geminiResult.url || needsGeminiRecipeImage(geminiResult.url)) {
      const geminiError = geminiResult.error ?? 'Unknown error';
      return new Response(JSON.stringify({
        error: 'Image generation failed',
        gemini_error: geminiError,
        retriable: isGeminiImageErrorRetriable(geminiError, geminiResult.status),
        elapsed_ms: Date.now() - started,
      }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const geminiUrl = geminiResult.url;

    if (dbRecipeId && geminiUrl !== imageUrl) {
      await admin.from('recipes').update({ image_url: geminiUrl }).eq('id', dbRecipeId);
    }

    return new Response(JSON.stringify({
      image_url: geminiUrl,
      upgraded: true,
      elapsed_ms: Date.now() - started,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('upgrade-recipe-image error:', err);
    return new Response(JSON.stringify({ error: 'Upgrade failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
