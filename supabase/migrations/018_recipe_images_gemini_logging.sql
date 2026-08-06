-- 2.6: Log every Gemini image against recipe_id with model + generated_at
ALTER TABLE public.recipe_images
  ADD COLUMN IF NOT EXISTS generated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.recipe_images
  ADD COLUMN IF NOT EXISTS gemini_model text;

-- Backfill generated_at from created_at where needed
UPDATE public.recipe_images
SET generated_at = created_at
WHERE generated_at IS NULL;

COMMENT ON COLUMN public.recipe_images.generated_at IS 'When the Gemini image was generated / logged';
COMMENT ON COLUMN public.recipe_images.gemini_model IS 'Gemini model id used to generate the image';

-- Backfill rows for existing recipes that already have app-hosted Gemini images
-- Note: remote recipes table may not have source/source_id columns.
INSERT INTO public.recipe_images (
  recipe_id,
  recipe_title,
  image_url,
  image_source,
  generated_at,
  gemini_model,
  status
)
SELECT
  r.id,
  r.title,
  r.image_url,
  'gemini_generated',
  COALESCE(r.created_at, now()),
  'gemini-2.5-flash-image',
  'ready'
FROM public.recipes r
WHERE r.image_url IS NOT NULL
  AND r.image_url LIKE '%/recipe-images/%'
  AND NOT EXISTS (
    SELECT 1 FROM public.recipe_images ri WHERE ri.recipe_id = r.id
  )
ON CONFLICT (recipe_id) DO NOTHING;

-- Existing recipe_images rows created before gemini_model column
UPDATE public.recipe_images
SET gemini_model = 'gemini-2.5-flash-image'
WHERE gemini_model IS NULL
   OR gemini_model IN ('backfill_existing', 'backfill_unknown');
