/** Quillo transactional emails — live HTML matching Anthony mockups. */

const PURPLE = '#3D1C8C';
const PURPLE_DARK = '#2E1570';
const PURPLE_SOFT = '#F3EEFF';
const PURPLE_CARD = '#EDE7F6';
const GREEN_HEADER = '#1B4332';
const GREEN_CARD = '#E8F5E9';
const GREEN_TEXT = '#2E7D32';
const INK = '#1A1A1A';
const MUTED = '#6B7280';
const LIME = '#C6F34A';

const SITE = 'https://quilloai.co.uk';
const SOCIAL = 'https://www.instagram.com/quillo.ai';

function firstName(raw: string | null | undefined, email: string): string {
  const n = (raw ?? '').trim();
  if (n.length > 0) return n.split(/\s+/)[0]!;
  const local = email.split('@')[0] ?? 'there';
  const stripped = local.replace(/[^a-zA-Z].*$/, '');
  if (stripped.length < 2) return 'there';
  return stripped.charAt(0).toUpperCase() + stripped.slice(1).toLowerCase();
}

function moneyLabel(n: number): string {
  const rounded = Math.round(n * 100) / 100;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(2);
}

function kgLabel(n: number): string {
  const rounded = Math.round(n * 10) / 10;
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
}

function emailFooter(unsubscribeUrl?: string): string {
  const unsub = unsubscribeUrl ?? `${SITE}/unsubscribe`;
  const year = new Date().getFullYear();
  return `
<tr>
  <td style="padding:28px 22px 32px 22px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:${MUTED};text-align:center;">
    <a href="${SITE}" style="color:#6C63FF;text-decoration:none;font-weight:700;">quilloai.co.uk</a>
    &nbsp;·&nbsp;
    <a href="${SOCIAL}" style="color:#6C63FF;text-decoration:none;font-weight:700;">@Quillo.ai</a>
    &nbsp;·&nbsp;
    <a href="${unsub}" style="color:${MUTED};text-decoration:underline;">Unsubscribe</a>
    <div style="margin-top:10px;">Reisen AI Ltd trading as Quillo · 66 Paul Street, London EC2A 4NA</div>
    <div style="margin-top:4px;">© ${year} Reisen AI Ltd. All rights reserved.</div>
  </td>
</tr>`;
}

function ctaButton(href: string, label: string, bg: string, color = '#ffffff'): string {
  return `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 0 0;">
  <tr>
    <td align="center" style="border-radius:28px;background:${bg};">
      <a href="${href}" style="display:block;padding:16px 22px;font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:800;color:${color};text-decoration:none;">
        ${label}
      </a>
    </td>
  </tr>
</table>`;
}

function featureRow(
  iconBg: string,
  icon: string,
  title: string,
  body: string,
): string {
  return `
<tr>
  <td style="padding:10px 0;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td width="48" valign="top">
          <div style="width:40px;height:40px;line-height:40px;text-align:center;border-radius:12px;background:${iconBg};color:${PURPLE};font-size:16px;font-weight:900;font-family:Arial,Helvetica,sans-serif;">${icon}</div>
        </td>
        <td valign="top" style="padding-left:10px;font-family:Arial,Helvetica,sans-serif;">
          <div style="color:${INK};font-size:14px;font-weight:800;line-height:1.3;">${title}</div>
          <div style="margin-top:3px;color:${MUTED};font-size:13px;line-height:1.45;font-weight:500;">${body}</div>
        </td>
      </tr>
    </table>
  </td>
</tr>`;
}

