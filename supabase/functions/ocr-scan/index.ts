// ─────────────────────────────────────────────────────────────────────────────
// Quillo — ocr-scan Edge Function
// Downloads receipt image → preprocessing passes (greyscale/normalise/sharpen/
// threshold) → Claude Vision OCR → saves ingredients.
//
// Sharp cannot run on Deno Edge; ImageScript implements the same pipeline.
// Secrets: ANTHROPIC_API_KEY
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  checkMonthlyScanAllowed,
  consumeMonthlyScan,
} from '../_shared/scan_quota.ts';
import { filterFoodIngredients } from '../_shared/non_food_filter.ts';
import {
  preprocessReceipt,
  uint8ToBase64,
  type ImageMeta,
  type PreprocessPass,
} from '../_shared/receipt_preprocess.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/** Minimum food ingredients required to consume a free scan credit (§05). */
const CREDIT_THRESHOLD = 3;

const OCR_PROMPT = `You are a grocery receipt OCR assistant.

This receipt image may be faded, low contrast, or partially illegible due to thermal paper degradation. Please:
1. Extract all clearly readable food and ingredient items
2. For partially visible text, include your best interpretation in square brackets e.g. [chicken breast]
3. Ignore non-food items, prices, dates, and store information

STRICT RULES:
- Include ONLY food/drink items: produce, meat, dairy, grains, beverages, condiments, etc.
- EXCLUDE everything else: store name, receipt number, totals, subtotals, tax/VAT lines, prices, loyalty points, barcodes, non-food items (cleaning products, cosmetics, batteries, etc.)
- Translate any French or German product names to English
- Resolve abbreviations (e.g. CHKN BRST → Chicken Breast, WHL MLK → Whole Milk, FRSH SPMN → Fresh Salmon)
- Normalise units to one of: g, kg, ml, l, piece
- If quantity is unclear, use 1 piece
- Keep bracketed names when text is uncertain — do not invent items that are not on the receipt

Return ONLY a valid JSON array. No markdown, no explanation, no code fences:
[
  { "name": "Chicken Breast", "quantity": 500, "unit": "g" },
  { "name": "[Whole Milk]", "quantity": 1, "unit": "l" },
  { "name": "Garlic", "quantity": 3, "unit": "piece" }
]

If no food items found, return: []`;

const FOOD_PROMPT = `You are looking at a photo of food or ingredients on a counter, in a fridge, or in a bag. This is not a receipt.

List each distinct edible ingredient you can see.
- Include produce, meat, dairy, pantry goods, drinks, and condiments.
- Ignore plates, packaging branding, people, and non-food objects.
- Estimate a quantity when it is obvious (a few tomatoes, one bottle). Otherwise use 1 piece.
- Normalise units to one of: g, kg, ml, l, piece.
- Do not invent items that are not visible.

Return ONLY a valid JSON array. No markdown, no explanation:
[
  { "name": "Tomato", "quantity": 3, "unit": "piece" },
  { "name": "Milk", "quantity": 1, "unit": "l" }
]

If nothing edible is visible, return: []`;

type Ingredient = { name: string; quantity: number | null; unit: string | null };

function stripBrackets(name: string): string {
  return name.replace(/^\[+|\]+$/g, '').replace(/[\[\]]/g, '').trim();
}

function normaliseIngredients(raw: Ingredient[]): Ingredient[] {
  return filterFoodIngredients(
    raw
      .map((ing) => ({
        ...ing,
        name: stripBrackets(String(ing.name ?? '')),
      }))
      .filter((ing) => ing.name.length >= 2),
  );
}

function parseIngredients(rawText: string): Ingredient[] {
  try {
    const cleaned = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
    const parsed = JSON.parse(cleaned);
    if (!Array.isArray(parsed)) return [];
    return normaliseIngredients(
      parsed.map((item: unknown) => {
        if (typeof item === 'string') {
          return { name: item, quantity: 1, unit: 'piece' };
        }
        const obj = item as Record<string, unknown>;
        return {
          name: String(obj.name ?? ''),
          quantity: typeof obj.quantity === 'number' ? obj.quantity : null,
          unit: typeof obj.unit === 'string' ? obj.unit : null,
        };
      }),
    );
  } catch {
    console.error('Failed to parse ingredients JSON:', rawText);
    return [];
  }
}

