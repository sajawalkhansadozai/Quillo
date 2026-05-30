-- Server-side recipe search (title + ingredients JSON) for the current user.
CREATE OR REPLACE FUNCTION public.search_user_recipes(
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
  WHERE r.user_id = auth.uid()
    AND trim(coalesce(p_query, '')) <> ''
    AND (
      r.title ILIKE '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
      OR r.ingredients_used::text ILIKE '%' || replace(replace(trim(p_query), '%', '\%'), '_', '\_') || '%'
    )
  ORDER BY r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
$$;

GRANT EXECUTE ON FUNCTION public.search_user_recipes(text, int) TO authenticated;
