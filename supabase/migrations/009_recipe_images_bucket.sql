-- Public bucket for AI-generated recipe hero images (Gemini 3 Pro Image).

INSERT INTO storage.buckets (id, name, public)
VALUES ('recipe-images', 'recipe-images', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "recipe_images_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'recipe-images');
