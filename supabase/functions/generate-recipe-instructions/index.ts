// Generate step-by-step cooking instructions via Claude when an external API
// (e.g. Edamam web recipes) only provides a source URL.
//
// Secrets: ANTHROPIC_API_KEY

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface InstructionStep {
  order: number;
  instruction: string;
  duration_minutes?: number;
}

function buildPrompt(body: {
  title: string;
  servings: number;
  cook_time_minutes: number;
  difficulty: string;
  ingredients: Array<{ name: string; amount?: string }>;
}): string {
  const ingredientList = body.ingredients
    .map((i) => {
      const amount = i.amount?.trim();
      return amount ? `• ${amount} ${i.name}` : `• ${i.name}`;
    })
    .join('\n');

  return `You are a professional chef writing clear home-cooking instructions.

Create step-by-step cooking instructions for this recipe:

TITLE: ${body.title}
SERVINGS: ${body.servings}
ESTIMATED COOK TIME: ${body.cook_time_minutes} minutes
DIFFICULTY: ${body.difficulty}

INGREDIENTS:
${ingredientList || '• (not listed)'}

RULES:
1. Return 6–12 practical steps a home cook can follow
2. Use the listed ingredients; do not invent major extra items
3. Match the stated cook time and difficulty
4. Each step should be one clear action (prep, cook, or finish)
5. Optionally include duration_minutes per step when helpful
6. Do NOT include URLs or "see original recipe" text
7. Steps should be original — inspired by the dish, not copied from a website

Return ONLY a valid JSON array. No markdown, no explanation:
[
  { "order": 1, "instruction": "...", "duration_minutes": 5 }
]`;
}

function parseSteps(rawText: string): InstructionStep[] {
  const cleaned = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
  const parsed = JSON.parse(cleaned);
  if (!Array.isArray(parsed)) return [];

  return parsed
    .map((step, index) => {
      const row = step as Record<string, unknown>;
      const instruction = String(row.instruction ?? '').trim();
      if (!instruction) return null;
      const order = Number(row.order ?? index + 1);
      const duration = row.duration_minutes != null
        ? Number(row.duration_minutes)
        : undefined;
      return {
        order: Number.isFinite(order) ? order : index + 1,
        instruction,
        ...(duration != null && Number.isFinite(duration)
          ? { duration_minutes: duration }
          : {}),
      };
    })
    .filter((s): s is InstructionStep => s != null)
    .sort((a, b) => a.order - b.order);
}

function isPlaceholderSteps(steps: unknown): boolean {
  if (!Array.isArray(steps) || steps.length === 0) return true;
  if (steps.length > 1) return false;
  const text = String((steps[0] as Record<string, unknown>)?.instruction ?? '').toLowerCase();
  return text.includes('see full instructions at') ||
    text.includes('follow the linked recipe') ||
    text.startsWith('http');
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

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!anthropicKey) {
      return new Response(JSON.stringify({ error: 'Instructions service not configured' }), {
        status: 503,
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

    const body = await req.json() as {
      recipe_id?: string;
      title?: string;
      servings?: number;
      cook_time_minutes?: number;
      difficulty?: string;
      ingredients_used?: Array<{ name: string; amount?: string }>;
      steps?: unknown;
    };

    const recipeId = body.recipe_id?.trim();
    const admin = createClient(supabaseUrl, serviceRoleKey);

    if (recipeId) {
      const { data: row, error } = await admin
        .from('recipes')
        .select('id, title, servings, cook_time_minutes, difficulty, ingredients_used, steps')
        .eq('id', recipeId)
        .maybeSingle();

      if (error || !row) {
        return new Response(JSON.stringify({ error: 'Recipe not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      if (!isPlaceholderSteps(row.steps)) {
        return new Response(JSON.stringify({ steps: row.steps, cached: true }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      body.title = String(row.title ?? body.title ?? 'Recipe');
      body.servings = Number(row.servings ?? body.servings ?? 2);
      body.cook_time_minutes = Number(row.cook_time_minutes ?? body.cook_time_minutes ?? 30);
      body.difficulty = String(row.difficulty ?? body.difficulty ?? 'medium');
      body.ingredients_used = (row.ingredients_used as Array<{ name: string; amount?: string }>) ??
        body.ingredients_used ?? [];
    }

    const title = (body.title ?? '').trim();
    if (!title) {
      return new Response(JSON.stringify({ error: 'title required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!isPlaceholderSteps(body.steps)) {
      return new Response(JSON.stringify({ steps: body.steps, cached: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const prompt = buildPrompt({
      title,
      servings: Math.max(1, Number(body.servings ?? 2)),
      cook_time_minutes: Math.max(1, Number(body.cook_time_minutes ?? 30)),
      difficulty: String(body.difficulty ?? 'medium'),
      ingredients: body.ingredients_used ?? [],
    });

    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 2048,
        temperature: 0.4,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    if (!claudeRes.ok) {
      const errBody = await claudeRes.text();
      console.error('Claude instructions error:', errBody);
      return new Response(JSON.stringify({ error: 'Could not generate instructions' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const claudeData = await claudeRes.json();
    const rawText: string = claudeData.content?.[0]?.text ?? '[]';

    let steps: InstructionStep[];
    try {
      steps = parseSteps(rawText);
    } catch {
      console.error('Failed to parse instructions JSON:', rawText);
      return new Response(JSON.stringify({ error: 'Could not parse instructions' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (steps.length === 0) {
      return new Response(JSON.stringify({ error: 'No instructions generated' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (recipeId) {
      const { error: updateError } = await admin
        .from('recipes')
        .update({ steps })
        .eq('id', recipeId);

      if (updateError) {
        console.error('Failed to cache instructions:', updateError);
      }
    }

    return new Response(JSON.stringify({ steps, generated: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('generate-recipe-instructions error:', err);
    return new Response(JSON.stringify({ error: 'Failed to generate instructions' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
