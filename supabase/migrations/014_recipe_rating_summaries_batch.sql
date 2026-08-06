-- Batch community rating summaries for recipe cards.

CREATE OR REPLACE FUNCTION public.get_recipe_rating_summaries(p_recipe_ids uuid[])
RETURNS TABLE (
  recipe_id uuid,
  average_rating numeric,
  rating_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    rr.recipe_id,
    ROUND(AVG(rr.rating)::numeric, 1) AS average_rating,
    COUNT(*)::bigint AS rating_count
  FROM public.recipe_ratings rr
  WHERE rr.recipe_id = ANY(p_recipe_ids)
  GROUP BY rr.recipe_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_recipe_rating_summaries(uuid[]) TO authenticated;
