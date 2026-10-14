// Balanced Notifications — 3 push types (expiry, streak, milestone).
// Priority when multiple fire: streak > expiry > milestone (max 1/day).
// Deploy: supabase functions deploy process-scheduled-pushes --no-verify-jwt
// Schedule hourly. Secrets: ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY, EMAIL_CRON_SECRET

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  ingredientAllowedForDiet,
  isWithinPushWindow,
  sendOneSignalPush,
} from '../_shared/onesignal.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-email-cron-secret',
};

type StreakRow = {
  user_id: string;
  week_streak: number;
  timezone: string;
  week_key: string;
};

type ExpiryRow = {
  user_id: string;
  ingredient_name: string;
  timezone: string;
  dietary_labels: string[] | null;
};

type MilestoneRow = {
  user_id: string;
  threshold: number;
  money_saved: number;
  kg_avoided: number;
  timezone: string;
};

function authorised(req: Request, serviceRoleKey: string): boolean {
  const cronSecret = Deno.env.get('EMAIL_CRON_SECRET') ?? '';
  const provided = req.headers.get('x-email-cron-secret') ?? '';
  const authHeader = req.headers.get('Authorization') ?? '';
  const bearer = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length)
    : '';
  return (cronSecret.length > 0 && provided === cronSecret) ||
    (bearer.length > 0 && bearer === serviceRoleKey);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  if (!authorised(req, serviceRoleKey)) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);
  const sentToday = new Set<string>();
  const results = {
    streak_sent: 0,
    expiry_sent: 0,
    milestone_sent: 0,
    skipped_quiet: 0,
    skipped_diet: 0,
    errors: [] as string[],
  };

  try {
    // Priority 1 — streak at risk
    const { data: streakRows, error: streakErr } = await admin.rpc(
      'list_streak_push_candidates',
    );
    if (streakErr) throw new Error(streakErr.message);

    for (const row of (streakRows ?? []) as StreakRow[]) {
      if (sentToday.has(row.user_id)) continue;
      if (!isWithinPushWindow(row.timezone)) {
        results.skipped_quiet++;
        continue;
      }
      try {
        await sendOneSignalPush({
          externalUserId: row.user_id,
          heading: 'Your streak is at risk',
          body:
            `You have a ${row.week_streak}-week streak — scan a receipt this week to keep it going.`,
          data: { screen: 'scan' },
        });
        await admin.rpc('mark_streak_push_sent', {
          p_user_id: row.user_id,
          p_week_key: row.week_key,
        });
        sentToday.add(row.user_id);
        results.streak_sent++;
      } catch (e) {
        results.errors.push(
          `streak ${row.user_id}: ${e instanceof Error ? e.message : e}`,
        );
      }
    }

    // Priority 2 — ingredient expiry
    const { data: expiryRows, error: expiryErr } = await admin.rpc(
      'list_expiry_push_candidates',
    );
    if (expiryErr) throw new Error(expiryErr.message);

    for (const row of (expiryRows ?? []) as ExpiryRow[]) {
      if (sentToday.has(row.user_id)) continue;
      if (!isWithinPushWindow(row.timezone)) {
        results.skipped_quiet++;
        continue;
      }
      const labels = row.dietary_labels ?? [];
      if (!ingredientAllowedForDiet(row.ingredient_name, labels)) {
        results.skipped_diet++;
        continue;
      }
      try {
        await sendOneSignalPush({
          externalUserId: row.user_id,
          heading: 'Use it soon',
          body: `Your ${row.ingredient_name} might go off tonight. Tap for recipe ideas.`,
          data: {
            screen: 'explore',
            ingredient: row.ingredient_name,
          },
        });
        await admin.rpc('mark_expiry_push_sent', {
          p_user_id: row.user_id,
          p_ingredient: row.ingredient_name,
        });
        sentToday.add(row.user_id);
        results.expiry_sent++;
      } catch (e) {
        results.errors.push(
          `expiry ${row.user_id}: ${e instanceof Error ? e.message : e}`,
        );
      }
    }

    // Priority 3 — milestone unlocked
    const { data: mileRows, error: mileErr } = await admin.rpc(
      'list_milestone_push_candidates',
    );
    if (mileErr) throw new Error(mileErr.message);

    for (const row of (mileRows ?? []) as MilestoneRow[]) {
      if (sentToday.has(row.user_id)) continue;
      if (!isWithinPushWindow(row.timezone)) {
        results.skipped_quiet++;
        continue;
      }
      try {
        const kg = Number(row.kg_avoided).toFixed(0);
        await sendOneSignalPush({
          externalUserId: row.user_id,
          heading: `You just saved £${row.threshold} with Quillo`,
          body: `That's about ${kg} kg of food waste avoided. See your impact.`,
          data: { screen: 'waste' },
        });
        await admin.rpc('mark_milestone_push_sent', {
          p_user_id: row.user_id,
          p_threshold: Number(row.threshold),
        });
        sentToday.add(row.user_id);
        results.milestone_sent++;
      } catch (e) {
        results.errors.push(
          `milestone ${row.user_id}: ${e instanceof Error ? e.message : e}`,
        );
      }
    }

    return new Response(JSON.stringify({ ok: true, ...results }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('process-scheduled-pushes error:', e);
    return new Response(
      JSON.stringify({
        error: e instanceof Error ? e.message : 'Unexpected error',
        ...results,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
