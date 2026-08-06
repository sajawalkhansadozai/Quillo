// Generate recipe hero images via Gemini Flash (fast) with Pro fallback.

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { decodeBase64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';
import type { NormalizedSearchRecipe } from './recipe_types.ts';

const STABLE_FLASH_IMAGE_MODEL = 'gemini-2.5-flash-image';

/** Production-ready flash image model (Nano Banana). */
const FLASH_IMAGE_MODELS = [
  STABLE_FLASH_IMAGE_MODEL,
];

/** Per-attempt timeout. Image models can take 30–50s under load. */
const FLASH_MODEL_TIMEOUT_MS = 55_000;

// One quick retry on transient timeouts / overload (client also retries).
const RETRY_ATTEMPTS = 1;
const RETRY_DELAYS_MS: number[] = [4_000];

export interface GeminiImageSuccess {
  ok: true;
  bytes: Uint8Array;
  mimeType: string;
  model: string;
}

export interface GeminiImageFailure {
  ok: false;
  error: string;
  status?: number;
}

export type GeminiImageResult = GeminiImageSuccess | GeminiImageFailure;

export interface ImageEnhancementStats {
  attempted: number;
  succeeded: number;
  failed: number;
  lastError?: string;
}

export interface ImageEnhancementResult {
  recipes: NormalizedSearchRecipe[];
  stats: ImageEnhancementStats;
}

function geminiModels(): string[] {
  const override = Deno.env.get('GEMINI_IMAGE_MODEL')?.trim();
  if (!override || override === STABLE_FLASH_IMAGE_MODEL) {
    return [...FLASH_IMAGE_MODELS];
  }
  // Always try the stable model first — overrides like gemini-3.1 often hit capacity limits.
  return [STABLE_FLASH_IMAGE_MODEL, override];
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function isGeminiImageErrorRetriable(error: string, status?: number): boolean {
  if (status === 401 || status === 403) return false;
  if (status === 503 || status === 429 || status === 500 || status === 502) return true;
  const lower = error.toLowerCase();
  return (
    lower.includes('high demand') ||
    lower.includes('overloaded') ||
    lower.includes('try again') ||
    lower.includes('timed out') ||
    lower.includes('timeout') ||
    lower.includes('signal') ||
    lower.includes('resource exhausted')
  );
}

function isRetriableGeminiError(status: number, message: string): boolean {
  return isGeminiImageErrorRetriable(message, status);
}

function geminiEndpoint(model: string): string {
  return `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
}

function parseGeminiError(body: string, status: number): string {
  try {
    const data = JSON.parse(body) as { error?: { message?: string } };
    const message = data.error?.message?.trim();
    if (message) return message;
  } catch {
    // ignore
  }
  return `Gemini HTTP ${status}`;
}

function isFlashImageModel(model: string): boolean {
  return model.includes('flash-image');
}

function generationConfigForModel(model: string): Record<string, unknown> {
  // Gemini image models require TEXT+IMAGE modalities (IMAGE-only hangs/fails).
  const config: Record<string, unknown> = {
    responseModalities: ['TEXT', 'IMAGE'],
  };

  config.imageConfig = {
    aspectRatio: '4:3',
  };

  return config;
}

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
  return decodeBase64(data);
}

type GeminiImageResponse = {
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

export async function generateRecipeImageBase64(
  prompt: string,
  apiKey: string,
): Promise<GeminiImageResult> {
  const models = geminiModels();
  let lastError = 'Gemini image generation failed';
  let lastStatus: number | undefined;
  const started = Date.now();
  // Allow two flash attempts (55s each) plus retry delay.
  const WALL_BUDGET_MS = 120_000;

  for (const model of models) {
    if (Date.now() - started > WALL_BUDGET_MS) {
      console.warn(`Gemini: skipping ${model} — wall budget exceeded`);
      break;
    }
    const timeoutMs = isFlashImageModel(model) ? FLASH_MODEL_TIMEOUT_MS : 55_000;

    for (let attempt = 0; attempt <= RETRY_ATTEMPTS; attempt++) {
      if (attempt > 0) {
        const delay = RETRY_DELAYS_MS[attempt - 1] ?? 5_000;
        console.log(`Gemini (${model}) retry ${attempt}/${RETRY_ATTEMPTS} after ${delay}ms`);
        await sleep(delay);
      }

      const modelStart = Date.now();
      try {
        const res = await fetch(geminiEndpoint(model), {
          method: 'POST',
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: generationConfigForModel(model),
          }),
          signal: AbortSignal.timeout(timeoutMs),
        });

        const elapsed = Date.now() - modelStart;

        if (!res.ok) {
          const text = await res.text();
          lastError = parseGeminiError(text, res.status);
          lastStatus = res.status;
          console.error(`Gemini image error (${model}, ${elapsed}ms):`, res.status, text.slice(0, 200));
          if (res.status === 401 || res.status === 403) {
            return { ok: false, error: lastError, status: res.status };
          }
          if (isRetriableGeminiError(res.status, lastError) && attempt < RETRY_ATTEMPTS) {
            continue;
          }
          break;
        }

        const data = await res.json() as GeminiImageResponse;

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

        if (!lastImage) {
          lastError = `Gemini (${model}) returned no image data`;
          console.warn(`Gemini (${model}, ${elapsed}ms): no image in response`, JSON.stringify(data).slice(0, 300));
          if (attempt < RETRY_ATTEMPTS) continue;
          break;
        }

        console.log(`Gemini image ok (${model}, ${elapsed}ms, total ${Date.now() - started}ms)`);
        return {
          ok: true,
          bytes: decodeBase64Image(lastImage.data),
          mimeType: lastImage.mimeType,
          model,
        };
      } catch (err) {
        const elapsed = Date.now() - modelStart;
        lastError = err instanceof Error ? err.message : String(err);
        console.error(`generateRecipeImageBase64 (${model}, ${elapsed}ms):`, lastError);
        if (isRetriableGeminiError(0, lastError) && attempt < RETRY_ATTEMPTS) {
          continue;
        }
        break;
      }
    }
  }

  console.error(`Gemini image failed after ${Date.now() - started}ms: ${lastError}`);
  return { ok: false, error: lastError, status: lastStatus };
}

export async function uploadRecipeImage(
  supabase: SupabaseClient,
  bytes: Uint8Array,
  mimeType: string,
  storagePath: string,
): Promise<string | null> {
  const compressed = await compressRecipeImage(bytes, mimeType);
  const ext = compressed.mimeType.includes('webp')
    ? 'webp'
    : compressed.mimeType.includes('jpeg') || compressed.mimeType.includes('jpg')
    ? 'jpg'
    : 'png';
  const path = storagePath.endsWith(`.${ext}`)
    ? storagePath.replace(/\.(png|jpe?g|webp)$/i, `.${ext}`)
    : `${storagePath}.${ext}`;

  const { error } = await supabase.storage
    .from('recipe-images')
    .upload(path, compressed.bytes, {
      contentType: compressed.mimeType,
      upsert: true,
    });

  if (error) {
    console.error('uploadRecipeImage:', error);
    return null;
  }

  const { data } = supabase.storage.from('recipe-images').getPublicUrl(path);
  return data.publicUrl;
}

/** Compress to WebP ~85% quality under 200KB; fall back to JPEG then original. */
async function compressRecipeImage(
  bytes: Uint8Array,
  mimeType: string,
): Promise<{ bytes: Uint8Array; mimeType: string }> {
  const MAX_BYTES = 200_000;
  if (mimeType.includes('webp') && bytes.byteLength <= MAX_BYTES) {
    return { bytes, mimeType: 'image/webp' };
  }
  try {
    const { Image } = await import('https://deno.land/x/imagescript@1.3.0/mod.ts');
    let image = await Image.decode(bytes);

    const tryEncode = async (
      img: InstanceType<typeof Image>,
      quality: number,
    ): Promise<{ bytes: Uint8Array; mimeType: string } | null> => {
      try {
        const webp = await img.encodeWEBP(quality);
        if (webp.byteLength > 0) return { bytes: webp, mimeType: 'image/webp' };
      } catch {
        // fall through to JPEG
      }
      try {
        const jpeg = await img.encodeJPEG(quality);
        if (jpeg.byteLength > 0) return { bytes: jpeg, mimeType: 'image/jpeg' };
      } catch {
        // ignore
      }
      return null;
    };

    // Progressively shrink + lower quality until under 200KB.
    const qualities = [85, 75, 65, 55];
    const scales = [1, 0.85, 0.7, 0.55];
    let best: { bytes: Uint8Array; mimeType: string } | null = null;

    for (const scale of scales) {
      const w = Math.max(320, Math.round(image.width * scale));
      const h = Math.max(240, Math.round(image.height * scale));
      const resized = scale === 1 ? image : image.resize(w, h);
      for (const quality of qualities) {
        const encoded = await tryEncode(resized, quality);
        if (!encoded) continue;
        if (!best || encoded.bytes.byteLength < best.bytes.byteLength) {
          best = encoded;
        }
        if (encoded.bytes.byteLength <= MAX_BYTES) {
          console.log(
            `compressRecipeImage: ok ${bytes.byteLength}→${encoded.bytes.byteLength} ` +
              `(${encoded.mimeType}, q=${quality}, scale=${scale})`,
          );
          return encoded;
        }
      }
      image = resized;
    }

    if (best) {
      console.warn(
        `compressRecipeImage: best effort ${best.bytes.byteLength} bytes (over ${MAX_BYTES})`,
      );
      return best;
    }
  } catch (err) {
    console.warn('compressRecipeImage failed, keeping original:', err);
  }
  return { bytes, mimeType };
}

export async function lookupRecipeImageCache(
  supabase: SupabaseClient,
  opts: {
    recipeId?: string | null;
    source?: string | null;
    sourceId?: string | null;
    title?: string | null;
  },
): Promise<string | null> {
  const isReadyUrl = (url: unknown, status?: unknown) => {
    if (typeof url !== 'string' || !url || url.startsWith('pending://')) return false;
    if (status === 'generating') return false;
    return true;
  };

  if (opts.recipeId) {
    const { data } = await supabase
      .from('recipe_images')
      .select('image_url, status')
      .eq('recipe_id', opts.recipeId)
      .maybeSingle();
    if (data && isReadyUrl(data.image_url, data.status)) return data.image_url as string;
  }
  if (opts.source && opts.sourceId) {
    const { data } = await supabase
      .from('recipe_images')
      .select('image_url, status')
      .eq('source', opts.source)
      .eq('source_id', opts.sourceId)
      .maybeSingle();
    if (data && isReadyUrl(data.image_url, data.status)) return data.image_url as string;
  }
  return null;
}

const PENDING_URL = 'pending://generating';

/** Returns true if this caller owns generation; false if another worker holds the lock. */
async function claimImageGenerationLock(
  supabase: SupabaseClient,
  opts: {
    recipeId?: string | null;
    source?: string | null;
    sourceId?: string | null;
    title: string;
  },
): Promise<boolean> {
  const base = {
    recipe_title: opts.title,
    image_url: PENDING_URL,
    image_source: 'gemini_generated',
    status: 'generating',
    source: opts.source ?? null,
    source_id: opts.sourceId ?? null,
    updated_at: new Date().toISOString(),
  };

  try {
    if (opts.recipeId) {
      const { data: existing } = await supabase
        .from('recipe_images')
        .select('id, status, image_url, updated_at')
        .eq('recipe_id', opts.recipeId)
        .maybeSingle();
      if (existing && existing.status === 'ready' && !String(existing.image_url).startsWith('pending://')) {
        return false;
      }
      if (existing?.status === 'generating') {
        const updatedAt = Date.parse(String(existing.updated_at ?? '')) || 0;
        // Stale lock (>2 min) can be stolen.
        if (updatedAt && Date.now() - updatedAt < 120_000) return false;
      }
      const { error } = await supabase.from('recipe_images').upsert(
        { ...base, recipe_id: opts.recipeId },
        { onConflict: 'recipe_id' },
      );
      return !error;
    }

    if (opts.source && opts.sourceId) {
      const { data: existing } = await supabase
        .from('recipe_images')
        .select('id, status, image_url, updated_at')
        .eq('source', opts.source)
        .eq('source_id', opts.sourceId)
        .maybeSingle();
      if (existing && existing.status === 'ready' && !String(existing.image_url).startsWith('pending://')) {
        return false;
      }
      if (existing?.status === 'generating') {
        const updatedAt = Date.parse(String(existing.updated_at ?? '')) || 0;
        if (updatedAt && Date.now() - updatedAt < 120_000) return false;
      }
      if (existing?.id) {
        const { error } = await supabase
          .from('recipe_images')
          .update(base)
          .eq('id', existing.id)
          .eq('status', existing.status ?? 'ready');
        return !error;
      }
      const { error } = await supabase.from('recipe_images').insert(base);
      return !error;
    }
  } catch (err) {
    console.warn('claimImageGenerationLock:', err);
  }
  // No key to lock on — allow generation.
  return true;
}

async function waitForCachedImage(
  supabase: SupabaseClient,
  opts: {
    recipeId?: string | null;
    source?: string | null;
    sourceId?: string | null;
  },
  timeoutMs = 55_000,
): Promise<string | null> {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const url = await lookupRecipeImageCache(supabase, opts);
    if (url) return url;
    await new Promise((r) => setTimeout(r, 2000));
  }
  return null;
}

const PLACEHOLDER_GEMINI_MODELS = new Set([
  'storage_cache',
  'existing_hosted',
  'recipe_images_cache',
  'waited_lock',
  'backfill_existing',
  'backfill_unknown',
  'gemini_generated',
]);

function isPlaceholderGeminiModel(model?: string | null): boolean {
  if (!model) return true;
  return PLACEHOLDER_GEMINI_MODELS.has(model);
}

export async function upsertRecipeImageCache(
  supabase: SupabaseClient,
  row: {
    recipeId?: string | null;
    title: string;
    imageUrl: string;
    prompt?: string;
    storagePath?: string;
    source?: string | null;
    sourceId?: string | null;
    geminiModel?: string | null;
    generatedAt?: string | null;
  },
): Promise<void> {
  if (!row.imageUrl || row.imageUrl.startsWith('pending://')) return;

  const now = new Date().toISOString();
  const payload: Record<string, unknown> = {
    recipe_title: row.title,
    image_url: row.imageUrl,
    image_source: 'gemini_generated',
    generation_prompt: row.prompt ?? null,
    storage_path: row.storagePath ?? null,
    source: row.source ?? null,
    source_id: row.sourceId ?? null,
    gemini_model: row.geminiModel ?? null,
    generated_at: row.generatedAt ?? now,
    status: 'ready',
    updated_at: now,
  };
  if (row.recipeId) payload.recipe_id = row.recipeId;

  try {
    if (row.recipeId) {
      const { data: existing } = await supabase
        .from('recipe_images')
        .select('id, gemini_model, generated_at')
        .eq('recipe_id', row.recipeId)
        .maybeSingle();
      if (existing?.gemini_model && isPlaceholderGeminiModel(row.geminiModel)) {
        payload.gemini_model = existing.gemini_model;
      }
      if (existing?.generated_at && isPlaceholderGeminiModel(row.geminiModel)) {
        payload.generated_at = existing.generated_at;
      }
      const { error } = await supabase
        .from('recipe_images')
        .upsert(payload, { onConflict: 'recipe_id' });
      if (error) console.warn('upsertRecipeImageCache recipe_id:', error.message);
      return;
    }
    if (row.source && row.sourceId) {
      const { data: existing } = await supabase
        .from('recipe_images')
        .select('id, gemini_model, generated_at')
        .eq('source', row.source)
        .eq('source_id', row.sourceId)
        .maybeSingle();
      if (existing?.gemini_model && isPlaceholderGeminiModel(row.geminiModel)) {
        payload.gemini_model = existing.gemini_model;
      }
      if (existing?.generated_at && isPlaceholderGeminiModel(row.geminiModel)) {
        payload.generated_at = existing.generated_at;
      }
      if (existing?.id) {
        await supabase.from('recipe_images').update(payload).eq('id', existing.id);
      } else {
        await supabase.from('recipe_images').insert(payload);
      }
    }
  } catch (err) {
    console.warn('upsertRecipeImageCache:', err);
  }
}

export function isAppHostedRecipeImage(imageUrl?: string): boolean {
  return !!imageUrl && imageUrl.includes('/recipe-images/');
}

/** True when the image is missing or still hosted by an external recipe API. */
export function needsGeminiRecipeImage(imageUrl?: string): boolean {
  if (!imageUrl || !isAppHostedRecipeImage(imageUrl)) return true;
  return false;
}

export async function ensureGeminiRecipeImage(
  supabase: SupabaseClient,
  apiKey: string,
  recipe: {
    title: string;
    source: string;
    source_id: string;
    image_url?: string;
    ingredients?: Array<{ name: string }>;
  },
): Promise<string | null> {
  const result = await ensureGeminiRecipeImageResult(supabase, apiKey, recipe);
  return result.url;
}

export async function ensureGeminiRecipeImageResult(
  supabase: SupabaseClient,
  apiKey: string,
  recipe: {
    title: string;
    source: string;
    source_id: string;
    image_url?: string;
    ingredients?: Array<{ name: string }>;
    recipe_id?: string | null;
  },
): Promise<{ url: string | null; error?: string; status?: number; model?: string }> {
  // Already app-hosted: still ensure a recipe_images row exists (2.6 logging).
  if (!needsGeminiRecipeImage(recipe.image_url) && recipe.image_url) {
    const existing = await lookupRecipeImageCache(supabase, {
      recipeId: recipe.recipe_id,
      source: recipe.source,
      sourceId: recipe.source_id,
      title: recipe.title,
    });
    if (!existing) {
      await upsertRecipeImageCache(supabase, {
        recipeId: recipe.recipe_id,
        title: recipe.title,
        imageUrl: recipe.image_url,
        source: recipe.source,
        sourceId: recipe.source_id,
        geminiModel: 'existing_hosted',
      });
    } else if (recipe.recipe_id) {
      // Attach recipe_id if cache was keyed only by source/title.
      await upsertRecipeImageCache(supabase, {
        recipeId: recipe.recipe_id,
        title: recipe.title,
        imageUrl: recipe.image_url,
        source: recipe.source,
        sourceId: recipe.source_id,
        geminiModel: 'existing_hosted',
      });
    }
    return { url: recipe.image_url, model: 'existing_hosted' };
  }

  const cachedRow = await lookupRecipeImageCache(supabase, {
    recipeId: recipe.recipe_id,
    source: recipe.source,
    sourceId: recipe.source_id,
    title: recipe.title,
  });
  if (cachedRow) {
    console.log(`recipe_images cache hit for "${recipe.title}"`);
    // Re-upsert so recipe_id is attached if this call has one and prior row did not.
    if (recipe.recipe_id) {
      await upsertRecipeImageCache(supabase, {
        recipeId: recipe.recipe_id,
        title: recipe.title,
        imageUrl: cachedRow,
        source: recipe.source,
        sourceId: recipe.source_id,
        geminiModel: 'recipe_images_cache',
      });
    }
    return { url: cachedRow, model: 'recipe_images_cache' };
  }

  const ownsLock = await claimImageGenerationLock(supabase, {
    recipeId: recipe.recipe_id,
    source: recipe.source,
    sourceId: recipe.source_id,
    title: recipe.title,
  });
  if (!ownsLock) {
    console.log(`recipe_images lock held — waiting for "${recipe.title}"`);
    const waited = await waitForCachedImage(supabase, {
      recipeId: recipe.recipe_id,
      source: recipe.source,
      sourceId: recipe.source_id,
    });
    if (waited) return { url: waited, model: 'waited_lock' };
  }

  const ingredients = recipe.ingredients?.map((i) => i.name).filter(Boolean);
  const storageBase = await exploreStorageBase(recipe.source, recipe.source_id, recipe.title);
  const result = await fetchGeminiRecipeImageUrlResult(
    supabase,
    recipe.title,
    apiKey,
    'explore',
    ingredients,
    storageBase,
  );

  if (result.url) {
    await upsertRecipeImageCache(supabase, {
      recipeId: recipe.recipe_id,
      title: recipe.title,
      imageUrl: result.url,
      prompt: buildRecipeImagePrompt(recipe.title, ingredients),
      storagePath: storageBase,
      source: recipe.source,
      sourceId: recipe.source_id,
      geminiModel: result.model ?? null,
    });
  }

  return result;
}

async function hashTitleKey(title: string): Promise<string> {
  const hash = await crypto.subtle.digest(
    'SHA-1',
    new TextEncoder().encode(title.toLowerCase().trim()),
  );
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 12);
}

/** Unique per provider id AND recipe title (prevents cross-recipe image reuse). */
async function exploreStorageBase(
  source: string,
  sourceId: string,
  title: string,
): Promise<string> {
  const safeSource = source.replace(/[^a-zA-Z0-9_-]/g, '_') || 'unknown';
  const safeId = (sourceId || 'unknown').replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 80);
  const titleKey = await hashTitleKey(title);
  return `explore/v2/${safeSource}/${safeId}_${titleKey}`;
}

async function getCachedStorageImageUrl(
  supabase: SupabaseClient,
  storageBase: string,
): Promise<string | null> {
  const slash = storageBase.lastIndexOf('/');
  const dir = slash >= 0 ? storageBase.slice(0, slash) : '';
  const prefix = slash >= 0 ? storageBase.slice(slash + 1) : storageBase;

  const { data: files, error } = await supabase.storage
    .from('recipe-images')
    .list(dir, { limit: 20, search: prefix });

  if (error || !files?.length) return null;

  const hit = files.find((f) =>
    f.name.startsWith(prefix) &&
    (f.name.endsWith('.png') || f.name.endsWith('.jpg') || f.name.endsWith('.webp'))
  );
  if (!hit) return null;

  const path = dir ? `${dir}/${hit.name}` : hit.name;
  const { data } = supabase.storage.from('recipe-images').getPublicUrl(path);
  return data.publicUrl;
}

export async function fetchGeminiRecipeImageUrl(
  supabase: SupabaseClient,
  title: string,
  apiKey: string,
  storagePrefix: string,
  ingredients?: string[],
  storageBase?: string,
): Promise<string | null> {
  const result = await fetchGeminiRecipeImageUrlResult(
    supabase,
    title,
    apiKey,
    storagePrefix,
    ingredients,
    storageBase,
  );
  return result.url;
}

export async function fetchGeminiRecipeImageUrlResult(
  supabase: SupabaseClient,
  title: string,
  apiKey: string,
  storagePrefix: string,
  ingredients?: string[],
  storageBase?: string,
): Promise<{ url: string | null; error?: string; status?: number; model?: string }> {
  if (storageBase) {
    const cached = await getCachedStorageImageUrl(supabase, storageBase);
    if (cached) return { url: cached, model: 'storage_cache' };
  }

  const prompt = buildRecipeImagePrompt(title, ingredients);
  const generated = await generateRecipeImageBase64(prompt, apiKey);
  if (!generated.ok) {
    return { url: null, error: generated.error, status: generated.status };
  }

  const path = storageBase ?? `${storagePrefix}/${crypto.randomUUID()}`;
  const url = await uploadRecipeImage(supabase, generated.bytes, generated.mimeType, path);
  if (!url) return { url: null, error: 'Failed to upload image to storage' };
  return { url, model: generated.model };
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
  options?: { maxCount?: number; concurrency?: number; enhanceAll?: boolean },
): Promise<ImageEnhancementResult> {
  const envMax = Number(Deno.env.get('GEMINI_IMAGE_MAX_PER_SEARCH') ?? '5');
  const maxCount = options?.enhanceAll
    ? recipes.length
    : (options?.maxCount ?? (Number.isFinite(envMax) ? envMax : 5));
  const concurrency = options?.concurrency ?? 2;

  const targets = recipes
    .slice(0, maxCount)
    .filter((r) => !isAppHostedRecipeImage(r.image_url));

  if (targets.length === 0) {
    return {
      recipes,
      stats: { attempted: 0, succeeded: 0, failed: 0 },
    };
  }

  let lastError: string | undefined;
  let succeeded = 0;

  const enhanced = await mapWithConcurrency(targets, concurrency, async (recipe) => {
    const ingredients = recipe.ingredients.map((i) => i.name).filter(Boolean);
    const storageBase = await exploreStorageBase(recipe.source, recipe.source_id, recipe.title);

    if (storageBase) {
      const cached = await getCachedStorageImageUrl(supabase, storageBase);
      if (cached) {
        succeeded++;
        return { id: recipe.id, image_url: cached };
      }
    }

    const prompt = buildRecipeImagePrompt(recipe.title, ingredients);
    const generated = await generateRecipeImageBase64(prompt, apiKey);
    if (!generated.ok) {
      lastError = generated.error;
      return { id: recipe.id, image_url: recipe.image_url };
    }

    const path = storageBase ?? `explore/${crypto.randomUUID()}`;
    const url = await uploadRecipeImage(
      supabase,
      generated.bytes,
      generated.mimeType,
      path,
    );

    if (url && isAppHostedRecipeImage(url)) {
      succeeded++;
      return { id: recipe.id, image_url: url };
    }

    lastError = lastError ?? 'Failed to upload Gemini image to storage';
    return { id: recipe.id, image_url: recipe.image_url };
  });

  const byId = new Map(enhanced.map((e) => [e.id, e.image_url]));
  const merged = recipes.map((r) => {
    const image_url = byId.get(r.id);
    return image_url && image_url !== r.image_url ? { ...r, image_url } : r;
  });

  return {
    recipes: merged,
    stats: {
      attempted: targets.length,
      succeeded,
      failed: targets.length - succeeded,
      ...(lastError ? { lastError } : {}),
    },
  };
}
