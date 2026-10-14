-- Onboarding Fix — preference completion flag (Quillo_Onboarding_Fix.docx §2.1)
-- Single source of truth: do not infer completion from row presence alone.

ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

-- Backfill users who already have core preference fields filled.
-- household_size lives on public.users; skill/cook time on user_preferences.
UPDATE public.user_preferences p
SET onboarding_completed = true
FROM public.users u
WHERE u.id = p.user_id
  AND p.onboarding_completed = false
  AND u.household_size IS NOT NULL
  AND p.cooking_skill IS NOT NULL
  AND p.max_cook_time IS NOT NULL;

COMMENT ON COLUMN public.user_preferences.onboarding_completed IS
  'True only after the full onboarding preference flow is finished.';
