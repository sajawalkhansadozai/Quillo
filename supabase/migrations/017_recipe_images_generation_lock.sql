-- Race-safe Gemini generation status on recipe_images
ALTER TABLE public.recipe_images
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'ready';

-- pending://generating placeholders must not be served as real images
COMMENT ON COLUMN public.recipe_images.status IS 'ready | generating';
