-- Per-user recipe ratings (1–5 stars).

CREATE TABLE IF NOT EXISTS public.recipe_ratings (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipe_id  uuid        NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
  rating     int         NOT NULL CHECK (rating >= 1 AND rating <= 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, recipe_id)
);

CREATE INDEX IF NOT EXISTS idx_recipe_ratings_user
  ON public.recipe_ratings(user_id);

CREATE INDEX IF NOT EXISTS idx_recipe_ratings_recipe
  ON public.recipe_ratings(recipe_id);

ALTER TABLE public.recipe_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipe_ratings_own" ON public.recipe_ratings
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
