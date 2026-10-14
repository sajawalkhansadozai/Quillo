// BlindSpots 6.1 — delete receipt images older than 90 days via Storage API.
// SQL cannot DELETE storage.objects directly (protect_delete trigger).
// Secure with PURGE_CRON_SECRET (x-purge-secret) or service-role JWT.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-purge-secret',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const purgeSecret = Deno.env.get('PURGE_CRON_SECRET') ?? '';

    const authHeader = req.headers.get('Authorization') ?? '';
    const providedSecret = req.headers.get('x-purge-secret') ?? '';
    const bearer = authHeader.startsWith('Bearer ')
      ? authHeader.slice('Bearer '.length)
      : '';

    const allowed =
      (purgeSecret && providedSecret === purgeSecret) ||
      (bearer && bearer === serviceRoleKey);

    if (!allowed) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let retentionDays = 90;
    try {
      const body = await req.json();
      if (typeof body?.retention_days === 'number') {
        retentionDays = Math.max(1, Math.min(365, body.retention_days));
      }
    } catch {
      // empty body is fine
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const { data: rows, error: listError } = await admin.rpc(
      'list_old_receipt_image_paths',
      { p_retention_days: retentionDays },
    );

    if (listError) {
      console.error('list_old_receipt_image_paths failed:', listError.message);
      return new Response(JSON.stringify({ error: listError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const paths = (rows ?? [])
      .map((r: { object_path?: string }) => r.object_path)
      .filter((p: string | undefined): p is string => !!p && p.length > 0);

    let storageDeleted = 0;
    const chunkSize = 100;
    for (let i = 0; i < paths.length; i += chunkSize) {
      const chunk = paths.slice(i, i + chunkSize);
      const { error: removeError } = await admin.storage
        .from('receipt-images')
        .remove(chunk);
      if (removeError) {
        console.error('storage.remove failed:', removeError.message);
      } else {
        storageDeleted += chunk.length;
      }
    }

    const { data: scansCleared, error: clearError } = await admin.rpc(
      'clear_old_scan_receipt_urls',
      { p_retention_days: retentionDays },
    );
    if (clearError) {
      console.warn('clear_old_scan_receipt_urls failed:', clearError.message);
    }

    return new Response(
      JSON.stringify({
        ok: true,
        retention_days: retentionDays,
        candidates: paths.length,
        storage_objects_deleted: storageDeleted,
        scan_image_urls_cleared: scansCleared ?? 0,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('purge-receipt-images error:', err);
    return new Response(JSON.stringify({ error: 'Purge failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
