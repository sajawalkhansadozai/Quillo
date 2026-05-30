-- New recipes are public on Explore by default (owners can still turn off in app).
ALTER TABLE public.recipes
  ALTER COLUMN is_public SET DEFAULT true;
