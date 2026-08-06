-- Public aggregate rating summary (no individual ratings exposed).

CREATE OR REPLACE FUNCTION public.get_recipe_rating_summary(p_recipe_id uuid)
RETURNS TABLE (
  average_rating numeric,
  rating_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    ROUND(AVG(rating)::numeric, 1) AS average_rating,
    COUNT(*)::bigint AS rating_count
  FROM public.recipe_ratings
  WHERE recipe_id = p_recipe_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_recipe_rating_summary(uuid) TO authenticated;
