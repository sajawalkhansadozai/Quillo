-- Fix 6.1: storage.objects DELETE is blocked; list paths for Storage API purge
-- and keep automated scan URL cleanup in SQL / cron.

CREATE OR REPLACE FUNCTION public.list_old_receipt_image_paths(
  p_retention_days int DEFAULT 90
)
RETURNS TABLE(object_path text, created_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = storage, public
AS $$
  SELECT o.name::text, o.created_at
  FROM storage.objects o
  WHERE o.bucket_id = 'receipt-images'
    AND o.created_at < now() - make_interval(
      days => greatest(coalesce(p_retention_days, 90), 1)
    )
  ORDER BY o.created_at ASC
  LIMIT 5000;
$$;

CREATE OR REPLACE FUNCTION public.clear_old_scan_receipt_urls(
  p_retention_days int DEFAULT 90
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cleared int := 0;
BEGIN
  WITH cleared AS (
    UPDATE public.scans s
    SET image_url = NULL
    WHERE s.image_url IS NOT NULL
      AND s.scan_date < now() - make_interval(
        days => greatest(coalesce(p_retention_days, 90), 1)
      )
    RETURNING 1
  )
  SELECT count(*)::int INTO v_cleared FROM cleared;
  RETURN v_cleared;
END;
$$;

-- Keep name used by cron / edge: clears scan URLs only.
-- Actual file deletion is done by the purge-receipt-images Edge Function.
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
  v_paths int := 0;
  v_scans int := 0;
BEGIN
  SELECT count(*)::int INTO v_paths
  FROM public.list_old_receipt_image_paths(v_days);

  v_scans := public.clear_old_scan_receipt_urls(v_days);

  RETURN jsonb_build_object(
    'retention_days', v_days,
    'pending_storage_objects', v_paths,
    'scan_image_urls_cleared', v_scans,
    'note', 'Call purge-receipt-images Edge Function to delete storage files via Storage API'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.list_old_receipt_image_paths(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.clear_old_scan_receipt_urls(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purge_old_receipt_images(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_old_receipt_image_paths(int) TO service_role;
GRANT EXECUTE ON FUNCTION public.clear_old_scan_receipt_urls(int) TO service_role;
GRANT EXECUTE ON FUNCTION public.purge_old_receipt_images(int) TO service_role;

-- Ensure daily cron still runs scan URL cleanup (storage files via edge / dashboard schedule).
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
    RAISE NOTICE 'Could not reschedule purge-receipt-images-daily: %', SQLERRM;
END;
$$;
