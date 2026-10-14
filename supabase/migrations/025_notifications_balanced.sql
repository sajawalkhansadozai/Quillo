-- Notifications Balanced Edition — email engagement, milestones, monthly summary, push prefs.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nudge_email_sent_at timestamptz,
  ADD COLUMN IF NOT EXISTS email_disengaged boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_unsubscribed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS milestone_emails_sent integer[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS milestone_pushes_sent integer[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_monthly_summary_ym text,
  ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Europe/London',
  ADD COLUMN IF NOT EXISTS streak_push_week_key text,
  ADD COLUMN IF NOT EXISTS push_expiry_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS push_streak_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS push_milestone_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS last_push_sent_on date,
  ADD COLUMN IF NOT EXISTS celebrated_week_streaks integer[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS last_milestone_seen integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.users.email_disengaged IS
  'True when Email 2 was not engaged within 72h — no further marketing emails until user scans again.';
COMMENT ON COLUMN public.users.milestone_emails_sent IS
  'Milestone thresholds already emailed (50, 100, 250).';
COMMENT ON COLUMN public.users.milestone_pushes_sent IS
  'Milestone thresholds already pushed (50, 100, 250, 500).';
COMMENT ON COLUMN public.users.premium_prompt_email_sent IS
  'Deprecated — day-7 premium prompt removed in Balanced Edition.';

-- Refresh nudge candidates to respect unsubscribe.
CREATE OR REPLACE FUNCTION public.list_nudge_email_candidates()
RETURNS TABLE(user_id uuid, email text, first_name text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT
    pu.id AS user_id,
    pu.email,
    COALESCE(
      NULLIF(TRIM(au.raw_user_meta_data->>'full_name'), ''),
      INITCAP(SPLIT_PART(SPLIT_PART(pu.email, '@', 1), '.', 1))
    ) AS first_name
  FROM public.users pu
  INNER JOIN auth.users au ON au.id = pu.id
  WHERE pu.nudge_email_sent = false
    AND pu.email_unsubscribed = false
    AND au.email_confirmed_at IS NOT NULL
    AND au.email_confirmed_at < now() - interval '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM public.scans s WHERE s.user_id = pu.id
    )
  LIMIT 200;
$$;

CREATE TABLE IF NOT EXISTS public.notification_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  channel     text NOT NULL CHECK (channel IN ('email', 'push', 'in_app')),
  kind        text NOT NULL,
  payload     jsonb NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_log_user_created
  ON public.notification_log (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_log_kind
  ON public.notification_log (kind, created_at DESC);

ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_log_own_select" ON public.notification_log
  FOR SELECT USING (auth.uid() = user_id);

-- Re-engage when user completes a scan (unlocks monthly summary again).
CREATE OR REPLACE FUNCTION public.reengage_email_on_scan()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'complete' THEN
    UPDATE public.users
    SET email_disengaged = false
    WHERE id = NEW.user_id
      AND email_disengaged = true
      AND email_unsubscribed = false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reengage_email_on_scan ON public.scans;
CREATE TRIGGER trg_reengage_email_on_scan
  AFTER INSERT OR UPDATE OF status ON public.scans
  FOR EACH ROW
  EXECUTE FUNCTION public.reengage_email_on_scan();

-- Mark nudge sent + timestamp
CREATE OR REPLACE FUNCTION public.mark_nudge_email_sent(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET nudge_email_sent = true,
      nudge_email_sent_at = now()
  WHERE id = p_user_id;
END;
$$;

-- Disengage after 72h with no open-proxy: still zero scans after nudge.
CREATE OR REPLACE FUNCTION public.mark_nudge_disengaged_candidates()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  WITH updated AS (
    UPDATE public.users pu
    SET email_disengaged = true
    WHERE pu.nudge_email_sent = true
      AND pu.nudge_email_sent_at IS NOT NULL
      AND pu.nudge_email_sent_at < now() - interval '72 hours'
      AND pu.email_disengaged = false
      AND pu.email_unsubscribed = false
      AND NOT EXISTS (SELECT 1 FROM public.scans s WHERE s.user_id = pu.id)
    RETURNING 1
  )
  SELECT count(*)::int INTO v_count FROM updated;
  RETURN COALESCE(v_count, 0);
END;
$$;

-- Milestone email candidates (£50 / £100 / £250 once each).
CREATE OR REPLACE FUNCTION public.list_milestone_email_candidates()
RETURNS TABLE(
  user_id uuid,
  email text,
  first_name text,
  threshold int,
  money_saved numeric,
  kg_avoided numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  WITH thresholds AS (
    SELECT unnest(ARRAY[50, 100, 250]) AS threshold
  )
  SELECT
    pu.id AS user_id,
    pu.email,
    COALESCE(
      NULLIF(TRIM(au.raw_user_meta_data->>'full_name'), ''),
      INITCAP(SPLIT_PART(SPLIT_PART(pu.email, '@', 1), '.', 1))
    ) AS first_name,
    t.threshold,
    pu.waste_money_saved AS money_saved,
    ROUND(pu.waste_money_saved * 0.5, 1) AS kg_avoided
  FROM public.users pu
  INNER JOIN auth.users au ON au.id = pu.id
  CROSS JOIN thresholds t
  WHERE pu.email_unsubscribed = false
    AND pu.waste_money_saved >= t.threshold
    AND NOT (t.threshold = ANY (pu.milestone_emails_sent))
    AND (
      pu.email_disengaged = false
      OR EXISTS (
        SELECT 1 FROM public.scans s
        WHERE s.user_id = pu.id AND s.status = 'complete'
      )
    )
  ORDER BY pu.id, t.threshold
  LIMIT 200;
$$;

CREATE OR REPLACE FUNCTION public.mark_milestone_email_sent(
  p_user_id uuid,
  p_threshold int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET milestone_emails_sent = array_append(milestone_emails_sent, p_threshold)
  WHERE id = p_user_id
    AND NOT (p_threshold = ANY (milestone_emails_sent));

  INSERT INTO public.notification_log (user_id, channel, kind, payload)
  VALUES (
    p_user_id,
    'email',
    'milestone',
    jsonb_build_object('threshold', p_threshold)
  );
END;
$$;

-- Monthly summary: first Monday of month, active prior month, not disengaged (or re-engaged).
CREATE OR REPLACE FUNCTION public.list_monthly_summary_candidates()
RETURNS TABLE(
  user_id uuid,
  email text,
  first_name text,
  month_name text,
  ym text,
  scan_count int,
  money_saved numeric,
  kg_avoided numeric,
  week_streak int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_today date := (timezone('Europe/London', now()))::date;
  v_dow int;
  v_prev_start date;
  v_prev_end date;
  v_ym text;
  v_month_name text;
BEGIN
  v_dow := EXTRACT(ISODOW FROM v_today)::int; -- Mon=1
  -- Only run on Mondays that are the first Monday of the month
  IF v_dow <> 1 OR EXTRACT(DAY FROM v_today)::int > 7 THEN
    RETURN;
  END IF;

  v_prev_start := date_trunc('month', v_today - interval '1 month')::date;
  v_prev_end := (date_trunc('month', v_today)::date) - 1;
  v_ym := to_char(v_prev_start, 'YYYY-MM');
  v_month_name := to_char(v_prev_start, 'FMMonth');

  RETURN QUERY
  SELECT
    pu.id AS user_id,
    pu.email,
    COALESCE(
      NULLIF(TRIM(au.raw_user_meta_data->>'full_name'), ''),
      INITCAP(SPLIT_PART(SPLIT_PART(pu.email, '@', 1), '.', 1))
    ) AS first_name,
    v_month_name,
    v_ym,
    sc.cnt AS scan_count,
    COALESCE(pu.waste_money_saved, 0) AS money_saved,
    ROUND(COALESCE(pu.waste_money_saved, 0) * 0.5, 1) AS kg_avoided,
    COALESCE(pu.scan_streak, 0) AS week_streak
  FROM public.users pu
  INNER JOIN auth.users au ON au.id = pu.id
  INNER JOIN (
    SELECT s.user_id, count(*)::int AS cnt
    FROM public.scans s
    WHERE s.status = 'complete'
      AND s.scan_date::date >= v_prev_start
      AND s.scan_date::date <= v_prev_end
    GROUP BY s.user_id
    HAVING count(*) >= 1
  ) sc ON sc.user_id = pu.id
  WHERE pu.email_unsubscribed = false
    AND pu.email_disengaged = false
    AND (pu.last_monthly_summary_ym IS DISTINCT FROM v_ym)
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_monthly_summary_sent(
  p_user_id uuid,
  p_ym text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET last_monthly_summary_ym = p_ym
  WHERE id = p_user_id;

  INSERT INTO public.notification_log (user_id, channel, kind, payload)
  VALUES (
    p_user_id,
    'email',
    'monthly_summary',
    jsonb_build_object('ym', p_ym)
  );
END;
$$;

-- Push: milestone candidates
CREATE OR REPLACE FUNCTION public.list_milestone_push_candidates()
RETURNS TABLE(
  user_id uuid,
  threshold int,
  money_saved numeric,
  kg_avoided numeric,
  timezone text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH thresholds AS (
    SELECT unnest(ARRAY[50, 100, 250, 500]) AS threshold
  )
  SELECT
    pu.id AS user_id,
    t.threshold,
    pu.waste_money_saved AS money_saved,
    ROUND(pu.waste_money_saved * 0.5, 1) AS kg_avoided,
    pu.timezone
  FROM public.users pu
  CROSS JOIN thresholds t
  WHERE pu.push_milestone_enabled = true
    AND pu.waste_money_saved >= t.threshold
    AND NOT (t.threshold = ANY (pu.milestone_pushes_sent))
    AND (pu.last_push_sent_on IS DISTINCT FROM CURRENT_DATE)
  ORDER BY pu.id, t.threshold
  LIMIT 200;
$$;

CREATE OR REPLACE FUNCTION public.mark_milestone_push_sent(
  p_user_id uuid,
  p_threshold int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET milestone_pushes_sent = array_append(milestone_pushes_sent, p_threshold),
      last_push_sent_on = CURRENT_DATE
  WHERE id = p_user_id
    AND NOT (p_threshold = ANY (milestone_pushes_sent));

  INSERT INTO public.notification_log (user_id, channel, kind, payload)
  VALUES (
    p_user_id,
    'push',
    'milestone',
    jsonb_build_object('threshold', p_threshold)
  );
END;
$$;

-- Push: streak at risk — Thu local evening; week streak computed from complete scans.
CREATE OR REPLACE FUNCTION public.list_streak_push_candidates()
RETURNS TABLE(
  user_id uuid,
  week_streak int,
  timezone text,
  week_key text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_week_key text := to_char(date_trunc('week', now() AT TIME ZONE 'UTC'), 'IYYY-"W"IW');
BEGIN
  RETURN QUERY
  WITH week_starts AS (
    SELECT
      s.user_id,
      date_trunc('week', s.scan_date::timestamptz AT TIME ZONE 'UTC')::date AS week_start
    FROM public.scans s
    WHERE s.status = 'complete'
    GROUP BY s.user_id, date_trunc('week', s.scan_date::timestamptz AT TIME ZONE 'UTC')::date
  ),
  streaks AS (
    SELECT
      ws.user_id,
      count(*)::int AS weeks_with_scan
    FROM week_starts ws
    GROUP BY ws.user_id
  ),
  current_week AS (
    SELECT date_trunc('week', now() AT TIME ZONE 'UTC')::date AS w
  ),
  scanned_this_week AS (
    SELECT DISTINCT s.user_id
    FROM public.scans s, current_week cw
    WHERE s.status = 'complete'
      AND date_trunc('week', s.scan_date::timestamptz AT TIME ZONE 'UTC')::date = cw.w
  )
  SELECT
    pu.id AS user_id,
    GREATEST(st.weeks_with_scan, 0) AS week_streak,
    pu.timezone,
    v_week_key AS week_key
  FROM public.users pu
  INNER JOIN streaks st ON st.user_id = pu.id
  WHERE pu.push_streak_enabled = true
    AND st.weeks_with_scan >= 4
    AND pu.id NOT IN (SELECT user_id FROM scanned_this_week)
    AND (pu.streak_push_week_key IS DISTINCT FROM v_week_key)
    AND (pu.last_push_sent_on IS DISTINCT FROM CURRENT_DATE)
    -- Local Thursday 18:00–20:00 window (cron hourly)
    AND EXTRACT(ISODOW FROM (now() AT TIME ZONE COALESCE(NULLIF(pu.timezone, ''), 'Europe/London')))::int = 4
    AND EXTRACT(HOUR FROM (now() AT TIME ZONE COALESCE(NULLIF(pu.timezone, ''), 'Europe/London')))::int BETWEEN 18 AND 20
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_streak_push_sent(
  p_user_id uuid,
  p_week_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET streak_push_week_key = p_week_key,
      last_push_sent_on = CURRENT_DATE
  WHERE id = p_user_id;

  INSERT INTO public.notification_log (user_id, channel, kind, payload)
  VALUES (
    p_user_id,
    'push',
    'streak_at_risk',
    jsonb_build_object('week_key', p_week_key)
  );
END;
$$;

-- Push: ingredient expiry (5–7 days old from last scan), max one/week via last_push_sent_on + log.
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
  WITH latest_scan AS (
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
      i.normalised_name AS ingredient_name,
      ls.scanned_at
    FROM latest_scan ls
    INNER JOIN public.ingredients i ON i.scan_id = ls.scan_id
    WHERE ls.scanned_at <= now() - interval '5 days'
      AND ls.scanned_at >= now() - interval '7 days'
  ),
  ranked AS (
    SELECT DISTINCT ON (a.user_id)
      a.user_id,
      a.ingredient_name
    FROM aged a
    ORDER BY a.user_id, a.ingredient_name
  )
  SELECT
    r.user_id,
    INITCAP(r.ingredient_name) AS ingredient_name,
    pu.timezone,
    COALESCE(up.dietary_labels, '{}'::text[]) AS dietary_labels
  FROM ranked r
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
    -- Quiet hours: only 08:00–21:59 local
    AND EXTRACT(HOUR FROM (now() AT TIME ZONE COALESCE(NULLIF(pu.timezone, ''), 'Europe/London')))::int BETWEEN 8 AND 21
  LIMIT 200;
$$;

CREATE OR REPLACE FUNCTION public.mark_expiry_push_sent(
  p_user_id uuid,
  p_ingredient text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET last_push_sent_on = CURRENT_DATE
  WHERE id = p_user_id;

  INSERT INTO public.notification_log (user_id, channel, kind, payload)
  VALUES (
    p_user_id,
    'push',
    'ingredient_expiry',
    jsonb_build_object('ingredient', p_ingredient)
  );
END;
$$;

-- Client: update push prefs + timezone
CREATE OR REPLACE FUNCTION public.update_notification_prefs(
  p_expiry boolean DEFAULT NULL,
  p_streak boolean DEFAULT NULL,
  p_milestone boolean DEFAULT NULL,
  p_timezone text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET
    push_expiry_enabled = COALESCE(p_expiry, push_expiry_enabled),
    push_streak_enabled = COALESCE(p_streak, push_streak_enabled),
    push_milestone_enabled = COALESCE(p_milestone, push_milestone_enabled),
    timezone = COALESCE(NULLIF(TRIM(p_timezone), ''), timezone)
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_nudge_disengaged_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.list_milestone_email_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_milestone_email_sent(uuid, int) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_monthly_summary_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_monthly_summary_sent(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_milestone_push_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_milestone_push_sent(uuid, int) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_streak_push_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_streak_push_sent(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.list_expiry_push_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_expiry_push_sent(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.update_notification_prefs(boolean, boolean, boolean, text) TO authenticated;
