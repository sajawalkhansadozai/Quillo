// Welcome Email §01–§02 — Supabase Auth Send Email Hook → branded Email 1 via Resend.
// Deploy with: supabase functions deploy send-welcome-email --no-verify-jwt
// Dashboard: Authentication → Hooks → Send Email → this function URL
// Secrets: RESEND_API_KEY, SEND_EMAIL_HOOK_SECRET

import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0';
import { sendViaResend } from '../_shared/resend.ts';
import {
  buildConfirmUrl,
  buildTransactionalEmail,
  buildWelcomeEmail,
} from '../_shared/email_templates.ts';

type HookPayload = {
  user: {
    email: string;
    user_metadata?: { full_name?: string };
  };
  email_data: {
    token: string;
    token_hash: string;
    redirect_to?: string;
    email_action_type: string;
    site_url?: string;
  };
};

function hookSecret(): string {
  const raw = Deno.env.get('SEND_EMAIL_HOOK_SECRET') ?? '';
  return raw.replace(/^v1,whsec_/, '');
}

function transactionalSubject(action: string): string {
  switch (action) {
    case 'recovery':
      return 'Reset your Quillo password';
    case 'magiclink':
      return 'Your Quillo sign-in link';
    case 'invite':
      return "You're invited to Quillo";
    case 'email_change':
      return 'Confirm your new Quillo email';
    default:
      return 'Quillo account notification';
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const secret = hookSecret();
  if (!secret) {
    return new Response(
      JSON.stringify({ error: { message: 'SEND_EMAIL_HOOK_SECRET not configured' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const payloadText = await req.text();
  const headers = Object.fromEntries(req.headers.entries());

  let payload: HookPayload;
  try {
    const wh = new Webhook(secret);
    payload = wh.verify(payloadText, headers) as HookPayload;
  } catch (e) {
    console.error('Webhook verify failed:', e);
    return new Response(
      JSON.stringify({ error: { message: 'Invalid hook signature' } }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const confirmRedirect = Deno.env.get('QUILLO_CONFIRM_REDIRECT') ??
    'quillo://home';
  const { user, email_data } = payload;
  const confirmUrl = buildConfirmUrl(
    supabaseUrl,
    email_data,
    confirmRedirect,
  );
  const action = email_data.email_action_type;

  try {
    if (action === 'signup') {
      const { subject, html } = buildWelcomeEmail({
        email: user.email,
        fullName: user.user_metadata?.full_name,
        confirmUrl,
      });
      await sendViaResend({
        to: user.email,
        subject,
        html,
        headers: {
          'List-Unsubscribe': '<mailto:hello@quilloai.co.uk?subject=unsubscribe>',
        },
      });
    } else {
      const title = transactionalSubject(action);
      const html = buildTransactionalEmail({
        title,
        bodyHtml: action === 'recovery'
          ? 'We received a request to reset your password. Tap below to choose a new one.'
          : 'Please confirm this action using the button below.',
        actionUrl: confirmUrl,
        actionLabel: action === 'recovery' ? 'Reset password' : 'Continue',
      });
      await sendViaResend({
        to: user.email,
        subject: title,
        html,
      });
    }

    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('send-welcome-email failed:', e);
    return new Response(
      JSON.stringify({
        error: {
          message: e instanceof Error ? e.message : 'Failed to send email',
        },
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
