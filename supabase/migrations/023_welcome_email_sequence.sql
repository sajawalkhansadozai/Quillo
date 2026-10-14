-- Welcome Email checklist §03–§04 — tracking flags + candidate queries + cron note.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS nudge_email_sent boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS premium_prompt_email_sent boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.users.nudge_email_sent IS
  'True after Email 2 (24h scan nudge) sent once via process-scheduled-emails.';
COMMENT ON COLUMN public.users.premium_prompt_email_sent IS
  'True after Email 3 (day-7 premium prompt) sent once via process-scheduled-emails.';

-- §03 — confirmed 24h+ ago, zero scans, not yet nudged.
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
    AND au.email_confirmed_at IS NOT NULL
    AND au.email_confirmed_at < now() - interval '24 hours'
    AND NOT EXISTS (
      SELECT 1 FROM public.scans s WHERE s.user_id = pu.id
    )
  LIMIT 200;
$$;

-- §04 — day 7+, free tier, ≥1 scan, not yet prompted.
CREATE OR REPLACE FUNCTION public.list_premium_prompt_email_candidates()
RETURNS TABLE(
  user_id uuid,
  email text,
  first_name text,
  scan_count int,
  weekly_saving_gbp numeric
)
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
    ) AS first_name,
    sc.cnt AS scan_count,
    ROUND((sc.cnt::numeric / 52.0) * 700, 2) AS weekly_saving_gbp
  FROM public.users pu
  INNER JOIN auth.users au ON au.id = pu.id
  INNER JOIN (
    SELECT user_id, count(*)::int AS cnt
    FROM public.scans
    GROUP BY user_id
    HAVING count(*) >= 1
  ) sc ON sc.user_id = pu.id
  WHERE pu.premium_prompt_email_sent = false
    AND pu.subscription_status IS DISTINCT FROM 'premium'
    AND pu.created_at < now() - interval '7 days'
  LIMIT 200;
$$;

CREATE OR REPLACE FUNCTION public.mark_nudge_email_sent(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET nudge_email_sent = true
  WHERE id = p_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_premium_prompt_email_sent(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET premium_prompt_email_sent = true
  WHERE id = p_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.list_nudge_email_candidates() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_premium_prompt_email_candidates() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_nudge_email_sent(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_premium_prompt_email_sent(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.list_nudge_email_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.list_premium_prompt_email_candidates() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_nudge_email_sent(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_premium_prompt_email_sent(uuid) TO service_role;

-- Hourly cron: schedule process-scheduled-emails in Supabase Dashboard
-- (Edge Functions → process-scheduled-emails → Cron: 0 * * * *)
-- with header x-email-cron-secret = EMAIL_CRON_SECRET secret value.

DO $$
BEGIN
  RAISE NOTICE 'Welcome emails: schedule process-scheduled-emails hourly in Supabase Dashboard.';
END;
$$;
