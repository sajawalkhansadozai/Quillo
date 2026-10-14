// ─────────────────────────────────────────────────────────────────────────────
// Quillo — generate-recipes Edge Function
// Takes a normalised ingredient list + user preferences and calls
// Claude claude-3-5-sonnet to generate exactly 3 recipe suggestions.
// Saves all 3 to the recipes table.
//
// Secrets required (set via Supabase Dashboard → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY     — Anthropic / Claude API key (OCR + recipe generation)
//   GEMINI_API_KEY        — Gemini 3 Pro Image (Nano Banana Pro) for recipe images
//   SPOONACULAR_API_KEY   — Optional fallback when Gemini image generation fails
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  fetchGeminiRecipeImageUrlResult,
  upsertRecipeImageCache,
} from '../_shared/gemini_image.ts';
import {
  checkMonthlyScanAllowed,
  consumeMonthlyScan,
} from '../_shared/scan_quota.ts';
import { applyRecipePreferences } from '../_shared/recipe_preference_filter.ts';
import { resolveUserPreferences } from '../_shared/user_preferences.ts';
import { filterFoodIngredients } from '../_shared/non_food_filter.ts';
import type { QuilloRecipePayload } from '../_shared/recipe_types.ts';

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
  dietary_labels?: string[];
  preferred_cuisines?: string[];
  household_size?: number;
  scan_id: string;
  user_id: string;
  is_manual_entry?: boolean;
  preferences?: Record<string, unknown>;
  max_cook_time_minutes?: number;
  cooking_skill?: string;
}

function buildRecipePrompt(
  req: RecipeRequest & {
    dietary_labels: string[];
    preferred_cuisines: string[];
    household_size: number;
    max_cook_time_minutes: number;
    cooking_skill: string;
    excluded_ingredients: string[];
  },
): string {
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

  const excluded = req.excluded_ingredients.length > 0
    ? req.excluded_ingredients.join(', ')
    : 'None';

  const skill = req.cooking_skill || 'Intermediate';
  const maxMins = req.max_cook_time_minutes > 0 ? req.max_cook_time_minutes : 45;

  const skillRule = (() => {
    const s = skill.toLowerCase();
    if (s.includes('beginner')) {
      return 'User skill is Beginner — ONLY suggest easy recipes (difficulty must be "easy").';
    }
    if (s.includes('home cook') || s.includes('intermediate')) {
      return 'User skill is Home Cook / Intermediate — only easy or medium recipes (never "hard").';
    }
    return 'User skill is Advanced / Confident — easy, medium, or hard recipes are allowed.';
  })();

  return `You are a professional chef assistant for the Quillo recipe app.

Generate EXACTLY 3 distinct recipe suggestions using the ingredients below.

AVAILABLE INGREDIENTS:
${ingredientList}

USER PREFERENCES:
- Dietary restrictions (HARD — never violate): ${dietary}
- Excluded ingredients (HARD — never use): ${excluded}
- Preferred cuisines (rank these higher when possible): ${cuisines}
- Household size (servings): ${req.household_size}
- Maximum cook time (HARD ceiling): ${maxMins} minutes
- Cooking skill: ${skill}

STRICT RULES:
1. Generate EXACTLY 3 recipes — no more, no less
2. You must NEVER suggest a recipe that contains ingredients violating the dietary requirements: ${dietary}. This is a hard instruction, not a preference.
3. Never use excluded ingredients: ${excluded}
4. Every recipe cook_time_minutes MUST be ≤ ${maxMins}. Do not suggest longer recipes.
5. ${skillRule}
6. Adjust all servings to match household size (${req.household_size})
7. Prefer preferred cuisines (${cuisines}) when several options exist from these ingredients
8. Each recipe must use AT LEAST 3 of the available ingredients
9. For missing_ingredients: only include truly essential items not in the available list
10. Nutrition values are per serving estimates
11. Vary ingredient coverage across the 3 recipes (list every ingredient in ingredients_used OR missing_ingredients):
   - Recipe 1: 100% match — missing_ingredients must be []
   - Recipe 2: ~80–90% match — at most 1–2 essential missing items
   - Recipe 3: ~70–80% match — 2–4 essential missing items

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
      "fat": 14,
      "fiber": 6,
      "sodium": 680,
      "sugar": 8,
      "saturated_fat": 4,
      "cholesterol": 85,
      "potassium": 420
    }
  }
]`;
}

