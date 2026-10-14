// Permanently delete the authenticated user's account and associated data.
// Called from Profile → Delete Account.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

async function removeStoragePrefix(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<number> {
  let removed = 0;
  const { data: entries, error } = await admin.storage.from(bucket).list(prefix, {
    limit: 1000,
  });
  if (error || !entries?.length) return 0;

  const files = entries
    .filter((e) => e.name && e.id != null)
    .map((e) => `${prefix}/${e.name}`);

  // Nested folders (rare for receipts) — list one level deeper.
  const folders = entries.filter((e) => e.id == null && e.name);
  for (const folder of folders) {
    const { data: nested } = await admin.storage
      .from(bucket)
      .list(`${prefix}/${folder.name}`, { limit: 1000 });
    for (const n of nested ?? []) {
      if (n.name) files.push(`${prefix}/${folder.name}/${n.name}`);
    }
  }

  if (files.length === 0) return 0;
  const { error: removeError } = await admin.storage.from(bucket).remove(files);
  if (!removeError) removed = files.length;
  return removed;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await userClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const uid = user.id;

    // Storage first (needs uid), then DB rows via CASCADE from auth delete.
    const receiptRemoved = await removeStoragePrefix(admin, 'receipt-images', uid);
    const avatarRemoved = await removeStoragePrefix(admin, 'avatars', uid);

    // Explicit public.users delete for clarity; auth delete also cascades.
    await admin.from('users').delete().eq('id', uid);

    const { error: deleteAuthError } = await admin.auth.admin.deleteUser(uid);
    if (deleteAuthError) {
      console.error('auth.admin.deleteUser failed:', deleteAuthError.message);
      return new Response(
        JSON.stringify({
          error: 'Could not delete account. Please try again or contact support.',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    console.log(
      `delete-account: uid=${uid} receipts=${receiptRemoved} avatars=${avatarRemoved}`,
    );

    return new Response(
      JSON.stringify({
        ok: true,
        receipt_files_removed: receiptRemoved,
        avatar_files_removed: avatarRemoved,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('delete-account error:', err);
    return new Response(JSON.stringify({ error: 'Account deletion failed' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
