// ─────────────────────────────────────────────────────────────────────────────
// Quillo — ocr-scan Edge Function
// Receives a Supabase Storage signed URL for a receipt image, calls
// Claude claude-3-5-sonnet (Vision) to extract food items, saves results
// to the DB, and returns the ingredient list to the Flutter app.
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

const OCR_PROMPT = `You are a grocery receipt OCR assistant.

Extract ONLY food and drink items from the receipt image provided.

STRICT RULES:
- Include ONLY food/drink items: produce, meat, dairy, grains, beverages, condiments, etc.
- EXCLUDE everything else: store name, receipt number, totals, subtotals, tax/VAT lines, prices, loyalty points, barcodes, non-food items (cleaning products, cosmetics, batteries, etc.)
- Translate any French or German product names to English
- Resolve abbreviations (e.g. CHKN BRST → Chicken Breast, WHL MLK → Whole Milk, FRSH SPMN → Fresh Salmon)
- Normalise units to one of: g, kg, ml, l, piece
- If quantity is unclear, use 1 piece

Return ONLY a valid JSON array. No markdown, no explanation, no code fences:
[
  { "name": "Chicken Breast", "quantity": 500, "unit": "g" },
  { "name": "Whole Milk", "quantity": 1, "unit": "l" },
  { "name": "Garlic", "quantity": 3, "unit": "piece" }
]

If no food items found, return: []`;

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

    const { image_url, scan_id, user_id } = await req.json() as {
      image_url: string;
      scan_id: string;
      user_id: string;
    };

    if (!image_url || !scan_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: image_url, scan_id, user_id' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // ── Rate limit check ──────────────────────────────────────────────────────
    const today = new Date().toISOString().split('T')[0];
    const { data: usage } = await supabase
      .from('api_usage')
      .select('ocr_calls, daily_limit')
      .eq('user_id', user_id)
      .eq('date', today)
      .maybeSingle();

    if (usage && usage.ocr_calls >= usage.daily_limit) {
      return new Response(
        JSON.stringify({ error: 'Daily scan limit reached. Upgrade to Premium for more scans.' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Claude Vision call ────────────────────────────────────────────────────
    const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'url',
                  url: image_url,
                },
              },
              {
                type: 'text',
                text: OCR_PROMPT,
              },
            ],
          },
        ],
      }),
    });

    if (!claudeRes.ok) {
      const errBody = await claudeRes.text();
      console.error('Claude error:', errBody);
      await supabase.from('scans').update({ status: 'failed' }).eq('id', scan_id);
      return new Response(
        JSON.stringify({ error: 'Could not read your receipt — please try again in better lighting.' }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const claudeData = await claudeRes.json();
    const rawText: string = claudeData.content?.[0]?.text ?? '[]';

    // ── Parse JSON from Claude response ───────────────────────────────────────
    let ingredients: Array<{ name: string; quantity: number | null; unit: string | null }> = [];
    try {
      const cleaned = rawText.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim();
      ingredients = JSON.parse(cleaned);
      if (!Array.isArray(ingredients)) ingredients = [];
    } catch {
      console.error('Failed to parse ingredients JSON:', rawText);
      ingredients = [];
    }

    // ── Save raw OCR text + update scan status ────────────────────────────────
    await supabase
      .from('scans')
      .update({ raw_ocr_text: rawText, status: 'complete' })
      .eq('id', scan_id);

    // ── Save ingredients to DB ────────────────────────────────────────────────
    if (ingredients.length > 0) {
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
    }

    // ── Increment API usage ───────────────────────────────────────────────────
    await supabase.rpc('increment_ocr_usage', { p_user_id: user_id, p_date: today });

    return new Response(
      JSON.stringify({ ingredients, scan_id }),
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
