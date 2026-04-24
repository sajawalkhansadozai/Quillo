// ─────────────────────────────────────────────────────────────────────────────
// Quillo — generate-recipes Edge Function
// Takes a normalised ingredient list + user preferences and calls
// Claude claude-3-5-sonnet to generate exactly 3 recipe suggestions.
// Saves all 3 to the recipes table.
//
// Secrets required (set via Supabase Dashboard → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY  — your Anthropic / Claude API key
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface Ingredient {
  name: string;
  quantity?: number | null;
  unit?: string | null;
}

interface RecipeRequest {
  ingredients: Ingredient[];
  dietary_labels: string[];
  preferred_cuisines: string[];
  household_size: number;
  scan_id: string;
  user_id: string;
}

function buildRecipePrompt(req: RecipeRequest): string {
  const ingredientList = req.ingredients
    .map((i) => {
      const qty = i.quantity != null ? ` — ${i.quantity}${i.unit ? ' ' + i.unit : ''}` : '';
      return `• ${i.name}${qty}`;
    })
    .join('\n');

  const dietary = req.dietary_labels.length > 0
    ? req.dietary_labels.join(', ')
    : 'None';

  const cuisines = req.preferred_cuisines.length > 0
    ? req.preferred_cuisines.join(', ')
    : 'Any';

  return `You are a professional chef AI assistant for the Quillo recipe app.

Generate EXACTLY 3 distinct recipe suggestions using the ingredients below.

AVAILABLE INGREDIENTS:
${ingredientList}

USER PREFERENCES:
- Dietary restrictions: ${dietary}
- Preferred cuisines: ${cuisines}
- Household size (servings): ${req.household_size}

STRICT RULES:
1. Generate EXACTLY 3 recipes — no more, no less
2. STRICTLY respect dietary restrictions — NEVER suggest a recipe that violates them
3. Adjust all servings to match household size (${req.household_size})
4. Each recipe must use AT LEAST 3 of the available ingredients
5. Vary difficulty: aim for at least one easy, one medium recipe
6. For missing_ingredients: only include truly essential items not in the available list
7. Nutrition values are per serving estimates

Return ONLY a valid JSON array. No markdown, no explanation, no code fences:
[
  {
    "title": "Recipe Name",
    "difficulty": "easy",
    "cook_time_minutes": 25,
    "servings": ${req.household_size},
    "steps": [
      { "order": 1, "instruction": "Detailed step description", "duration_minutes": 5 }
    ],
    "ingredients_used": [
      { "name": "Chicken Breast", "amount": "300g" }
    ],
    "missing_ingredients": [
      { "name": "Fresh Parsley", "amount": "small bunch" }
    ],
    "nutrition": {
      "calories": 450,
      "protein": 32,
      "carbs": 38,
      "fat": 14
    }
  }
]`;
}

// ── Fetch a food image from TheMealDB (free, no API key required) ─────────────
async function fetchFoodImage(title: string): Promise<string | null> {
  // Try progressively shorter queries: full title → first 2 words → first word
  const candidates = [
    title,
    title.split(' ').slice(0, 2).join(' '),
    title.split(' ')[0],
  ];

  for (const q of candidates) {
    try {
      const res = await fetch(
        `https://www.themealdb.com/api/json/v1/1/search.php?s=${encodeURIComponent(q)}`,
        { signal: AbortSignal.timeout(4000) },
      );
      if (!res.ok) continue;
      const data = await res.json();
      if (data.meals && data.meals.length > 0) {
        return `${data.meals[0].strMealThumb}/preview`; // /preview = 320px thumbnail
      }
    } catch {
      continue;
    }
  }
  return null;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY');

    if (!anthropicKey) {
      return new Response(
        JSON.stringify({ error: 'Anthropic API key not configured. Add ANTHROPIC_API_KEY to Edge Function secrets.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const body = await req.json() as RecipeRequest;
    const { ingredients, dietary_labels, preferred_cuisines, household_size, scan_id, user_id } = body;

    if (!ingredients?.length || !scan_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: ingredients, scan_id, user_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // ── Rate limit check ──────────────────────────────────────────────────────
    const today = new Date().toISOString().split('T')[0];
    const { data: usage } = await supabase
      .from('api_usage')
      .select('recipe_calls, daily_limit')
      .eq('user_id', user_id)
      .eq('date', today)
      .maybeSingle();

    if (usage && usage.recipe_calls >= usage.daily_limit) {
      return new Response(
        JSON.stringify({ error: 'Daily recipe limit reached. Upgrade to Premium for more.' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Build prompt and call Claude ──────────────────────────────────────────
    const prompt = buildRecipePrompt({
      ingredients,
      dietary_labels: dietary_labels ?? [],
      preferred_cuisines: preferred_cuisines ?? [],
      household_size: household_size ?? 2,
      scan_id,
      user_id,
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
        max_tokens: 8192,
        temperature: 0.7,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    if (!claudeRes.ok) {
      const errBody = await claudeRes.text();
      console.error('Claude error:', errBody);
      return new Response(
        JSON.stringify({ error: 'Recipe generation is taking longer than usual — tap to retry.' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const claudeData = await claudeRes.json();
    const rawText: string = claudeData.content?.[0]?.text ?? '[]';

    // ── Parse recipes ─────────────────────────────────────────────────────────
    let recipes: Record<string, unknown>[] = [];
    try {
      const cleaned = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      recipes = JSON.parse(cleaned);
      if (!Array.isArray(recipes)) recipes = [];
    } catch {
      console.error('Failed to parse recipes JSON:', rawText);
      return new Response(
        JSON.stringify({ error: 'Recipe generation is taking longer than usual — tap to retry.' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (recipes.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No recipes could be generated. Please try again.' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Fetch images + save recipes to DB ────────────────────────────────────
    const savedRecipes = [];
    for (const recipe of recipes) {
      // Fetch food image concurrently with DB insert
      const imageUrl = await fetchFoodImage(recipe.title as string);

      const { data: saved, error: saveErr } = await supabase
        .from('recipes')
        .insert({
          scan_id,
          user_id,
          title: recipe.title,
          cook_time_minutes: recipe.cook_time_minutes,
          difficulty: recipe.difficulty,
          servings: recipe.servings,
          steps: recipe.steps,
          ingredients_used: recipe.ingredients_used,
          missing_ingredients: recipe.missing_ingredients,
          nutrition: recipe.nutrition,
          image_url: imageUrl,
        })
        .select()
        .single();

      if (!saveErr && saved) {
        savedRecipes.push({ ...recipe, id: saved.id, image_url: imageUrl });
      } else {
        savedRecipes.push({ ...recipe, image_url: imageUrl });
      }
    }

    // ── Increment API usage ───────────────────────────────────────────────────
    await supabase.rpc('increment_recipe_usage', { p_user_id: user_id, p_date: today });

    return new Response(
      JSON.stringify({ recipes: savedRecipes, scan_id }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('generate-recipes error:', err);
    return new Response(
      JSON.stringify({ error: 'An unexpected error occurred. Please try again.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
