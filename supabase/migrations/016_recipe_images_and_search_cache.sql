-- recipe_images: permanent Gemini cache keyed by recipe (shared across users)
CREATE TABLE IF NOT EXISTS public.recipe_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id uuid REFERENCES public.recipes(id) ON DELETE CASCADE,
  recipe_title text NOT NULL,
  image_url text NOT NULL,
  image_source text NOT NULL DEFAULT 'gemini_generated',
  generation_prompt text,
  storage_path text,
  source text,
  source_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT recipe_images_recipe_id_unique UNIQUE (recipe_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_recipe_images_source_pair
  ON public.recipe_images (source, source_id)
  WHERE source IS NOT NULL AND source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_recipe_images_title_lower
  ON public.recipe_images (lower(recipe_title));

ALTER TABLE public.recipe_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recipe_images_select_authenticated" ON public.recipe_images;
CREATE POLICY "recipe_images_select_authenticated" ON public.recipe_images
  FOR SELECT TO authenticated USING (true);

-- Shared search result cache (smart pagination)
CREATE TABLE IF NOT EXISTS public.recipe_cache (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  search_term text NOT NULL,
  result_position int NOT NULL,
  recipe_id uuid REFERENCES public.recipes(id) ON DELETE CASCADE,
  recipe_payload jsonb NOT NULL,
  cached_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT recipe_cache_term_position_unique UNIQUE (search_term, result_position)
);

CREATE INDEX IF NOT EXISTS idx_recipe_cache_term_pos
  ON public.recipe_cache (search_term, result_position);

ALTER TABLE public.recipe_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recipe_cache_select_authenticated" ON public.recipe_cache;
CREATE POLICY "recipe_cache_select_authenticated" ON public.recipe_cache
  FOR SELECT TO authenticated USING (true);

CREATE TABLE IF NOT EXISTS public.search_popularity (
  search_term text PRIMARY KEY,
  hit_count int NOT NULL DEFAULT 1,
  last_searched_at timestamptz NOT NULL DEFAULT now(),
  cached_count int NOT NULL DEFAULT 0
);

ALTER TABLE public.search_popularity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "search_popularity_select_authenticated" ON public.search_popularity;
CREATE POLICY "search_popularity_select_authenticated" ON public.search_popularity
  FOR SELECT TO authenticated USING (true);
