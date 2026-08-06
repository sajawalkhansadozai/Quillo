-- Reduce free monthly scan limit from 10 to 2.

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
