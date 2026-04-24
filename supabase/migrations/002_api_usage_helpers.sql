-- ============================================================
-- Quillo — API Usage Increment Helper Functions
-- Run this in Supabase SQL Editor AFTER 001_initial_schema.sql
-- These are called by the Edge Functions to safely increment
-- daily usage counters without race conditions.
-- ============================================================

CREATE OR REPLACE FUNCTION public.increment_ocr_usage(p_user_id uuid, p_date date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.api_usage (user_id, date, ocr_calls, recipe_calls, daily_limit)
  VALUES (p_user_id, p_date, 1, 0, 10)
  ON CONFLICT (user_id, date)
  DO UPDATE SET ocr_calls = api_usage.ocr_calls + 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_recipe_usage(p_user_id uuid, p_date date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.api_usage (user_id, date, ocr_calls, recipe_calls, daily_limit)
  VALUES (p_user_id, p_date, 0, 1, 10)
  ON CONFLICT (user_id, date)
  DO UPDATE SET recipe_calls = api_usage.recipe_calls + 1;
END;
$$;

-- Upgrade premium users' daily limit to 30
CREATE OR REPLACE FUNCTION public.set_premium_limit(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.api_usage
  SET daily_limit = 30
  WHERE user_id = p_user_id;
END;
$$;
