/**
 * Receipt image preprocessing for OCR (Faded Receipt §01–§02).
 *
 * Sharp is Node-native and cannot run on Supabase Edge (Deno). This module
 * implements the same pipeline with ImageScript:
 *   greyscale → normalise → sharpen → threshold
 */

import { decode, Image } from 'https://deno.land/x/imagescript@1.2.15/mod.ts';

export type PreprocessPass = 0 | 1 | 2 | 3;

export interface ImageMeta {
  width: number;
  height: number;
  meanBrightness: number;
  pass: PreprocessPass;
}

export interface PreprocessResult {
  jpeg: Uint8Array;
  meta: ImageMeta;
}

function luma(r: number, g: number, b: number): number {
  return 0.299 * r + 0.587 * g + 0.114 * b;
}

/** Direct bitmap walk — ImageScript stores RGBA in `img.bitmap`. */
function toGreyscale(img: Image): void {
  const bmp = img.bitmap;
  for (let i = 0; i < bmp.length; i += 4) {
    const v = Math.round(luma(bmp[i], bmp[i + 1], bmp[i + 2]));
    bmp[i] = v;
    bmp[i + 1] = v;
    bmp[i + 2] = v;
  }
}

/** Percentile stretch — Sharp's normalise / normalise({ lower, upper }). */
function normalise(
  img: Image,
  lowerPercentile = 1,
  upperPercentile = 99,
): void {
  const bmp = img.bitmap;
  const samples: number[] = [];
  const step = Math.max(4, Math.floor(bmp.length / 50000) * 4);
  for (let i = 0; i < bmp.length; i += step) {
    samples.push(bmp[i]);
  }
  samples.sort((a, b) => a - b);
  if (samples.length < 2) return;

  const loIdx = Math.floor((lowerPercentile / 100) * (samples.length - 1));
  const hiIdx = Math.floor((upperPercentile / 100) * (samples.length - 1));
  const lo = samples[loIdx];
  const hi = samples[hiIdx];
  const range = Math.max(1, hi - lo);

  for (let i = 0; i < bmp.length; i += 4) {
    const v = Math.round(
      Math.min(255, Math.max(0, ((bmp[i] - lo) / range) * 255)),
    );
    bmp[i] = v;
    bmp[i + 1] = v;
    bmp[i + 2] = v;
  }
}

/** Unsharp-style cross convolution. Higher strength ≈ stronger sharpen. */
function sharpen(img: Image, strength = 1): void {
  const w = img.width;
  const h = img.height;
  const bmp = img.bitmap;
  const src = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      src[y * w + x] = bmp[(y * w + x) * 4];
    }
  }

  const centre = 1 + 4 * strength;
  const neighbour = -strength;

  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      const v =
        src[(y - 1) * w + x] * neighbour +
        src[y * w + (x - 1)] * neighbour +
        src[y * w + x] * centre +
        src[y * w + (x + 1)] * neighbour +
        src[(y + 1) * w + x] * neighbour;
      const clamped = Math.round(Math.min(255, Math.max(0, v)));
      const idx = (y * w + x) * 4;
      bmp[idx] = clamped;
      bmp[idx + 1] = clamped;
      bmp[idx + 2] = clamped;
    }
  }
}

function threshold(img: Image, cutoff: number): void {
  const bmp = img.bitmap;
  for (let i = 0; i < bmp.length; i += 4) {
    const v = bmp[i] >= cutoff ? 255 : 0;
    bmp[i] = v;
    bmp[i + 1] = v;
    bmp[i + 2] = v;
  }
}

function invert(img: Image): void {
  const bmp = img.bitmap;
  for (let i = 0; i < bmp.length; i += 4) {
    bmp[i] = 255 - bmp[i];
    bmp[i + 1] = 255 - bmp[i + 1];
    bmp[i + 2] = 255 - bmp[i + 2];
  }
}

function meanBrightness(img: Image): number {
  const bmp = img.bitmap;
  let sum = 0;
  let n = 0;
  const step = Math.max(4, Math.floor(bmp.length / 20000) * 4);
  for (let i = 0; i < bmp.length; i += step) {
    sum += bmp[i];
    n++;
  }
  return n === 0 ? 128 : sum / n;
}

function maybeDownscale(img: Image, maxEdge = 2000): Image {
  const longest = Math.max(img.width, img.height);
  if (longest <= maxEdge) return img;
  const scale = maxEdge / longest;
  return img.resize(
    Math.round(img.width * scale),
    Math.round(img.height * scale),
  );
}

/**
 * Pass 0 — clear receipts: keep colour, light sharpen only (no threshold).
 * Pass 1 — standard (threshold 128)
 * Pass 2 — aggressive contrast (threshold 100, stronger sharpen)
 * Pass 3 — max contrast; invert first if the page is darker than the text
 */
export async function preprocessReceipt(
  buffer: Uint8Array,
  pass: PreprocessPass = 1,
): Promise<PreprocessResult> {
  let img = await decode(buffer);
  img = maybeDownscale(img);

  if (pass === 0) {
    // Keep colour — only downscale for API limits (clear receipts).
  } else {
    toGreyscale(img);

    if (pass === 1) {
      normalise(img, 1, 99);
      sharpen(img, 1);
      threshold(img, 128);
    } else if (pass === 2) {
      normalise(img, 5, 95);
      sharpen(img, 2);
      threshold(img, 100);
    } else {
      // Pass 3: if mean is dark (likely dark bg / inverted thermal), invert first.
      const mean = meanBrightness(img);
      if (mean < 110) invert(img);
      normalise(img, 10, 90);
      sharpen(img, 2.5);
      threshold(img, 90);
    }
  }

  const meta: ImageMeta = {
    width: img.width,
    height: img.height,
    meanBrightness: Math.round(meanBrightness(img) * 10) / 10,
    pass,
  };

  const jpeg = await img.encodeJPEG(pass === 0 ? 92 : 85);
  return { jpeg, meta };
}

export function uint8ToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}
