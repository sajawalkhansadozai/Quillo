-- Hourly cron → Balanced Notifications edge functions (emails + pushes).
-- Auth: x-email-cron-secret from vault secret named `email_cron_secret`
--   OR Authorization Bearer = service_role (also accepted by the functions).
--
-- One-time vault setup (if not already present):
--   select vault.create_secret('YOUR_EMAIL_CRON_SECRET', 'email_cron_secret');

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

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

CREATE OR REPLACE FUNCTION public.invoke_process_scheduled_emails()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_secret text;
  v_request_id bigint;
BEGIN
  SELECT ds.decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'email_cron_secret'
  LIMIT 1;

  IF v_secret IS NULL OR length(v_secret) = 0 THEN
    RAISE WARNING 'vault secret email_cron_secret missing — skip process-scheduled-emails';
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url := 'https://klvzgfheneyqrwfxtfyg.supabase.co/functions/v1/process-scheduled-emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-email-cron-secret', v_secret
    ),
    body := '{}'::jsonb
  ) INTO v_request_id;

  RETURN v_request_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invoke_process_scheduled_pushes()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_secret text;
  v_request_id bigint;
BEGIN
  SELECT ds.decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'email_cron_secret'
  LIMIT 1;

  IF v_secret IS NULL OR length(v_secret) = 0 THEN
    RAISE WARNING 'vault secret email_cron_secret missing — skip process-scheduled-pushes';
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url := 'https://klvzgfheneyqrwfxtfyg.supabase.co/functions/v1/process-scheduled-pushes',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-email-cron-secret', v_secret
    ),
    body := '{}'::jsonb
  ) INTO v_request_id;

  RETURN v_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.invoke_process_scheduled_emails() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.invoke_process_scheduled_pushes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invoke_process_scheduled_emails() TO postgres;
GRANT EXECUTE ON FUNCTION public.invoke_process_scheduled_pushes() TO postgres;

DO $$
DECLARE
  existing_jobid bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron missing — schedule jobs manually in Dashboard';
    RETURN;
  END IF;

  SELECT jobid INTO existing_jobid
  FROM cron.job
  WHERE jobname = 'process-scheduled-emails-hourly'
  LIMIT 1;
  IF existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(existing_jobid);
  END IF;

  PERFORM cron.schedule(
    'process-scheduled-emails-hourly',
    '0 * * * *',
    $cron$SELECT public.invoke_process_scheduled_emails();$cron$
  );

  SELECT jobid INTO existing_jobid
  FROM cron.job
  WHERE jobname = 'process-scheduled-pushes-hourly'
  LIMIT 1;
  IF existing_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(existing_jobid);
  END IF;

  PERFORM cron.schedule(
    'process-scheduled-pushes-hourly',
    '5 * * * *',
    $cron$SELECT public.invoke_process_scheduled_pushes();$cron$
  );
END;
$$;
