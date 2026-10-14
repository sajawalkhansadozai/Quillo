/** OneSignal REST helper — server-side push (Balanced Notifications). */

const ONESIGNAL_API = 'https://api.onesignal.com/notifications';

export interface PushPayload {
  externalUserId: string;
  heading: string;
  body: string;
  data?: Record<string, string>;
}

function inQuietHoursUtcHour(localHour: number): boolean {
  return localHour < 8 || localHour >= 22;
}

/** Returns true if local hour is within allowed send window (08:00–21:59). */
export function isWithinPushWindow(timezone: string, now = new Date()): boolean {
  try {
    const fmt = new Intl.DateTimeFormat('en-GB', {
      timeZone: timezone || 'Europe/London',
      hour: 'numeric',
      hour12: false,
    });
    const hour = Number(fmt.format(now));
    return !inQuietHoursUtcHour(Number.isFinite(hour) ? hour : 12);
  } catch {
    return true;
  }
}

export async function sendOneSignalPush(opts: PushPayload): Promise<void> {
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const apiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
  if (!appId || !apiKey) {
    throw new Error(
      'ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY not configured in Edge Function secrets.',
    );
  }

  const res = await fetch(ONESIGNAL_API, {
    method: 'POST',
    headers: {
      Authorization: `Key ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      app_id: appId,
      target_channel: 'push',
      include_aliases: {
        external_id: [opts.externalUserId],
      },
      headings: { en: opts.heading },
      contents: { en: opts.body },
      data: opts.data ?? {},
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`OneSignal error ${res.status}: ${body}`);
  }
}

/** Dietary exclusion check for ingredient names in push copy. */
const DIETARY_BANNED: Record<string, string[]> = {
  vegan: ['pork', 'bacon', 'ham', 'beef', 'chicken', 'lamb', 'fish', 'milk', 'cheese', 'egg'],
  vegetarian: ['pork', 'bacon', 'ham', 'beef', 'chicken', 'lamb', 'fish'],
  halal: ['pork', 'bacon', 'ham', 'wine', 'beer', 'alcohol', 'lard'],
  muslim: ['pork', 'bacon', 'ham', 'wine', 'beer', 'alcohol', 'lard'],
  kosher: ['pork', 'bacon', 'ham', 'shellfish', 'prawn', 'shrimp'],
  'no pork': ['pork', 'bacon', 'ham', 'prosciutto', 'chorizo', 'lard'],
};

export function ingredientAllowedForDiet(
  ingredientName: string,
  dietaryLabels: string[],
): boolean {
  const lower = ingredientName.toLowerCase();
  for (const label of dietaryLabels) {
    const banned = DIETARY_BANNED[label.toLowerCase()];
    if (!banned) continue;
    if (banned.some((b) => lower.includes(b))) return false;
  }
  return true;
}
