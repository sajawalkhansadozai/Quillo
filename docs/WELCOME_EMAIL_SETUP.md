# Quillo — Welcome Email Setup (Resend)

Balanced Notifications Edition — **4 emails max**, marketing only when useful.

| Email | When | Subject |
|-------|------|---------|
| **1** | Signup (Auth hook) | Welcome to Quillo — confirm your email |
| **2** | 24h after confirm, zero scans | Your fridge is waiting |
| **3** | Cross £50 / £100 / £250 saved | You just saved £[X] with Quillo |
| **4** | First Monday of month (active prior month) | Your Quillo month — [month] |

Email 2 unopened proxy: still zero scans after **72h** → `email_disengaged` (no further marketing until they scan again). Monthly summary resumes after re-engagement.

---

## 1. Resend (Anthony + Sajawal)

1. Create account at [resend.com](https://resend.com) (Reisen AI Google account).
2. **Domains** → add `quilloai.co.uk` → add SPF, DKIM, DMARC in Namecheap → verify.
3. **API Keys** → create key with **Send** access only.
4. Enable Resend unsubscribe / suppression for marketing emails.

---

## 2. Supabase secrets

```bash
supabase secrets set \
  RESEND_API_KEY=re_xxx \
  SEND_EMAIL_HOOK_SECRET="v1,whsec_xxx" \
  EMAIL_CRON_SECRET=your-random-cron-secret \
  ONESIGNAL_APP_ID=your-onesignal-app-id \
  ONESIGNAL_REST_API_KEY=your-onesignal-rest-key
```

Optional:

```bash
supabase secrets set RESEND_FROM="Quillo <hello@quilloai.co.uk>"
supabase secrets set QUILLO_UNSUBSCRIBE_URL="https://quilloai.co.uk/unsubscribe"
```

---

## 3. Deploy Edge Functions + migration

```bash
supabase db push   # includes 025_notifications_balanced.sql

supabase functions deploy send-welcome-email --no-verify-jwt
supabase functions deploy process-scheduled-emails --no-verify-jwt
supabase functions deploy process-scheduled-pushes --no-verify-jwt
```

---

## 4. Auth Send Email Hook (Email 1) — required for Resend branding

Endpoint:
`https://klvzgfheneyqrwfxtfyg.supabase.co/functions/v1/send-welcome-email`

Until this hook is enabled **and** `RESEND_API_KEY` + `SEND_EMAIL_HOOK_SECRET` are set,
Supabase sends its built-in confirmation email (now Quillo-branded via Auth templates).

### Fix confirm redirect (done in project)

- **Site URL:** `https://quillo.app/auth/confirmed`
- **Redirect allow list:** includes `https://quillo.app/auth/confirmed` and `quillo://**`
- App signup passes `emailRedirectTo` to that page
- Confirm page opens the app via `quillo://home`

Publish `docs/auth/confirmed/index.html` to the `quillo.app` GitHub Pages site if not already live.

### Enable full Resend hook

1. Set secrets:
   ```bash
   npx supabase secrets set RESEND_API_KEY=re_xxx SEND_EMAIL_HOOK_SECRET="v1,whsec_xxx" --project-ref klvzgfheneyqrwfxtfyg
   ```
2. Dashboard → Authentication → Hooks → **Send Email** → enable → paste function URL + hook secret
   (or set `hook_send_email_enabled` / `hook_send_email_uri` via Management API)


---

## 5. Cron jobs (hourly) — deployed via migration 026

`pg_cron` + `pg_net` call the Edge Functions:

| Job | Schedule (UTC) | Function |
|-----|----------------|----------|
| `process-scheduled-emails-hourly` | `0 * * * *` (:00) | `process-scheduled-emails` |
| `process-scheduled-pushes-hourly` | `5 * * * *` (:05) | `process-scheduled-pushes` |

Auth uses Vault secret `email_cron_secret` → header `x-email-cron-secret` (kept in sync with Edge secret `EMAIL_CRON_SECRET`).

Pushes: ingredient expiry · streak at risk (Thu ~7pm local) · milestones. Max **1 push/day**. Quiet hours **10pm–8am**.


---

## 6. Client build

```bash
flutter run --dart-define=ONESIGNAL_APP_ID=...
```

Profile → **Notifications** for per-type toggles (expiry / streak / milestone).

---

## Copy approval

Anthony must approve all subject lines and body copy before production send (checklist 1.6).
