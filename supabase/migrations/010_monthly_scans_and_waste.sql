-- ============================================================
-- Quillo — Monthly scan limits + food waste tracking
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS monthly_scan_count   int     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS monthly_scan_period  text,
  ADD COLUMN IF NOT EXISTS waste_money_saved    numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS waste_items_rescued  int     NOT NULL DEFAULT 0;

-- Consume one monthly scan for free users (premium bypasses).
CREATE OR REPLACE FUNCTION public.increment_monthly_scan(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_period text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM');
  v_status text;
  v_count  int;
  v_period_stored text;
BEGIN
  SELECT subscription_status, monthly_scan_count, monthly_scan_period
  INTO v_status, v_count, v_period_stored
  FROM public.users
  WHERE id = p_user_id;

  IF v_status = 'premium' THEN
    RETURN;
  END IF;

  IF v_period_stored IS DISTINCT FROM v_period THEN
    v_count := 0;
  END IF;

  UPDATE public.users
  SET monthly_scan_count = v_count + 1,
      monthly_scan_period = v_period
  WHERE id = p_user_id;
END;
$$;

-- Check quota without consuming (used by edge functions).
CREATE OR REPLACE FUNCTION public.check_monthly_scan_allowed(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_period text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM');
  v_status text;
  v_count  int;
  v_period_stored text;
  v_limit  int := 2;
BEGIN
  SELECT subscription_status, monthly_scan_count, monthly_scan_period
  INTO v_status, v_count, v_period_stored
  FROM public.users
  WHERE id = p_user_id;

  IF v_status = 'premium' THEN
    RETURN true;
  END IF;

  IF v_period_stored IS DISTINCT FROM v_period THEN
    v_count := 0;
  END IF;

  RETURN v_count < v_limit;
END;
$$;

-- Atomically consume quota; returns false when limit reached.
CREATE OR REPLACE FUNCTION public.consume_monthly_scan(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_period text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM');
  v_status text;
  v_count  int;
  v_period_stored text;
  v_limit  int := 2;
BEGIN
  SELECT subscription_status, monthly_scan_count, monthly_scan_period
  INTO v_status, v_count, v_period_stored
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_status = 'premium' THEN
    RETURN true;
  END IF;

  IF v_period_stored IS DISTINCT FROM v_period THEN
    v_count := 0;
  END IF;

  IF v_count >= v_limit THEN
    RETURN false;
  END IF;

  UPDATE public.users
  SET monthly_scan_count = v_count + 1,
      monthly_scan_period = v_period
  WHERE id = p_user_id;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_food_waste_saved(
  p_user_id uuid,
  p_items int,
  p_money numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET waste_items_rescued = waste_items_rescued + GREATEST(p_items, 0),
      waste_money_saved = waste_money_saved + GREATEST(p_money, 0)
  WHERE id = p_user_id;
END;
$$;
