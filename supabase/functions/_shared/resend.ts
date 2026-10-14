/** Resend API helper — server-side only (Edge Functions). */

const RESEND_API = 'https://api.resend.com/emails';

export interface SendEmailOptions {
  to: string;
  subject: string;
  html: string;
  from?: string;
  replyTo?: string;
  headers?: Record<string, string>;
}

export async function sendViaResend(opts: SendEmailOptions): Promise<void> {
  const apiKey = Deno.env.get('RESEND_API_KEY');
  if (!apiKey) {
    throw new Error('RESEND_API_KEY is not configured in Edge Function secrets.');
  }

  const from = opts.from ??
    Deno.env.get('RESEND_FROM') ??
    'Quillo <hello@quilloai.co.uk>';

  const res = await fetch(RESEND_API, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [opts.to],
      subject: opts.subject,
      html: opts.html,
      reply_to: opts.replyTo ?? 'hello@quilloai.co.uk',
      headers: opts.headers,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend error ${res.status}: ${body}`);
  }
}
