-- Pantry use history follows the account, and expiry pushes use best-before dates.

CREATE TABLE IF NOT EXISTS public.user_pantry_activity (
  user_id            uuid        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  use_log            jsonb       NOT NULL DEFAULT '[]'::jsonb,
  dismissed_restock  text[]      NOT NULL DEFAULT '{}',
  updated_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_pantry_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_pantry_activity_select_own ON public.user_pantry_activity;
CREATE POLICY user_pantry_activity_select_own
  ON public.user_pantry_activity FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_pantry_activity_insert_own ON public.user_pantry_activity;
CREATE POLICY user_pantry_activity_insert_own
  ON public.user_pantry_activity FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_pantry_activity_update_own ON public.user_pantry_activity;
CREATE POLICY user_pantry_activity_update_own
  ON public.user_pantry_activity FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.user_pantry_activity TO authenticated;
GRANT ALL ON public.user_pantry_activity TO service_role;

-- Prefer pantry best-before dates. Fall back to aged scan ingredients
-- only for people who have nothing due in the pantry.
CREATE OR REPLACE FUNCTION public.list_expiry_push_candidates()
RETURNS TABLE(
  user_id uuid,
  ingredient_name text,
  timezone text,
  dietary_labels text[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH pantry_due AS (
    SELECT DISTINCT ON (p.user_id)
      p.user_id,
      INITCAP(COALESCE(NULLIF(p.data->>'name', ''), 'an item')) AS ingredient_name,
      left(p.data->>'best_before', 10)::date AS best_before
    FROM public.user_pantry_items p
    WHERE p.deleted_at IS NULL
      AND COALESCE(p.data->>'best_before', '') ~ '^\d{4}-\d{2}-\d{2}'
      AND left(p.data->>'best_before', 10)::date BETWEEN CURRENT_DATE - 1 AND CURRENT_DATE + 2
    ORDER BY p.user_id, left(p.data->>'best_before', 10)::date
  ),
  latest_scan AS (
    SELECT DISTINCT ON (s.user_id)
      s.user_id,
      s.id AS scan_id,
      s.scan_date::timestamptz AS scanned_at
    FROM public.scans s
    WHERE s.status = 'complete'
    ORDER BY s.user_id, s.scan_date DESC
  ),
  aged AS (
    SELECT
      ls.user_id,
      i.normalised_name AS ingredient_name
    FROM latest_scan ls
    INNER JOIN public.ingredients i ON i.scan_id = ls.scan_id
    WHERE ls.scanned_at <= now() - interval '5 days'
      AND ls.scanned_at >= now() - interval '7 days'
      AND NOT EXISTS (
        SELECT 1 FROM pantry_due d WHERE d.user_id = ls.user_id
      )
  ),
  ranked AS (
    SELECT DISTINCT ON (a.user_id)
      a.user_id,
      INITCAP(a.ingredient_name) AS ingredient_name
    FROM aged a
    ORDER BY a.user_id, a.ingredient_name
  ),
  picked AS (
    SELECT user_id, ingredient_name FROM pantry_due
    UNION ALL
    SELECT user_id, ingredient_name FROM ranked
  )
  SELECT
    r.user_id,
    r.ingredient_name,
    pu.timezone,
    COALESCE(up.dietary_labels, '{}'::text[]) AS dietary_labels
  FROM picked r
  INNER JOIN public.users pu ON pu.id = r.user_id
  LEFT JOIN public.user_preferences up ON up.user_id = r.user_id
  WHERE pu.push_expiry_enabled = true
    AND (pu.last_push_sent_on IS DISTINCT FROM CURRENT_DATE)
    AND NOT EXISTS (
      SELECT 1 FROM public.notification_log nl
      WHERE nl.user_id = r.user_id
        AND nl.kind = 'ingredient_expiry'
        AND nl.created_at > now() - interval '7 days'
    )
    AND EXTRACT(HOUR FROM (now() AT TIME ZONE COALESCE(NULLIF(pu.timezone, ''), 'Europe/London')))::int BETWEEN 8 AND 21
  LIMIT 200;
$$;
