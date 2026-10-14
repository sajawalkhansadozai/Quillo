-- Search Fix Checklist (10 Aug 2026): shared cache RLS, pg_trgm fuzzy match,
-- normalised terms, popularity suggestions, and user_searches logging.

-- ── 1.2 Shared tables must be readable by all users ─────────────────────────
ALTER TABLE public.recipe_cache DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_images DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_popularity DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recipe_cache_select_authenticated" ON public.recipe_cache;
DROP POLICY IF EXISTS "recipe_images_select_authenticated" ON public.recipe_images;
DROP POLICY IF EXISTS "search_popularity_select_authenticated" ON public.search_popularity;

GRANT SELECT ON public.recipe_cache TO authenticated;
GRANT SELECT ON public.recipe_images TO authenticated;
GRANT SELECT ON public.search_popularity TO authenticated;

-- ── 3.1 pg_trgm ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ── recipe_cache columns for title / normalised fuzzy lookup ────────────────
ALTER TABLE public.recipe_cache
  ADD COLUMN IF NOT EXISTS recipe_title text,
  ADD COLUMN IF NOT EXISTS normalised_search_term text;

UPDATE public.recipe_cache
SET
  recipe_title = coalesce(
    nullif(trim(recipe_payload->>'title'), ''),
    nullif(trim(recipe_payload->>'name'), ''),
    search_term
  ),
  normalised_search_term = lower(trim(regexp_replace(
    regexp_replace(coalesce(search_term, ''), '[^a-zA-Z0-9 ]', '', 'g'),
    '\s+', ' ', 'g'
  )))
WHERE recipe_title IS NULL
   OR normalised_search_term IS NULL;

ALTER TABLE public.recipe_cache
  ALTER COLUMN recipe_title SET DEFAULT '',
  ALTER COLUMN normalised_search_term SET DEFAULT '';

UPDATE public.recipe_cache
SET recipe_title = coalesce(recipe_title, '')
WHERE recipe_title IS NULL;

UPDATE public.recipe_cache
SET normalised_search_term = coalesce(normalised_search_term, '')
WHERE normalised_search_term IS NULL;