function ingredientMatchPercent(recipe: Record<string, unknown>): number {
  const used = Array.isArray(recipe.ingredients_used) ? recipe.ingredients_used.length : 0;
  const missing = Array.isArray(recipe.missing_ingredients) ? recipe.missing_ingredients.length : 0;
  const total = used + missing;
  if (total === 0) return 100;
  return Math.round((used / total) * 100);
}

function titleSearchCandidates(title: string): string[] {
  const words = title.trim().split(/\s+/).filter(Boolean);
  const candidates = [
    title.trim(),
    words.slice(0, 2).join(' '),
    words[0] ?? '',
  ].filter((q) => q.length > 0);
  return [...new Set(candidates)];
}

async function fetchRecipeImage(
  title: string,
  ingredientNames: string[],
  geminiKey: string | undefined,
  spoonacularKey: string | undefined,
  supabase: ReturnType<typeof createClient>,
  userId: string,
  scanId: string,
): Promise<{ url: string | null; geminiModel?: string | null }> {
  if (geminiKey) {
    const result = await fetchGeminiRecipeImageUrlResult(
      supabase,
      title,
      geminiKey,
      `generated/${userId}/${scanId}`,
      ingredientNames,
    );
    if (result.url) return { url: result.url, geminiModel: result.model ?? null };
    console.warn(`Gemini image failed for "${title}", trying Spoonacular fallback`);
  }

  if (spoonacularKey) {
    const url = await fetchSpoonacularImage(title, spoonacularKey);
    return { url, geminiModel: null };
  }

  return { url: null };
}

