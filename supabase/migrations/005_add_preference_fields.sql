-- Add extra preference columns to user_preferences
ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS cooking_skill TEXT NOT NULL DEFAULT 'Intermediate',
  ADD COLUMN IF NOT EXISTS max_cook_time INT  NOT NULL DEFAULT 45;
