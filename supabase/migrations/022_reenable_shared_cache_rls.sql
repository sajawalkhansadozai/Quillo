-- Fix Supabase advisor rls_disabled_in_public.
-- Shared cache tables stay readable by signed-in users; writes stay
-- service-role only (edge functions bypass RLS).

ALTER TABLE public.recipe_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.search_popularity ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owners so the advisor stays green.
ALTER TABLE public.recipe_cache FORCE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_images FORCE ROW LEVEL SECURITY;
ALTER TABLE public.search_popularity FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recipe_cache_select_authenticated" ON public.recipe_cache;
CREATE POLICY "recipe_cache_select_authenticated" ON public.recipe_cache
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "recipe_images_select_authenticated" ON public.recipe_images;
CREATE POLICY "recipe_images_select_authenticated" ON public.recipe_images
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "search_popularity_select_authenticated" ON public.search_popularity;
CREATE POLICY "search_popularity_select_authenticated" ON public.search_popularity
  FOR SELECT TO authenticated USING (true);

REVOKE ALL ON public.recipe_cache FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.recipe_images FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.search_popularity FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.recipe_cache TO authenticated;
GRANT SELECT ON public.recipe_images TO authenticated;
GRANT SELECT ON public.search_popularity TO authenticated;

GRANT ALL ON public.recipe_cache TO service_role;
GRANT ALL ON public.recipe_images TO service_role;
GRANT ALL ON public.search_popularity TO service_role;
