// Generate high-quality recipe hero images via Gemini 3 Pro Image (Nano Banana Pro).

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { NormalizedSearchRecipe } from './recipe_types.ts';

const GEMINI_MODEL = 'gemini-3-pro-image';
const GEMINI_ENDPOINT =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

export function buildRecipeImagePrompt(title: string, ingredients?: string[]): string {
  const ingredientHint = ingredients?.length
    ? ` Key visible ingredients: ${ingredients.slice(0, 6).join(', ')}.`
    : '';
  return (
    `Professional appetizing food photography of "${title}".` +
    ` Shot from a 45-degree angle on a clean ceramic plate with soft natural window light, ` +
    `shallow depth of field, vibrant true-to-life colors, styled for a premium recipe app hero image.` +
    ` No text, no watermarks, no logos, no people's faces.` +
    ingredientHint
  );
}

function decodeBase64Image(data: string): Uint8Array {
  const binary = atob(data);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

export async function generateRecipeImageBase64(
  prompt: string,
  apiKey: string,
): Promise<{ bytes: Uint8Array; mimeType: string } | null> {
  try {
    const res = await fetch(GEMINI_ENDPOINT, {
      method: 'POST',
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseModalities: ['IMAGE'],
          responseFormat: {
            image: { aspectRatio: '4:3', imageSize: '2K' },
          },
        },
      }),
      signal: AbortSignal.timeout(90_000),
    });

    if (!res.ok) {
      console.error('Gemini image error:', res.status, await res.text());
      return null;
    }

    const data = await res.json() as {
      candidates?: Array<{
        content?: {
          parts?: Array<{
            thought?: boolean;
            inline_data?: { mime_type?: string; data?: string };
            inlineData?: { mimeType?: string; data?: string };
          }>;
        };
      }>;
    };

    const parts = data.candidates?.[0]?.content?.parts ?? [];
    let lastImage: { data: string; mimeType: string } | null = null;

    for (const part of parts) {
      if (part.thought) continue;
      const inline = part.inline_data ?? part.inlineData;
      if (inline?.data) {
        lastImage = {
          data: inline.data,
          mimeType: inline.mime_type ?? inline.mimeType ?? 'image/png',
        };
      }
    }

    if (!lastImage) return null;

    return {
      bytes: decodeBase64Image(lastImage.data),
      mimeType: lastImage.mimeType,
    };
  } catch (err) {
    console.error('generateRecipeImageBase64:', err);
    return null;
  }
}

export async function uploadRecipeImage(
  supabase: SupabaseClient,
  bytes: Uint8Array,
  mimeType: string,
  storagePath: string,
): Promise<string | null> {
  const ext = mimeType.includes('jpeg') || mimeType.includes('jpg') ? 'jpg' : 'png';
  const path = storagePath.endsWith(`.${ext}`) ? storagePath : `${storagePath}.${ext}`;

  const { error } = await supabase.storage
    .from('recipe-images')
    .upload(path, bytes, { contentType: mimeType, upsert: true });

  if (error) {
    console.error('uploadRecipeImage:', error);
    return null;
  }

  const { data } = supabase.storage.from('recipe-images').getPublicUrl(path);
  return data.publicUrl;
}

export function isAppHostedRecipeImage(imageUrl?: string): boolean {
  return !!imageUrl && imageUrl.includes('/recipe-images/');
}

function exploreStorageBase(source: string, sourceId: string): string {
  const safeId = sourceId.replace(/[^a-zA-Z0-9_-]/g, '_');
  return `explore/${source}/${safeId}`;
}

async function getCachedStorageImageUrl(
  supabase: SupabaseClient,
  storageBase: string,
): Promise<string | null> {
  for (const ext of ['png', 'jpg', 'webp']) {
    const path = `${storageBase}.${ext}`;
    const { data } = supabase.storage.from('recipe-images').getPublicUrl(path);
    try {
      const res = await fetch(data.publicUrl, { method: 'HEAD', signal: AbortSignal.timeout(4000) });
      if (res.ok) return data.publicUrl;
    } catch {
      continue;
    }
  }
  return null;
}

export async function fetchGeminiRecipeImageUrl(
  supabase: SupabaseClient,
  title: string,
  apiKey: string,
  storagePrefix: string,
  ingredients?: string[],
  storageBase?: string,
): Promise<string | null> {
  if (storageBase) {
    const cached = await getCachedStorageImageUrl(supabase, storageBase);
    if (cached) return cached;
  }

  const prompt = buildRecipeImagePrompt(title, ingredients);
  const generated = await generateRecipeImageBase64(prompt, apiKey);
  if (!generated) return null;

  const path = storageBase ?? `${storagePrefix}/${crypto.randomUUID()}`;
  return uploadRecipeImage(supabase, generated.bytes, generated.mimeType, path);
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  fn: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  if (items.length === 0) return [];
  const results = new Array<R>(items.length);
  let next = 0;

  async function worker(): Promise<void> {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i], i);
    }
  }

  const workers = Math.min(concurrency, items.length);
  await Promise.all(Array.from({ length: workers }, () => worker()));
  return results;
}

/** Replace external API thumbnails with Gemini images (cached in recipe-images bucket). */
export async function enhanceSearchResultImages(
  supabase: SupabaseClient,
  recipes: NormalizedSearchRecipe[],
  apiKey: string,
  options?: { maxCount?: number; concurrency?: number },
): Promise<NormalizedSearchRecipe[]> {
  const envMax = Number(Deno.env.get('GEMINI_IMAGE_MAX_PER_SEARCH') ?? '12');
  const maxCount = options?.maxCount ?? (Number.isFinite(envMax) ? envMax : 12);
  const concurrency = options?.concurrency ?? 3;

  const targets = recipes
    .slice(0, maxCount)
    .filter((r) => !isAppHostedRecipeImage(r.image_url));

  if (targets.length === 0) return recipes;

  const enhanced = await mapWithConcurrency(targets, concurrency, async (recipe) => {
    const ingredients = recipe.ingredients.map((i) => i.name).filter(Boolean);
    const storageBase = exploreStorageBase(recipe.source, recipe.source_id);
    const url = await fetchGeminiRecipeImageUrl(
      supabase,
      recipe.title,
      apiKey,
      'explore',
      ingredients,
      storageBase,
    );
    return { id: recipe.id, image_url: url ?? recipe.image_url };
  });

  const byId = new Map(enhanced.map((e) => [e.id, e.image_url]));

  return recipes.map((r) => {
    const image_url = byId.get(r.id);
    return image_url && image_url !== r.image_url ? { ...r, image_url } : r;
  });
}
