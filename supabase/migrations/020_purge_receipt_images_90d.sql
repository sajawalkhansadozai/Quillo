-- BlindSpots 6.1 — receipt image retention helpers.
-- NOTE: Direct DELETE on storage.objects is blocked by Supabase.
-- File deletion is performed by the purge-receipt-images Edge Function (Storage API).
-- Migration 021 adds list/clear helpers used by that function.

CREATE OR REPLACE FUNCTION public.purge_old_receipt_images(
  p_retention_days int DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_days int := greatest(coalesce(p_retention_days, 90), 1);
  v_scans_cleared int := 0;
BEGIN
  WITH cleared AS (
    UPDATE public.scans s
    SET image_url = NULL
    WHERE s.image_url IS NOT NULL
      AND s.scan_date < now() - make_interval(days => v_days)
    RETURNING 1
  )
  SELECT count(*)::int INTO v_scans_cleared FROM cleared;

  RETURN jsonb_build_object(
    'retention_days', v_days,
    'scan_image_urls_cleared', v_scans_cleared,
    'note', 'Storage files deleted by purge-receipt-images Edge Function'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.purge_old_receipt_images(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_old_receipt_images(int) TO service_role;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
EXCEPTION
  WHEN OTHERS THEN
    BEGIN
      CREATE EXTENSION IF NOT EXISTS pg_cron;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron not available: %', SQLERRM;
    END;
END;
$$;

DO $$
DECLARE
  existing_jobid bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    SELECT jobid INTO existing_jobid
    FROM cron.job
    WHERE jobname = 'purge-receipt-images-daily'
    LIMIT 1;

    IF existing_jobid IS NOT NULL THEN
      PERFORM cron.unschedule(existing_jobid);
    END IF;

    PERFORM cron.schedule(
      'purge-receipt-images-daily',
      '0 3 * * *',
      $cron$SELECT public.purge_old_receipt_images(90);$cron$
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Could not schedule purge-receipt-images-daily: %', SQLERRM;
END;
$$;
