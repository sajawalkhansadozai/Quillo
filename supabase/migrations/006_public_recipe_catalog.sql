-- Public Explore catalog: opt-in sharing via is_public on recipes.

ALTER TABLE public.recipes
  ADD COLUMN IF NOT EXISTS is_public boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_recipes_public_created
  ON public.recipes (created_at DESC)
  WHERE is_public = true;

-- Replace single-owner policy with granular policies.
DROP POLICY IF EXISTS "recipes_own" ON public.recipes;

CREATE POLICY "recipes_select_own_or_public" ON public.recipes
  FOR SELECT
  USING (auth.uid() = user_id OR is_public = true);

CREATE POLICY "recipes_insert_own" ON public.recipes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "recipes_update_own" ON public.recipes
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "recipes_delete_own" ON public.recipes
  FOR DELETE
  USING (auth.uid() = user_id);

-- Search public catalog (title + ingredients).
CREATE OR REPLACE FUNCTION public.search_public_recipes(
  p_query text,
  p_limit int DEFAULT 50
)
RETURNS SETOF public.recipes
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT r.*
  FROM public.recipes r
  WHERE r.is_public = true
    AND trim(coalesce(p_query, '')) <> ''
    AND (
      r.title ILIKE '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      OR r.ingredients_used::text ILIKE '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
    )
  ORDER BY r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
$$;

GRANT EXECUTE ON FUNCTION public.search_public_recipes(text, int) TO authenticated;
