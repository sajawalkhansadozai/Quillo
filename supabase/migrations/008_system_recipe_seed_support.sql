-- Support large-scale imported recipes (e.g. 1400+)
-- Adds source metadata + dedupe fields for safe bulk upserts.

ALTER TABLE public.recipes
  ADD COLUMN IF NOT EXISTS is_system boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS source_id text,
  ADD COLUMN IF NOT EXISTS source_url text,
  ADD COLUMN IF NOT EXISTS license text,
  ADD COLUMN IF NOT EXISTS title_hash text;

-- Dedupe by provider identity when available.
ALTER TABLE public.recipes
  DROP CONSTRAINT IF EXISTS recipes_source_source_id_unique;

ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_source_source_id_unique
  UNIQUE (source, source_id);

CREATE INDEX IF NOT EXISTS idx_recipes_is_system_created
  ON public.recipes (is_system, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_recipes_title_hash
  ON public.recipes (title_hash);