// ── Fetch a recipe image from Spoonacular (fallback) ──────────────────────────
async function fetchSpoonacularImage(title: string, apiKey: string): Promise<string | null> {
  for (const query of titleSearchCandidates(title)) {
    try {
      const url = new URL('https://api.spoonacular.com/recipes/complexSearch');
      url.searchParams.set('query', query);
      url.searchParams.set('number', '1');
      url.searchParams.set('addRecipeInformation', 'false');
      url.searchParams.set('apiKey', apiKey);

      const res = await fetch(url.toString(), { signal: AbortSignal.timeout(4000) });
      if (!res.ok) {
        if (res.status === 402) console.error('Spoonacular daily point quota exceeded');
        continue;
      }

      const data = await res.json() as { results?: Array<{ image?: string }> };
      const image = data.results?.[0]?.image;
      if (image) return image;
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
    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    const spoonacularKey = Deno.env.get('SPOONACULAR_API_KEY');

    if (!anthropicKey) {
      return new Response(
        JSON.stringify({ error: 'Anthropic API key not configured. Add ANTHROPIC_API_KEY to Edge Function secrets.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!geminiKey && !spoonacularKey) {
      return new Response(
        JSON.stringify({
          error: 'Recipe image API not configured. Add GEMINI_API_KEY (recommended) or SPOONACULAR_API_KEY to Edge Function secrets.',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const body = await req.json() as RecipeRequest;
    const { scan_id, user_id, is_manual_entry } = body;
    const ingredients = filterFoodIngredients(body.ingredients ?? []);

    if (!ingredients?.length || !scan_id || !user_id) {
      return new Response(
        JSON.stringify({
          error: !body.ingredients?.length
            ? 'Missing required fields: ingredients, scan_id, user_id'
            : 'No food ingredients left after filtering non-food items. Please edit the list and try again.',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Always load prefs from DB (body may supplement) — checklist 1.3
    const prefs = await resolveUserPreferences(supabase, user_id, {
      preferences: {
        ...(typeof body.preferences === 'object' && body.preferences
          ? body.preferences
          : {}),
        dietary: body.dietary_labels,
        cuisines: body.preferred_cuisines,
        household_size: body.household_size,
        max_cook_time_minutes: body.max_cook_time_minutes,
        cooking_skill: body.cooking_skill,
      },
      dietary_labels: body.dietary_labels,
      preferred_cuisines: body.preferred_cuisines,
      household_size: body.household_size,
    });

    // Manual entry: soft-check now; consume only after recipes succeed.
    if (is_manual_entry) {
      const quotaCheck = await checkMonthlyScanAllowed(supabase, user_id);
      if (!quotaCheck.allowed) {
        return new Response(
          JSON.stringify({
            error: quotaCheck.message ??
              'Monthly scan limit reached. Upgrade to Premium for unlimited scans.',
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    // ── Build prompt and call Claude ──────────────────────────────────────────
    const prompt = buildRecipePrompt({
      ingredients,
      dietary_labels: prefs.dietary,
      preferred_cuisines: prefs.cuisines,
      household_size: prefs.household_size,
      max_cook_time_minutes: prefs.max_cook_time_minutes,
      cooking_skill: prefs.cooking_skill,
      excluded_ingredients: prefs.excluded_ingredients,
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

    // Hard post-filter: reject dietary / cook-time / skill violations (checklist 1.5 / 1.7 / 2.5)
    const asPayloads: QuilloRecipePayload[] = recipes.map((r) => ({
      title: String(r.title ?? ''),
      difficulty: String(r.difficulty ?? 'medium'),
      cook_time_minutes: Number(r.cook_time_minutes ?? 0),
      servings: Number(r.servings ?? prefs.household_size),
      steps: Array.isArray(r.steps) ? r.steps as QuilloRecipePayload['steps'] : [],
      ingredients_used: Array.isArray(r.ingredients_used)
        ? r.ingredients_used as QuilloRecipePayload['ingredients_used']
        : [],
      missing_ingredients: Array.isArray(r.missing_ingredients)
        ? r.missing_ingredients as QuilloRecipePayload['missing_ingredients']
        : [],
      nutrition: (r.nutrition as QuilloRecipePayload['nutrition']) ?? {
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      },
    }));

    const compliant = applyRecipePreferences(asPayloads, prefs);
    if (compliant.length === 0) {
      console.warn('generate-recipes: all AI recipes violated hard preferences', prefs);
      return new Response(
        JSON.stringify({
          error:
            'Generated recipes did not match your dietary or cook-time preferences. Please try again.',
          preferences_applied: prefs,
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Keep original objects that passed the filter (by title match).
    const compliantTitles = new Set(compliant.map((r) => r.title.toLowerCase()));
    recipes = recipes.filter((r) =>
      compliantTitles.has(String(r.title ?? '').toLowerCase())
    );
    // Force servings to household size
    for (const r of recipes) {
      r.servings = prefs.household_size;
    }

    // Manual entry only: burn a free scan after successful generation.
    if (is_manual_entry) {
      const consumed = await consumeMonthlyScan(supabase, user_id);
      if (!consumed.allowed) {
        return new Response(
          JSON.stringify({
            error: consumed.message ??
              'Monthly scan limit reached. Upgrade to Premium for unlimited scans.',
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    // Highest ingredient match first (100% → 90% → 80% → …)
    recipes.sort((a, b) => ingredientMatchPercent(b) - ingredientMatchPercent(a));

    // ── Fetch images (Gemini 3 Pro Image, Spoonacular fallback) + save ──────
    const imageUrls = await Promise.all(
      recipes.map((recipe) => {
        const used = Array.isArray(recipe.ingredients_used)
          ? (recipe.ingredients_used as Array<{ name?: string }>).map((i) => i.name ?? '').filter(Boolean)
          : [];
        return fetchRecipeImage(
          recipe.title as string,
          used,
          geminiKey ?? undefined,
          spoonacularKey ?? undefined,
          supabase,
          user_id,
          scan_id,
        );
      }),
    );

    const savedRecipes = [];
    for (let i = 0; i < recipes.length; i++) {
      const recipe = recipes[i];
      const imageResult = imageUrls[i];
      const imageUrl = imageResult.url;

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
          is_public: true,
        })
        .select()
        .single();

      if (!saveErr && saved) {
        // 2.6: Log Gemini image against the saved recipe_id
        if (imageUrl && imageResult.geminiModel) {
          await upsertRecipeImageCache(supabase, {
            recipeId: saved.id,
            title: String(recipe.title ?? ''),
            imageUrl,
            source: 'scan',
            sourceId: scan_id,
            geminiModel: imageResult.geminiModel,
          });
        } else if (imageUrl && String(imageUrl).includes('/recipe-images/')) {
          await upsertRecipeImageCache(supabase, {
            recipeId: saved.id,
            title: String(recipe.title ?? ''),
            imageUrl,
            source: 'scan',
            sourceId: scan_id,
            geminiModel: imageResult.geminiModel ?? 'gemini_generated',
          });
        }
        savedRecipes.push({ ...recipe, id: saved.id, image_url: imageUrl });
      } else {
        savedRecipes.push({ ...recipe, image_url: imageUrl });
      }
    }

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
