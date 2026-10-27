-- Smart pantry cloud sync (device-local SQLite remains primary offline cache).

CREATE TABLE IF NOT EXISTS public.user_pantry_items (
  id          text        NOT NULL,
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  data        jsonb       NOT NULL DEFAULT '{}'::jsonb,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,
  PRIMARY KEY (user_id, id)
);

CREATE INDEX IF NOT EXISTS user_pantry_items_user_updated_idx
  ON public.user_pantry_items (user_id, updated_at DESC);

ALTER TABLE public.user_pantry_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_pantry_items_select_own ON public.user_pantry_items;
CREATE POLICY user_pantry_items_select_own
  ON public.user_pantry_items FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_pantry_items_insert_own ON public.user_pantry_items;
CREATE POLICY user_pantry_items_insert_own
  ON public.user_pantry_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_pantry_items_update_own ON public.user_pantry_items;
CREATE POLICY user_pantry_items_update_own
  ON public.user_pantry_items FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_pantry_items_delete_own ON public.user_pantry_items;
CREATE POLICY user_pantry_items_delete_own
  ON public.user_pantry_items FOR DELETE
  USING (auth.uid() = user_id);

COMMENT ON TABLE public.user_pantry_items IS
  'Per-user smart pantry inventory mirrored from the app for multi-device sync.';
