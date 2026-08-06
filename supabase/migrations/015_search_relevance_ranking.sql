-- Tighten public recipe search: title matches rank first; ingredient hits use
-- word-boundary matching so receipt leftovers (e.g. "steak" listed on a fish
-- recipe's ingredients_used) don't dominate Explore results.

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
      trim(coalesce(p_query, '')) AS term,
      replace(replace(trim(coalesce(p_query, '')), '%', '\%'), '_', '\_') AS like_escaped,
      -- Escape POSIX regex metacharacters for safe ~* matching.
      regexp_replace(
        trim(coalesce(p_query, '')),
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
      r.title ILIKE '%' || q.like_escaped || '%'
      OR r.ingredients_used::text ~* ('(^|[^a-z0-9])' || q.regex_escaped || '([^a-z0-9]|$)')
    )
  ORDER BY
    CASE
      WHEN lower(r.title) = lower(q.term) THEN 300
      WHEN lower(r.title) LIKE lower(q.term) || '%' THEN 200
      WHEN r.title ILIKE '%' || q.like_escaped || '%' THEN 100
      ELSE 20
    END DESC,
    r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
$$;

GRANT EXECUTE ON FUNCTION public.search_public_recipes(text, int) TO authenticated;