async function callClaudeOcr(
  anthropicKey: string,
  jpegBase64: string,
  prompt: string,
): Promise<{ ok: true; text: string } | { ok: false; status: number; body: string }> {
  const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': anthropicKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      temperature: 0,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: 'image/jpeg',
                data: jpegBase64,
              },
            },
            {
              type: 'text',
              text: prompt,
            },
          ],
        },
      ],
    }),
  });

  if (!claudeRes.ok) {
    return { ok: false, status: claudeRes.status, body: await claudeRes.text() };
  }

  const claudeData = await claudeRes.json();
  const text: string = claudeData.content?.[0]?.text ?? '[]';
  return { ok: true, text };
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
        JSON.stringify({
          error:
            'Anthropic API key not configured. Add ANTHROPIC_API_KEY to Edge Function secrets.',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { image_url, scan_id, user_id, purpose } = await req.json() as {
      image_url: string;
      scan_id: string;
      user_id: string;
      purpose?: string;
    };
    const pantryAdd = purpose === 'pantryReceipt' || purpose === 'pantryFood';
    const prompt = purpose === 'pantryFood' ? FOOD_PROMPT : OCR_PROMPT;

    if (!image_url || !scan_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: image_url, scan_id, user_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Pantry stocking does not use the recipe scan allowance.
    // Soft gate only — failed / empty OCR must NOT burn a free scan.
    if (!pantryAdd) {
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

    // ── Download original receipt bytes ───────────────────────────────────────
    const imgRes = await fetch(image_url);
    if (!imgRes.ok) {
      await supabase.from('scans').update({ status: 'failed' }).eq('id', scan_id);
      return new Response(
        JSON.stringify({ error: 'Could not load receipt image. Please try again.' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }
    const receiptBuffer = new Uint8Array(await imgRes.arrayBuffer());

    // ── Multi-pass preprocess + OCR (§01–§02) ─────────────────────────────────
    type PassOutcome = {
      pass: PreprocessPass;
      ingredients: Ingredient[];
      rawText: string;
      meta: ImageMeta;
    };

    const outcomes: PassOutcome[] = [];
    let lastClaudeError: string | null = null;

    const passes: PreprocessPass[] = purpose === 'pantryFood'
      ? [0]
      : [0, 1, 2, 3];

    for (const pass of passes) {
      let processed: { jpeg: Uint8Array; meta: ImageMeta };
      try {
        processed = await preprocessReceipt(receiptBuffer, pass);
      } catch (preErr) {
        console.error(`preprocess pass ${pass} failed:`, preErr);
        continue;
      }

      const ocr = await callClaudeOcr(
        anthropicKey,
        uint8ToBase64(processed.jpeg),
        prompt,
      );
      if (!ocr.ok) {
        lastClaudeError = ocr.body;
        console.error(`Claude error on pass ${pass}:`, ocr.body);
        // Auth/quota errors — abort retries
        if (ocr.status === 401 || ocr.status === 403 || ocr.status === 429) break;
        continue;
      }

      const ingredients = parseIngredients(ocr.text);
      outcomes.push({
        pass,
        ingredients,
        rawText: ocr.text,
        meta: processed.meta,
      });

      // Early exit when we already have a strong result
      if (ingredients.length >= CREDIT_THRESHOLD) break;
    }

    if (outcomes.length === 0) {
      await supabase.from('scans').update({ status: 'failed' }).eq('id', scan_id);
      const apiHint = lastClaudeError?.includes('not_found') ||
          lastClaudeError?.includes('model')
        ? 'OCR service is temporarily unavailable. Please try again shortly.'
        : lastClaudeError
          ? 'Could not read your receipt — try a flat surface with even lighting, or use Upload instead.'
          : 'Could not process receipt image. Please try again.';
      return new Response(
        JSON.stringify({ error: apiHint }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Best result across passes (§2.4)
    outcomes.sort((a, b) => b.ingredients.length - a.ingredients.length);
    const best = outcomes[0];
    const ingredients = best.ingredients;
    const creditConsumed = !pantryAdd && ingredients.length >= CREDIT_THRESHOLD;
    const isPartial = ingredients.length > 0 && ingredients.length < CREDIT_THRESHOLD;

    if (ingredients.length === 0) {
      await supabase
        .from('scans')
        .update({ raw_ocr_text: best.rawText, status: 'failed' })
        .eq('id', scan_id);

      return new Response(
        JSON.stringify({
          ingredients: [],
          scan_id,
          credit_consumed: false,
          partial: true,
          best_pass: best.pass,
          meta: best.meta,
          message:
            'This scan did not use one of your credits. Try again with better lighting, or add ingredients manually.',
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (creditConsumed) {
      const consumed = await consumeMonthlyScan(supabase, user_id);
      if (!consumed.allowed) {
        await supabase.from('scans').update({ status: 'failed' }).eq('id', scan_id);
        return new Response(
          JSON.stringify({
            error: consumed.message ??
              'Monthly scan limit reached. Upgrade to Premium for unlimited scans.',
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }
    }

    // DB CHECK only allows pending|processing|complete|failed — use complete
    // whenever ingredients were saved; credit flag is returned separately.
    await supabase
      .from('scans')
      .update({ raw_ocr_text: best.rawText, status: 'complete' })
      .eq('id', scan_id);

    const rows = ingredients.map((ing) => ({
      scan_id,
      user_id,
      raw_name: ing.name,
      normalised_name: ing.name,
      quantity: ing.quantity ?? null,
      unit: ing.unit ?? null,
      user_edited: false,
    }));
    await supabase.from('ingredients').insert(rows);

    return new Response(
      JSON.stringify({
        ingredients,
        scan_id,
        credit_consumed: creditConsumed,
        partial: isPartial || !creditConsumed,
        best_pass: best.pass,
        meta: best.meta,
        message: creditConsumed
          ? undefined
          : 'We found some of your ingredients. Add any we missed below. This scan did not use one of your credits.',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('ocr-scan error:', err);
    return new Response(
      JSON.stringify({ error: 'An unexpected error occurred. Please try again.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