function wrapEmail(opts: {
  preheader: string;
  title: string;
  bodyRows: string;
  unsubscribeUrl?: string;
}): string {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>${opts.title}</title>
</head>
<body style="margin:0;padding:0;background:#f3f4f6;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${opts.preheader}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f3f4f6;">
    <tr>
      <td align="center" style="padding:20px 10px;">
        <table role="presentation" width="440" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:440px;background:#ffffff;border-radius:20px;overflow:hidden;">
          ${opts.bodyRows}
          ${emailFooter(opts.unsubscribeUrl)}
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/** Email 1 — Welcome + confirm */
function welcomeAsset(file: string): string {
  const base = (Deno.env.get('EMAIL_ASSET_BASE_URL') ??
    'https://klvzgfheneyqrwfxtfyg.supabase.co/storage/v1/object/public/email-assets')
    .replace(/\/$/, '');
  return `${base}/welcome-card/${file}`;
}

/** Email 1 — Welcome + confirm (quillo-welcome-card design) */
export function buildWelcomeEmail(opts: {
  email: string;
  fullName?: string | null;
  confirmUrl: string;
  unsubscribeUrl?: string;
  homeDeepLink?: string;
}): { subject: string; html: string } {
  const name = firstName(opts.fullName, opts.email);
  const home = opts.homeDeepLink ?? 'quillo://home';
  const unsub = opts.unsubscribeUrl ?? `${SITE}/unsubscribe`;
  const subject = `Welcome to Quillo, ${name}`;
  const bowl = welcomeAsset('foodbowl.png');
  const bag = welcomeAsset('bag.png');

  const ink = '#241456';
  const purpleTop = '#2f1d72';
  const purpleBot = '#241456';
  const btn = '#5a2fd6';
  const box = '#ece9f5';
  const muted = '#8a86a0';
  const footBg = '#eceaf3';
  const hand = '#2d1a6b';

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>${subject}</title>
</head>
<body style="margin:0;padding:0;background:#f1f1f6;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
    Confirm your email and unlock your first Quillo scans.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f1f1f6;">
    <tr>
      <td align="center" style="padding:24px 10px;">
        <table role="presentation" width="360" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:360px;background:#ffffff;border-radius:6px;overflow:hidden;">

          <!-- HEADER -->
          <tr>
            <td style="background-color:${purpleBot};background:linear-gradient(160deg,${purpleTop},${purpleBot});padding:0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td valign="top" style="padding:22px 8px 26px 22px;width:58%;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="left" style="font-family:Arial,Helvetica,sans-serif;">
                          <a href="${home}" style="color:#ffffff;font-size:20px;font-weight:800;text-decoration:none;letter-spacing:0.3px;">Quillo</a>
                        </td>
                        <td align="right" style="font-family:Georgia,'Segoe Script',cursive;color:#d9d3f2;font-size:13px;font-style:italic;line-height:1.15;font-weight:600;">
                          Receipts to<br>recipes for a<br>brighter tomorrow
                        </td>
                      </tr>
                    </table>
                    <div style="margin-top:26px;font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:24px;line-height:1.2;font-weight:800;letter-spacing:-0.3px;">
                      Welcome to Quillo, ${name}
                    </div>
                    <p style="margin:12px 0 0;font-family:Arial,Helvetica,sans-serif;color:#d3cdec;font-size:12px;line-height:1.5;">
                      You're in. Let's turn your grocery receipts into great meals.
                    </p>
                  </td>
                  <td valign="bottom" align="right" style="padding:16px 0 0 0;width:42%;">
                    <img src="${bowl}" width="140" height="140" alt="" style="display:block;margin:0 0 0 auto;width:140px;height:140px;border-radius:70px;object-fit:cover;">
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- BODY / CTA -->
          <tr>
            <td style="padding:22px 22px 6px 22px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;">
              <p style="margin:0;color:#3a3652;font-size:13.5px;line-height:1.55;">
                Please confirm your email address to get started and unlock your first scans.
              </p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:18px;">
                <tr>
                  <td align="center" style="border-radius:30px;background:${btn};">
                    <a href="${opts.confirmUrl}" style="display:block;padding:15px 18px;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:700;color:#ffffff;text-decoration:none;">
                      Confirm my email →
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin:14px 0 0;text-align:center;color:${muted};font-size:10.5px;line-height:1.5;">
                This link expires in 24 hours. If you didn't create a Quillo account, you can safely ignore this email.
              </p>
              <div style="height:1px;background:#eceaf1;margin:18px 0 0 0;line-height:1px;font-size:1px;">&nbsp;</div>
            </td>
          </tr>

          <!-- FEATURES -->
          <tr>
            <td style="padding:18px;background:#ffffff;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${box};border-radius:16px;">
                <tr>
                  <td style="padding:18px 16px 8px 16px;font-family:Arial,Helvetica,sans-serif;">
                    <div style="font-size:14px;font-weight:800;color:${ink};margin-bottom:14px;">What you can do with Quillo</div>

                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:14px;">
                      <tr>
                        <td width="48" valign="top">
                          <div style="width:38px;height:38px;line-height:38px;text-align:center;border-radius:11px;background:#ede4ff;color:#6a35d6;font-size:14px;font-weight:800;">⌁</div>
                        </td>
                        <td valign="top" style="padding-left:4px;">
                          <div style="font-size:13px;font-weight:800;color:${ink};">Scan any receipt</div>
                          <div style="margin-top:3px;font-size:11.5px;color:#6f6b85;line-height:1.45;">Turn your grocery shop into recipe ideas in seconds.</div>
                        </td>
                      </tr>
                    </table>

                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:14px;">
                      <tr>
                        <td width="48" valign="top">
                          <div style="width:38px;height:38px;line-height:38px;text-align:center;border-radius:11px;background:#d9f0cf;color:#4e9c4f;font-size:14px;font-weight:800;">◇</div>
                        </td>
                        <td valign="top" style="padding-left:4px;">
                          <div style="font-size:13px;font-weight:800;color:${ink};">Get personalised recipes</div>
                          <div style="margin-top:3px;font-size:11.5px;color:#6f6b85;line-height:1.45;">Tailored to your diet, household size, and cooking time.</div>
                        </td>
                      </tr>
                    </table>

                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:10px;">
                      <tr>
                        <td width="48" valign="top">
                          <div style="width:38px;height:38px;line-height:38px;text-align:center;border-radius:11px;background:#ffe1cc;color:#ef8f3c;font-size:14px;font-weight:800;">▣</div>
                        </td>
                        <td valign="top" style="padding-left:4px;">
                          <div style="font-size:13px;font-weight:800;color:${ink};">Track your impact</div>
                          <div style="margin-top:3px;font-size:11.5px;color:#6f6b85;line-height:1.45;">See how much money and food waste you've saved over time.</div>
                        </td>
                      </tr>
                    </table>

                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:6px;">
                      <tr>
                        <td valign="middle" style="font-family:Georgia,'Segoe Script',cursive;color:${hand};font-size:22px;line-height:1.15;font-style:italic;font-weight:600;">
                          Good food<br>less waste<br>brighter days <span style="color:#7cc45f;">♥</span>
                        </td>
                        <td width="100" valign="middle" align="right">
                          <img src="${bag}" width="96" alt="" style="display:block;width:96px;height:auto;">
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="background:${footBg};padding:14px 18px;text-align:center;font-family:Arial,Helvetica,sans-serif;">
              <div style="font-size:10px;color:#3f3a5a;font-weight:600;line-height:1.7;">
                <a href="${SITE}" style="color:#3f3a5a;text-decoration:none;">quilloai.co.uk</a>
                <span style="color:#9a95b0;font-weight:400;margin:0 5px;">|</span>
                <a href="${SOCIAL}" style="color:#3f3a5a;text-decoration:none;">@Quillo.ai</a>
                <span style="color:#9a95b0;font-weight:400;margin:0 5px;">|</span>
                <a href="${unsub}" style="color:#3f3a5a;text-decoration:none;">Unsubscribe</a>
              </div>
              <div style="margin-top:4px;font-size:8.5px;color:#9a95b0;line-height:1.5;">
                Reisen AI Ltd trading as Quillo · 66 Paul Street, London EC2A 4NA
              </div>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { subject, html };
}

/** Auth Dashboard Go template — same live layout, ConfirmationURL placeholder. */
export function buildWelcomeEmailAuthTemplate(): string {
  const built = buildWelcomeEmail({
    email: 'you@example.com',
    fullName: 'there',
    confirmUrl: '{{ .ConfirmationURL }}',
  });
  return built.html.replace(/Welcome to Quillo, there/g, 'Welcome to Quillo');
}

export function buildTransactionalEmail(opts: {
  title: string;
  bodyHtml: string;
  actionUrl: string;
  actionLabel: string;
}): string {
  const bodyRows = `
<tr>
  <td style="background:${PURPLE};padding:22px;">
    <div style="font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:22px;font-weight:800;">Quillo</div>
  </td>
</tr>
<tr>
  <td style="padding:28px 22px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;color:#333;font-size:15px;line-height:1.6;">
    <h2 style="margin:0 0 12px;color:${INK};font-size:20px;font-weight:900;">${opts.title}</h2>
    <p style="margin:0 0 8px;">${opts.bodyHtml}</p>
    ${ctaButton(opts.actionUrl, opts.actionLabel, PURPLE)}
    <p style="margin:16px 0 0;color:${MUTED};font-size:13px;">If you did not request this, you can ignore this email.</p>
  </td>
</tr>`;
  return wrapEmail({
    preheader: opts.title,
    title: opts.title,
    bodyRows,
  });
}

/** Email 2 — 24h scan nudge */
function fridgeAsset(file: string): string {
  const base = (Deno.env.get('EMAIL_ASSET_BASE_URL') ??
    'https://klvzgfheneyqrwfxtfyg.supabase.co/storage/v1/object/public/email-assets')
    .replace(/\/$/, '');
  return `${base}/fridge-card/${file}`;
}

/** Email 2 — 24h scan nudge (quillo-fridge-card design) */
export function buildNudgeEmail(opts: {
  email: string;
  fullName?: string | null;
  scanDeepLink: string;
  unsubscribeUrl?: string;
  homeDeepLink?: string;
  freeScans?: number;
}): { subject: string; html: string } {
  const home = opts.homeDeepLink ?? 'quillo://home';
  const freeScans = opts.freeScans ?? 2;
  const unsub = opts.unsubscribeUrl ?? `${SITE}/unsubscribe`;
  const subject = 'Your fridge is waiting';
  const phone = fridgeAsset('phone.png');

  const ink = '#241456';
  const purpleTop = '#2f1d72';
  const purpleBot = '#251659';
  const btn = '#5a2fd6';
  const box = '#f3ecfd';
  const badge = '#6db23f';
  const muted = '#8a86a0';
  const footBg = '#f0eef6';
  const hand = '#2d1a6b';
  const greenBg = '#eef7ea';
  const green = '#4e9c4f';

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>${subject}</title>
</head>
<body style="margin:0;padding:0;background:#f1f1f6;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
    Scan your first receipt in under 30 seconds.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f1f1f6;">
    <tr>
      <td align="center" style="padding:24px 10px;">
        <table role="presentation" width="360" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:360px;background:#ffffff;border-radius:6px;overflow:hidden;">

          <!-- HEADER -->
          <tr>
            <td style="background-color:${purpleBot};background:linear-gradient(160deg,${purpleTop},${purpleBot});padding:0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td valign="top" style="padding:22px 6px 24px 22px;width:58%;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="left" style="font-family:Arial,Helvetica,sans-serif;">
                          <a href="${home}" style="color:#ffffff;font-size:20px;font-weight:800;text-decoration:none;letter-spacing:0.3px;">Quillo</a>
                        </td>
                        <td align="right" style="font-family:Georgia,'Segoe Script',cursive;color:#d9d3f2;font-size:13px;font-style:italic;line-height:1.15;font-weight:600;">
                          Same groceries.<br>More possibilities.
                        </td>
                      </tr>
                    </table>
                    <div style="margin-top:22px;font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:28px;line-height:1.08;font-weight:800;letter-spacing:-0.5px;">
                      Your fridge is waiting
                    </div>
                    <p style="margin:14px 0 0;font-family:Arial,Helvetica,sans-serif;color:#cec7ec;font-size:12px;line-height:1.5;">
                      You've confirmed your email, but you haven't scanned a receipt yet.
                    </p>
                    <div style="margin-top:14px;">
                      <span style="display:inline-block;background:${badge};color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:10px;font-weight:700;line-height:1.2;padding:10px 12px;border-radius:999px;">
                        Takes less than<br>30 seconds
                      </span>
                    </div>
                  </td>
                  <td valign="bottom" align="right" style="padding:12px 0 0 0;width:42%;">
                    <img src="${phone}" width="132" alt="" style="display:block;margin:0 0 0 auto;width:132px;height:auto;">
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- BODY / CTA -->
          <tr>
            <td style="padding:22px 22px 6px 22px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;">
              <p style="margin:0;color:#3a3652;font-size:13.5px;line-height:1.55;">
                Open the app, point your camera at any grocery receipt, and Quillo will turn it into personalised meal ideas.
              </p>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:16px;">
                <tr>
                  <td align="center" style="border-radius:30px;background:${btn};">
                    <a href="${opts.scanDeepLink}" style="display:block;padding:15px 18px;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:700;color:#ffffff;text-decoration:none;">
                      Scan my first receipt →
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin:12px 0 0;text-align:center;color:${muted};font-size:10.5px;">
                <a href="${opts.scanDeepLink}" style="color:${muted};text-decoration:none;">Opens the Quillo camera screen directly.</a>
              </p>
            </td>
          </tr>

          <!-- FREE SCANS -->
          <tr>
            <td style="padding:16px 22px 6px 22px;background:#ffffff;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${box};border-radius:14px;">
                <tr>
                  <td width="48" valign="middle" style="padding:15px 0 15px 16px;font-family:Arial,Helvetica,sans-serif;color:#6a35d6;font-size:20px;font-weight:800;">▣</td>
                  <td valign="middle" style="padding:15px 16px 15px 0;font-family:Arial,Helvetica,sans-serif;">
                    <div style="font-size:12.5px;font-weight:800;color:${ink};">You have ${freeScans} free scans available this month.</div>
                    <div style="margin-top:2px;font-size:11px;color:#7b7794;">No card required.</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- WHY -->
          <tr>
            <td style="padding:16px 22px 8px 22px;background:#ffffff;">
              <div style="height:1px;background:#eceaf1;line-height:1px;font-size:1px;margin-bottom:16px;">&nbsp;</div>
              <div style="font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:800;color:${ink};margin-bottom:16px;">Why do it now?</div>
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td width="33%" valign="top" style="padding:0 8px;font-family:Arial,Helvetica,sans-serif;text-align:center;border-right:1px solid #ece9f2;">
                    <div style="margin:0 auto 10px;width:40px;height:40px;line-height:40px;border-radius:20px;background:${greenBg};color:${green};font-weight:800;">1</div>
                    <div style="font-size:11px;color:#5f6b62;line-height:1.4;"><b style="color:${ink};">Get recipe ideas</b> from what you already buy</div>
                  </td>
                  <td width="33%" valign="top" style="padding:0 8px;font-family:Arial,Helvetica,sans-serif;text-align:center;border-right:1px solid #ece9f2;">
                    <div style="margin:0 auto 10px;width:40px;height:40px;line-height:40px;border-radius:20px;background:${greenBg};color:${green};font-weight:800;">2</div>
                    <div style="font-size:11px;color:#5f6b62;line-height:1.4;"><b style="color:${ink};">Reduce waste</b> at home</div>
                  </td>
                  <td width="33%" valign="top" style="padding:0 8px;font-family:Arial,Helvetica,sans-serif;text-align:center;">
                    <div style="margin:0 auto 10px;width:40px;height:40px;line-height:40px;border-radius:20px;background:${greenBg};color:${green};font-weight:800;">3</div>
                    <div style="font-size:11px;color:#5f6b62;line-height:1.4;"><b style="color:${ink};">Start tracking</b> your savings</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- HAND -->
          <tr>
            <td style="padding:6px 20px 16px 20px;background:#ffffff;font-family:Georgia,'Segoe Script',cursive;color:${hand};font-size:20px;font-style:italic;font-weight:600;text-align:center;line-height:1.3;">
              Small scans. A bigger tomorrow. <span style="color:#7cc45f;">♥</span>
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="background:${footBg};padding:14px 18px;text-align:center;font-family:Arial,Helvetica,sans-serif;">
              <div style="font-size:10px;color:#3f3a5a;font-weight:600;line-height:1.7;">
                <a href="${SITE}" style="color:#3f3a5a;text-decoration:none;">quilloai.co.uk</a>
                <span style="color:#9a95b0;font-weight:400;margin:0 5px;">|</span>
                <a href="${SOCIAL}" style="color:#3f3a5a;text-decoration:none;">@Quillo.ai</a>
                <span style="color:#9a95b0;font-weight:400;margin:0 5px;">|</span>
                <a href="${unsub}" style="color:#3f3a5a;text-decoration:none;">Unsubscribe</a>
              </div>
              <div style="margin-top:4px;font-size:8.5px;color:#9a95b0;line-height:1.5;">
                Reisen AI Ltd trading as Quillo · 66 Paul Street, London EC2A 4NA
              </div>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { subject, html };
}

function milestoneSubcopy(threshold: number): string {
  if (threshold >= 250) {
    return "That's more than a third of the average UK household's annual food waste budget — saved since you joined.";
  }
  if (threshold >= 100) {
    return "You're building real momentum — every scan keeps more food (and money) in your kitchen.";
  }
  return "That's a real dent in household food waste — saved since you joined.";
}

function savingsAsset(file: string): string {
  const base = (Deno.env.get('EMAIL_ASSET_BASE_URL') ??
    'https://klvzgfheneyqrwfxtfyg.supabase.co/storage/v1/object/public/email-assets')
    .replace(/\/$/, '');
  return `${base}/savings-card/${file}`;
}

/** Email 3 — savings milestone (quillo-savings-card design + dynamic app data) */
export function buildMilestoneEmail(opts: {
  email: string;
  fullName?: string | null;
  threshold: number;
  moneySavedGbp: number;
  kgAvoided: number;
  openDeepLink: string;
  homeDeepLink?: string;
  unsubscribeUrl?: string;
}): { subject: string; html: string } {
  const threshold = Math.round(opts.threshold);
  const money = moneyLabel(opts.moneySavedGbp);
  const kg = kgLabel(opts.kgAvoided);
  const dashboard = opts.openDeepLink;
  const home = opts.homeDeepLink ?? 'quillo://home';
  const unsub = opts.unsubscribeUrl ?? `${SITE}/unsubscribe`;
  const subject = `You just saved £${money} with Quillo`;
  const sub = milestoneSubcopy(threshold);
  const fruit = savingsAsset('fruit.png');
  const leafIcon = savingsAsset('leaf-icon.png');
  const leaf1 = savingsAsset('leaf1.png');
  const leaf2 = savingsAsset('leaf2.png');

  const headerTop = '#294539';
  const headerBot = '#0c3823';
  const darkGreen = '#123d26';
  const accent = '#15402a';
  const statBox = '#f0f8ec';
  const mileBox = '#f1f4e3';
  const footBg = '#e6e7ee';
  const muted = '#7f8f84';
  const hand = '#2f6b3e';

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>${subject}</title>
</head>
<body style="margin:0;padding:0;background:#f1f2f7;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">
    Milestone unlocked — £${threshold} saved with Quillo.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f1f2f7;">
    <tr>
      <td align="center" style="padding:24px 10px;">
        <table role="presentation" width="360" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:360px;background:#ffffff;border-radius:6px;overflow:hidden;">

          <!-- HEADER -->
          <tr>
            <td style="background-color:${headerBot};background:linear-gradient(150deg,${headerTop} 0%,${headerBot} 70%);padding:0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td valign="top" style="padding:22px 10px 22px 22px;width:58%;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="left" style="font-family:Arial,Helvetica,sans-serif;">
                          <a href="${home}" style="color:#ffffff;font-size:19px;font-weight:700;text-decoration:none;letter-spacing:0.3px;">Quillo</a>
                        </td>
                        <td align="right" style="font-family:Arial,Helvetica,sans-serif;color:#c3d8c9;font-size:9.5px;font-style:italic;line-height:1.4;font-weight:400;">
                          Good food<br>goes further.
                        </td>
                      </tr>
                    </table>
                    <div style="margin-top:20px;font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:23px;line-height:1.28;font-weight:800;letter-spacing:-0.2px;">
                      You just saved £${money} with Quillo
                    </div>
                    <p style="margin:14px 0 0;font-family:Arial,Helvetica,sans-serif;color:#c9dacf;font-size:11.5px;line-height:1.55;">
                      ${sub}
                    </p>
                  </td>
                  <td valign="bottom" align="right" style="padding:8px 0 0 0;width:42%;">
                    <img src="${leaf2}" width="56" alt="" style="display:block;margin:0 8px 0 auto;width:56px;height:auto;opacity:0.95;">
                    <img src="${fruit}" width="118" alt="" style="display:block;margin:0 0 0 auto;width:118px;max-width:118px;height:auto;">
                    <img src="${leaf1}" width="64" alt="" style="display:block;margin:-28px 70px 8px auto;width:64px;height:auto;opacity:0.95;">
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- STATS -->
          <tr>
            <td style="padding:18px 18px 6px 18px;background:#ffffff;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${statBox};border-radius:14px;">
                <tr>
                  <td width="50%" valign="top" style="padding:22px 12px;font-family:Arial,Helvetica,sans-serif;text-align:center;">
                    <div style="font-size:18px;line-height:26px;color:${accent};font-weight:700;">£</div>
                    <div style="margin-top:8px;color:${accent};font-size:23px;font-weight:700;">£${money}</div>
                    <div style="margin-top:6px;color:${muted};font-size:10.5px;line-height:1.4;">Estimated money<br>saved since joining</div>
                  </td>
                  <td width="1" style="background:#d6e2d3;width:1px;"></td>
                  <td width="50%" valign="top" style="padding:22px 12px;font-family:Arial,Helvetica,sans-serif;text-align:center;">
                    <img src="${leafIcon}" width="24" height="26" alt="" style="display:inline-block;width:24px;height:26px;">
                    <div style="margin-top:8px;color:${accent};font-size:23px;font-weight:700;">${kg} kg</div>
                    <div style="margin-top:6px;color:${muted};font-size:10.5px;line-height:1.4;">Estimated food<br>waste avoided</div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- MILESTONE -->
          <tr>
            <td style="padding:12px 18px 6px 18px;background:#ffffff;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:${mileBox};border-radius:12px;">
                <tr>
                  <td align="center" style="padding:16px 18px;font-family:Arial,Helvetica,sans-serif;">
                    <span style="color:#4ea340;font-size:28px;vertical-align:middle;line-height:1;">★</span>
                    <span style="display:inline-block;vertical-align:middle;text-align:left;padding-left:12px;">
                      <span style="display:block;font-size:12px;color:#4a5a4f;">Milestone unlocked</span>
                      <span style="display:block;font-size:22px;font-weight:700;color:${accent};margin-top:2px;">£${threshold} saved</span>
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td style="padding:14px 18px 4px 18px;background:#ffffff;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center" style="border-radius:16px;background:${darkGreen};">
                    <a href="${dashboard}" style="display:block;padding:15px 18px;font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:600;color:#ffffff;text-decoration:none;">
                      View my savings dashboard →
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin:10px 0 14px;text-align:center;font-family:Arial,Helvetica,sans-serif;font-size:10.5px;color:#9aa79e;">
                <a href="${dashboard}" style="color:#9aa79e;text-decoration:none;">Open your personal savings tracker in the app.</a>
              </p>
            </td>
          </tr>

          <!-- TIP -->
          <tr>
            <td style="padding:0 18px 16px 18px;background:#ffffff;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#eef6ea;border:1px solid #e0ebdb;border-radius:14px;">
                <tr>
                  <td width="48" valign="top" style="padding:16px 0 16px 14px;">
                    <img src="${leafIcon}" width="20" height="22" alt="" style="display:block;width:20px;height:22px;margin:6px;background:#cfe8c6;padding:6px;border-radius:9px;">
                  </td>
                  <td valign="top" style="padding:16px 8px 16px 0;font-family:Arial,Helvetica,sans-serif;">
                    <div style="font-size:13px;font-weight:700;color:${accent};">Small changes add up</div>
                    <div style="margin-top:4px;font-size:11px;color:#5d6d62;line-height:1.45;">Keep scanning receipts to unlock more personalised recipes and make an even bigger impact.</div>
                  </td>
                  <td width="88" valign="middle" align="center" style="padding:12px 10px 12px 0;font-family:Georgia,'Segoe Script',cursive;color:${hand};font-size:12px;line-height:1.35;font-style:italic;">
                    Good food<br>brighter futures<br><span style="color:#7cc45f;">♥</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="background:${footBg};padding:14px 18px;text-align:center;font-family:Arial,Helvetica,sans-serif;">
              <div style="font-size:10px;color:#3a4a40;font-weight:600;line-height:1.7;">
                <a href="${SITE}" style="color:#3a4a40;text-decoration:none;">quilloai.co.uk</a>
                <span style="color:#8794a8;font-weight:400;margin:0 5px;">|</span>
                <a href="${SOCIAL}" style="color:#3a4a40;text-decoration:none;">@Quillo.ai</a>
                <span style="color:#8794a8;font-weight:400;margin:0 5px;">|</span>
                <a href="${unsub}" style="color:#3a4a40;text-decoration:none;">Unsubscribe</a>
              </div>
              <div style="margin-top:4px;font-size:8.5px;color:#8794a8;line-height:1.5;">
                Reisen AI Ltd trading as Quillo · 66 Paul Street, London EC2A 4NA
              </div>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { subject, html };
}

export function buildMonthlySummaryEmail(opts: {
  email: string;
  fullName?: string | null;
  monthName: string;
  scanCount: number;
  moneySavedGbp: number;
  kgAvoided: number;
  streak: number;
  openDeepLink: string;
  unsubscribeUrl?: string;
}): { subject: string; html: string } {
  const name = firstName(opts.fullName, opts.email);
  const money = moneyLabel(opts.moneySavedGbp);
  const kg = kgLabel(opts.kgAvoided);
  const subject = `Your Quillo month — ${opts.monthName}`;

  const bodyRows = `
<tr>
  <td style="background:${GREEN_HEADER};padding:22px;">
    <div style="font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:22px;font-weight:800;">Quillo</div>
    <div style="margin-top:16px;font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:24px;font-weight:900;">Your Quillo month — ${opts.monthName}</div>
  </td>
</tr>
<tr>
  <td style="padding:24px 22px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;">
    <p style="margin:0 0 16px;color:${INK};font-size:15px;line-height:1.55;">Hi ${name}, here's a quick look at your impact last month.</p>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
      <tr>
        <td style="width:32%;padding:14px 8px;background:${GREEN_CARD};border-radius:12px;text-align:center;">
          <div style="font-size:22px;font-weight:900;color:${GREEN_HEADER};">${opts.scanCount}</div>
          <div style="font-size:11px;color:${GREEN_TEXT};margin-top:4px;">scans</div>
        </td>
        <td style="width:2%;"></td>
        <td style="width:32%;padding:14px 8px;background:${GREEN_CARD};border-radius:12px;text-align:center;">
          <div style="font-size:22px;font-weight:900;color:${GREEN_HEADER};">£${money}</div>
          <div style="font-size:11px;color:${GREEN_TEXT};margin-top:4px;">saved</div>
        </td>
        <td style="width:2%;"></td>
        <td style="width:32%;padding:14px 8px;background:${GREEN_CARD};border-radius:12px;text-align:center;">
          <div style="font-size:22px;font-weight:900;color:${GREEN_HEADER};">${kg} kg</div>
          <div style="font-size:11px;color:${GREEN_TEXT};margin-top:4px;">avoided</div>
        </td>
      </tr>
    </table>
    <p style="margin:16px 0 8px;color:#555;">Streak status: <strong>${opts.streak}</strong> day${opts.streak === 1 ? '' : 's'}.</p>
    ${ctaButton(opts.openDeepLink, 'See your food waste dashboard →', GREEN_HEADER)}
  </td>
</tr>`;

  return {
    subject,
    html: wrapEmail({
      preheader: `Your Quillo impact for ${opts.monthName}.`,
      title: subject,
      bodyRows,
      unsubscribeUrl: opts.unsubscribeUrl,
    }),
  };
}

export function buildPremiumPromptEmail(opts: {
  email: string;
  fullName?: string | null;
  weeklySavingGbp: number;
  premiumDeepLink: string;
}): { subject: string; html: string } {
  const name = firstName(opts.fullName, opts.email);
  const saving = opts.weeklySavingGbp.toFixed(2);
  const subject = `You could have saved £${saving} this week`;
  const bodyRows = `
<tr>
  <td style="background:${GREEN_HEADER};padding:22px;">
    <div style="font-family:Arial,Helvetica,sans-serif;color:#ffffff;font-size:22px;font-weight:800;">Quillo</div>
  </td>
</tr>
<tr>
  <td style="padding:28px 22px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;">
    <p style="margin:0 0 12px;font-size:18px;font-weight:700;color:${INK};">${subject}</p>
    <p style="margin:0 0 16px;color:${MUTED};">Hi ${name}, Quillo Premium users track exactly how much food waste they avoid every week.</p>
    ${ctaButton(opts.premiumDeepLink, 'Upgrade to Quillo Premium →', GREEN_TEXT)}
  </td>
</tr>`;
  return {
    subject,
    html: wrapEmail({ preheader: subject, title: subject, bodyRows }),
  };
}

export function buildConfirmUrl(
  supabaseUrl: string,
  emailData: {
    token_hash: string;
    email_action_type: string;
    redirect_to?: string;
  },
  fallbackRedirect = 'quillo://home',
): string {
  const base = supabaseUrl.replace(/\/$/, '');
  const rawRedirect = (emailData.redirect_to ?? '').trim();
  const redirect =
    !rawRedirect ||
      rawRedirect.includes('localhost') ||
      rawRedirect.includes('127.0.0.1')
      ? fallbackRedirect
      : rawRedirect;

  const params = new URLSearchParams({
    token: emailData.token_hash,
    type: emailData.email_action_type,
    redirect_to: redirect,
  });
  return `${base}/auth/v1/verify?${params.toString()}`;
}