CREATE INDEX IF NOT EXISTS recipe_cache_title_trgm_idx
  ON public.recipe_cache USING gin (recipe_title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS recipe_cache_terms_trgm_idx
  ON public.recipe_cache USING gin (normalised_search_term gin_trgm_ops);

CREATE INDEX IF NOT EXISTS recipes_title_trgm_idx
  ON public.recipes USING gin (title gin_trgm_ops);

-- ── search_popularity: normalised_term for autocomplete ─────────────────────
ALTER TABLE public.search_popularity
  ADD COLUMN IF NOT EXISTS normalised_term text;

UPDATE public.search_popularity
SET normalised_term = lower(trim(regexp_replace(
  regexp_replace(coalesce(search_term, ''), '[^a-zA-Z0-9 ]', '', 'g'),
  '\s+', ' ', 'g'
)))
WHERE normalised_term IS NULL OR normalised_term = '';

CREATE INDEX IF NOT EXISTS search_popularity_normalised_trgm_idx
  ON public.search_popularity USING gin (normalised_term gin_trgm_ops);

CREATE INDEX IF NOT EXISTS search_popularity_normalised_prefix_idx
  ON public.search_popularity (normalised_term);

-- ── 4.2 user_searches ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_searches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  raw_term text NOT NULL,
  normalised_term text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_searches_user_created
  ON public.user_searches (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_searches_normalised
  ON public.user_searches (normalised_term);

ALTER TABLE public.user_searches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_searches_select_own" ON public.user_searches;
CREATE POLICY "user_searches_select_own" ON public.user_searches
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_searches_insert_own" ON public.user_searches;
CREATE POLICY "user_searches_insert_own" ON public.user_searches
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT ON public.user_searches TO authenticated;

-- ── Fuzzy public recipe search (partial words + minor typos) ────────────────
CREATE OR REPLACE FUNCTION public.search_public_recipes(
  p_query text,
  p_limit int DEFAULT 50
)
RETURNS SETOF public.recipes
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH q AS (
    SELECT
      lower(trim(regexp_replace(
        regexp_replace(coalesce(p_query, ''), '[^a-zA-Z0-9 ]', '', 'g'),
        '\s+', ' ', 'g'
      ))) AS term,
      replace(replace(
        lower(trim(regexp_replace(
          regexp_replace(coalesce(p_query, ''), '[^a-zA-Z0-9 ]', '', 'g'),
          '\s+', ' ', 'g'
        ))),
        '%', '\%'
      ), '_', '\_') AS like_escaped,
      regexp_replace(
        lower(trim(regexp_replace(
          regexp_replace(coalesce(p_query, ''), '[^a-zA-Z0-9 ]', '', 'g'),
          '\s+', ' ', 'g'
        ))),
        '([\\.^$|?*+()\\[\\]{}])',
        '\\\1',
        'g'
      ) AS regex_escaped
  )
  SELECT r.*
  FROM public.recipes r
  CROSS JOIN q
  WHERE r.is_public = true
    AND q.term <> ''
    AND (
      similarity(lower(r.title), q.term) > 0.2
      OR r.title ILIKE '%' || q.like_escaped || '%'
      OR r.ingredients_used::text ~* ('(^|[^a-z0-9])' || q.regex_escaped || '([^a-z0-9]|$)')
    )
  ORDER BY
    greatest(
      similarity(lower(r.title), q.term),
      CASE
        WHEN lower(r.title) = q.term THEN 1.0
        WHEN lower(r.title) LIKE q.term || '%' THEN 0.9
        WHEN r.title ILIKE '%' || q.like_escaped || '%' THEN 0.7
        ELSE 0.2
      END
    ) DESC,
    r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
$$;

GRANT EXECUTE ON FUNCTION public.search_public_recipes(text, int) TO authenticated;

-- Fuzzy recipe_cache lookup by title / normalised term (checklist 3.3)
CREATE OR REPLACE FUNCTION public.search_recipe_cache_fuzzy(
  p_query text,
  p_limit int DEFAULT 10
)
RETURNS TABLE (
  recipe_id uuid,
  recipe_title text,
  recipe_payload jsonb,
  score double precision
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH q AS (
    SELECT lower(trim(regexp_replace(
      regexp_replace(coalesce(p_query, ''), '[^a-zA-Z0-9 ]', '', 'g'),
      '\s+', ' ', 'g'
    ))) AS term
  ),
  ranked AS (
    SELECT
      c.recipe_id,
      c.recipe_title,
      c.recipe_payload,
      greatest(
        similarity(coalesce(c.recipe_title, ''), q.term),
        similarity(coalesce(c.normalised_search_term, ''), q.term)
      ) AS score,
      row_number() OVER (
        PARTITION BY coalesce(
          nullif(c.recipe_payload->>'id', ''),
          c.recipe_id::text,
          lower(coalesce(c.recipe_title, ''))
        )
        ORDER BY greatest(
          similarity(coalesce(c.recipe_title, ''), q.term),
          similarity(coalesce(c.normalised_search_term, ''), q.term)
        ) DESC
      ) AS rn
    FROM public.recipe_cache c
    CROSS JOIN q
    WHERE q.term <> ''
      AND (
        similarity(coalesce(c.recipe_title, ''), q.term) > 0.2
        OR c.recipe_title ILIKE '%' || q.term || '%'
        OR similarity(coalesce(c.normalised_search_term, ''), q.term) > 0.2
        OR c.normalised_search_term ILIKE '%' || q.term || '%'
      )
  )
  SELECT recipe_id, recipe_title, recipe_payload, score
  FROM ranked
  WHERE rn = 1
  ORDER BY score DESC
  LIMIT greatest(1, least(coalesce(p_limit, 10), 50));
$$;

GRANT EXECUTE ON FUNCTION public.search_recipe_cache_fuzzy(text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_recipe_cache_fuzzy(text, int) TO service_role;

-- Autocomplete from popular searches (checklist 6.x)
CREATE OR REPLACE FUNCTION public.suggest_search_terms(
  p_prefix text,
  p_limit int DEFAULT 5
)
RETURNS TABLE (
  search_term text,
  search_count int
)
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  WITH q AS (
    SELECT lower(trim(regexp_replace(
      regexp_replace(coalesce(p_prefix, ''), '[^a-zA-Z0-9 ]', '', 'g'),
      '\s+', ' ', 'g'
    ))) AS term
  )
  SELECT
    coalesce(nullif(sp.normalised_term, ''), sp.search_term) AS search_term,
    sp.hit_count AS search_count
  FROM public.search_popularity sp
  CROSS JOIN q
  WHERE q.term <> ''
    AND length(q.term) >= 2
    AND coalesce(nullif(sp.normalised_term, ''), sp.search_term) ILIKE q.term || '%'
  ORDER BY sp.hit_count DESC, sp.last_searched_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 5), 10));
$$;

GRANT EXECUTE ON FUNCTION public.suggest_search_terms(text, int) TO authenticated;

-- Atomically bump popularity (normalised key)
CREATE OR REPLACE FUNCTION public.record_search_popularity(
  p_term text,
  p_cached_count int DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
BEGIN
  v_norm := lower(trim(regexp_replace(
    regexp_replace(coalesce(p_term, ''), '[^a-zA-Z0-9 ]', '', 'g'),
    '\s+', ' ', 'g'
  )));
  IF v_norm = '' THEN
    RETURN;
  END IF;

  INSERT INTO public.search_popularity AS sp (
    search_term,
    normalised_term,
    hit_count,
    last_searched_at,
    cached_count
  ) VALUES (
    v_norm,
    v_norm,
    1,
    now(),
    greatest(coalesce(p_cached_count, 0), 0)
  )
  ON CONFLICT (search_term) DO UPDATE
  SET
    normalised_term = excluded.normalised_term,
    hit_count = sp.hit_count + 1,
    last_searched_at = now(),
    cached_count = greatest(sp.cached_count, excluded.cached_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_search_popularity(text, int) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_search_popularity(text, int) TO authenticated;
