// Balanced Notifications — Emails 2–4 (nudge, milestone, monthly summary).
// Deploy: supabase functions deploy process-scheduled-emails --no-verify-jwt
// Schedule hourly. Secrets: RESEND_API_KEY, EMAIL_CRON_SECRET

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendViaResend } from '../_shared/resend.ts';
import {
  buildNudgeEmail,
  buildMilestoneEmail,
  buildMonthlySummaryEmail,
} from '../_shared/email_templates.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-email-cron-secret',
};

const SCAN_DEEP_LINK = Deno.env.get('QUILLO_SCAN_DEEP_LINK') ?? 'quillo://scan';
const WASTE_DEEP_LINK = Deno.env.get('QUILLO_WASTE_DEEP_LINK') ??
  'quillo://waste';
const UNSUBSCRIBE_URL = Deno.env.get('QUILLO_UNSUBSCRIBE_URL') ??
  'https://quilloai.co.uk/unsubscribe';

type NudgeRow = {
  user_id: string;
  email: string;
  first_name: string | null;
};

type MilestoneRow = {
  user_id: string;
  email: string;
  first_name: string | null;
  threshold: number;
  money_saved: number;
  kg_avoided: number;
};

type MonthlyRow = {
  user_id: string;
  email: string;
  first_name: string | null;
  month_name: string;
  ym: string;
  scan_count: number;
  money_saved: number;
  kg_avoided: number;
  week_streak: number;
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
  const results = {
    nudge_sent: 0,
    nudge_errors: [] as string[],
    disengaged: 0,
    milestone_sent: 0,
    milestone_errors: [] as string[],
    monthly_sent: 0,
    monthly_errors: [] as string[],
  };

  try {
    // 1.5 — mark Email 2 non-openers (proxy: still zero scans after 72h)
    const { data: disengagedCount, error: disErr } = await admin.rpc(
      'mark_nudge_disengaged_candidates',
    );
    if (disErr) {
      console.error('mark_nudge_disengaged_candidates:', disErr.message);
    } else {
      results.disengaged = Number(disengagedCount ?? 0);
    }

    // Email 2 — 24h scan nudge
    const { data: nudgeRows, error: nudgeListErr } = await admin.rpc(
      'list_nudge_email_candidates',
    );
    if (nudgeListErr) {
      throw new Error(`list_nudge_email_candidates: ${nudgeListErr.message}`);
    }

    for (const row of (nudgeRows ?? []) as NudgeRow[]) {
      try {
        const { subject, html } = buildNudgeEmail({
          email: row.email,
          fullName: row.first_name,
          scanDeepLink: SCAN_DEEP_LINK,
          unsubscribeUrl: UNSUBSCRIBE_URL,
        });
        await sendViaResend({
          to: row.email,
          subject,
          html,
          headers: {
            'List-Unsubscribe': `<${UNSUBSCRIBE_URL}>`,
          },
        });

        const { error: markErr } = await admin.rpc('mark_nudge_email_sent', {
          p_user_id: row.user_id,
        });
        if (markErr) throw new Error(markErr.message);
        results.nudge_sent++;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        results.nudge_errors.push(`${row.user_id}: ${msg}`);
      }
    }

    // Email 3 — milestones £50 / £100 / £250
    const { data: milestoneRows, error: mileErr } = await admin.rpc(
      'list_milestone_email_candidates',
    );
    if (mileErr) {
      throw new Error(`list_milestone_email_candidates: ${mileErr.message}`);
    }

    for (const row of (milestoneRows ?? []) as MilestoneRow[]) {
      try {
        const { subject, html } = buildMilestoneEmail({
          email: row.email,
          fullName: row.first_name,
          threshold: Number(row.threshold),
          moneySavedGbp: Number(row.money_saved),
          kgAvoided: Number(row.kg_avoided),
          openDeepLink: WASTE_DEEP_LINK,
          unsubscribeUrl: UNSUBSCRIBE_URL,
        });
        await sendViaResend({
          to: row.email,
          subject,
          html,
          headers: { 'List-Unsubscribe': `<${UNSUBSCRIBE_URL}>` },
        });

        const { error: markErr } = await admin.rpc('mark_milestone_email_sent', {
          p_user_id: row.user_id,
          p_threshold: Number(row.threshold),
        });
        if (markErr) throw new Error(markErr.message);
        results.milestone_sent++;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        results.milestone_errors.push(`${row.user_id}: ${msg}`);
      }
    }

    // Email 4 — monthly summary (first Monday only; RPC returns empty otherwise)
    const { data: monthlyRows, error: monthErr } = await admin.rpc(
      'list_monthly_summary_candidates',
    );
    if (monthErr) {
      throw new Error(`list_monthly_summary_candidates: ${monthErr.message}`);
    }

    for (const row of (monthlyRows ?? []) as MonthlyRow[]) {
      try {
        const { subject, html } = buildMonthlySummaryEmail({
          email: row.email,
          fullName: row.first_name,
          monthName: row.month_name,
          scanCount: Number(row.scan_count),
          moneySavedGbp: Number(row.money_saved),
          kgAvoided: Number(row.kg_avoided),
          streak: Number(row.week_streak),
          openDeepLink: WASTE_DEEP_LINK,
          unsubscribeUrl: UNSUBSCRIBE_URL,
        });
        await sendViaResend({
          to: row.email,
          subject,
          html,
          headers: { 'List-Unsubscribe': `<${UNSUBSCRIBE_URL}>` },
        });

        const { error: markErr } = await admin.rpc('mark_monthly_summary_sent', {
          p_user_id: row.user_id,
          p_ym: row.ym,
        });
        if (markErr) throw new Error(markErr.message);
        results.monthly_sent++;
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        results.monthly_errors.push(`${row.user_id}: ${msg}`);
      }
    }

    return new Response(JSON.stringify({ ok: true, ...results }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('process-scheduled-emails error:', e);
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
