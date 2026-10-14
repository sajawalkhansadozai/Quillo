// QA helper: send welcome / nudge / milestone emails via Resend.
// Header: x-test-secret: <TEST_MILESTONE_SECRET>
// Body: { "to": "...", "type": "welcome"|"nudge"|"milestone", ... }

import { sendViaResend } from '../_shared/resend.ts';
import {
  buildMilestoneEmail,
  buildNudgeEmail,
  buildWelcomeEmail,
} from '../_shared/email_templates.ts';

const WASTE_DEEP_LINK = Deno.env.get('QUILLO_WASTE_DEEP_LINK') ??
  'quillo://waste';
const SCAN_DEEP_LINK = Deno.env.get('QUILLO_SCAN_DEEP_LINK') ?? 'quillo://scan';
const UNSUBSCRIBE_URL = Deno.env.get('QUILLO_UNSUBSCRIBE_URL') ??
  'https://quilloai.co.uk/unsubscribe';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type, x-test-secret',
      },
    });
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const expected = Deno.env.get('TEST_MILESTONE_SECRET') ?? '';
  const provided = req.headers.get('x-test-secret') ?? '';
  if (!expected || provided !== expected) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: {
    to?: string;
    type?: string;
    threshold?: number;
    moneySavedGbp?: number;
    kgAvoided?: number;
    fullName?: string;
  };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const to = (body.to ?? '').trim();
  if (!to || !to.includes('@')) {
    return new Response(JSON.stringify({ error: 'to email required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const type = (body.type ?? 'milestone').toLowerCase();
  const fullName = body.fullName ?? 'Sarah';

  let subject = '';
  let html = '';

  if (type === 'welcome') {
    ({ subject, html } = buildWelcomeEmail({
      email: to,
      fullName,
      confirmUrl: 'quillo://home',
      unsubscribeUrl: UNSUBSCRIBE_URL,
    }));
  } else if (type === 'nudge') {
    ({ subject, html } = buildNudgeEmail({
      email: to,
      fullName,
      scanDeepLink: SCAN_DEEP_LINK,
      unsubscribeUrl: UNSUBSCRIBE_URL,
    }));
  } else {
    const threshold = Number(body.threshold ?? 50);
    const moneySavedGbp = Number(body.moneySavedGbp ?? 87.4);
    const kgAvoided = Number(body.kgAvoided ?? 42.6);
    ({ subject, html } = buildMilestoneEmail({
      email: to,
      fullName,
      threshold,
      moneySavedGbp,
      kgAvoided,
      openDeepLink: WASTE_DEEP_LINK,
      unsubscribeUrl: UNSUBSCRIBE_URL,
    }));
  }

  try {
    await sendViaResend({
      to,
      subject,
      html,
      headers: { 'List-Unsubscribe': `<${UNSUBSCRIBE_URL}>` },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({
        error: e instanceof Error ? e.message : String(e),
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true, to, type, subject }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
