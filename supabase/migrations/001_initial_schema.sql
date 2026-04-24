-- ============================================================
-- Quillo — Initial Database Schema
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- TABLES
-- ─────────────────────────────────────────────────────────────

-- 1. users
CREATE TABLE IF NOT EXISTS public.users (
  id                  uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text        NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  household_size      int         NOT NULL DEFAULT 2,
  preferred_cuisine   text[]      NOT NULL DEFAULT '{}',
  gdpr_consent        boolean     NOT NULL DEFAULT false,
  gdpr_consent_at     timestamptz,
  scan_streak         int         NOT NULL DEFAULT 0,
  last_scan_date      date,
  subscription_status text        NOT NULL DEFAULT 'free'
);

-- 2. user_preferences
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  dietary_labels       text[] NOT NULL DEFAULT '{}',
  exclude_ingredients  text[] NOT NULL DEFAULT '{}',
  UNIQUE (user_id)
);

-- 3. scans
CREATE TABLE IF NOT EXISTS public.scans (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  image_url    text,
  raw_ocr_text text,
  scan_date    timestamptz NOT NULL DEFAULT now(),
  status       text        NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'complete', 'failed'))
);

-- 4. ingredients
CREATE TABLE IF NOT EXISTS public.ingredients (
  id               uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id          uuid    NOT NULL REFERENCES public.scans(id) ON DELETE CASCADE,
  user_id          uuid    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  raw_name         text    NOT NULL,
  normalised_name  text    NOT NULL,
  quantity         numeric,
  unit             text,
  user_edited      boolean NOT NULL DEFAULT false
);

-- 5. recipes
CREATE TABLE IF NOT EXISTS public.recipes (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id              uuid        REFERENCES public.scans(id) ON DELETE SET NULL,
  user_id              uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title                text        NOT NULL,
  cook_time_minutes    int,
  difficulty           text        CHECK (difficulty IN ('easy', 'medium', 'hard')),
  servings             int,
  steps                jsonb       NOT NULL DEFAULT '[]',
  ingredients_used     jsonb       NOT NULL DEFAULT '[]',
  missing_ingredients  jsonb       NOT NULL DEFAULT '[]',
  nutrition            jsonb,
  created_at           timestamptz NOT NULL DEFAULT now()
);

-- 6. saved_recipes
CREATE TABLE IF NOT EXISTS public.saved_recipes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipe_id   uuid        NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
  saved_at    timestamptz NOT NULL DEFAULT now(),
  cached_data jsonb,
  UNIQUE (user_id, recipe_id)
);

-- 7. api_usage
CREATE TABLE IF NOT EXISTS public.api_usage (
  id           uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid  NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  date         date  NOT NULL DEFAULT CURRENT_DATE,
  ocr_calls    int   NOT NULL DEFAULT 0,
  recipe_calls int   NOT NULL DEFAULT 0,
  daily_limit  int   NOT NULL DEFAULT 10,
  UNIQUE (user_id, date)
);

-- ─────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scans             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_recipes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_usage         ENABLE ROW LEVEL SECURITY;

-- users: only own row
CREATE POLICY "users_own" ON public.users
  FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- user_preferences: only own row
CREATE POLICY "user_preferences_own" ON public.user_preferences
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- scans: only own rows
CREATE POLICY "scans_own" ON public.scans
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ingredients: only own rows
CREATE POLICY "ingredients_own" ON public.ingredients
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- recipes: only own rows
CREATE POLICY "recipes_own" ON public.recipes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- saved_recipes: only own rows
CREATE POLICY "saved_recipes_own" ON public.saved_recipes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- api_usage: only own rows
CREATE POLICY "api_usage_own" ON public.api_usage
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- INDEXES (for performance)
-- ─────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_scans_user_id       ON public.scans(user_id);
CREATE INDEX IF NOT EXISTS idx_ingredients_scan_id ON public.ingredients(scan_id);
CREATE INDEX IF NOT EXISTS idx_ingredients_user_id ON public.ingredients(user_id);
CREATE INDEX IF NOT EXISTS idx_recipes_user_id     ON public.recipes(user_id);
CREATE INDEX IF NOT EXISTS idx_recipes_scan_id     ON public.recipes(scan_id);
CREATE INDEX IF NOT EXISTS idx_saved_recipes_user  ON public.saved_recipes(user_id);
CREATE INDEX IF NOT EXISTS idx_api_usage_user_date ON public.api_usage(user_id, date);

-- ─────────────────────────────────────────────────────────────
-- STORAGE BUCKET
-- Run these separately in the Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('receipt-images', 'receipt-images', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: users can only access their own images
-- Images are stored as: receipt-images/{user_id}/{filename}
CREATE POLICY "storage_own_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'receipt-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "storage_own_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'receipt-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "storage_own_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'receipt-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ─────────────────────────────────────────────────────────────
-- AUTO-CREATE USER ROW ON SIGNUP (trigger)
-- This ensures a users row exists as soon as Supabase Auth
-- creates the account — even before the app calls saveUserProfile.
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, subscription_status, scan_streak)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    'free',
    0
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
