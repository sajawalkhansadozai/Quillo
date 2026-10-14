# Quillo email templates

| Email | Builder | Design source |
|-------|---------|---------------|
| Welcome + confirm | `buildWelcomeEmail` | `docs/email/welcome-card/` |
| 24h scan nudge | `buildNudgeEmail` | `docs/email/fridge-card/` |
| Savings milestone | `buildMilestoneEmail` | `docs/email/savings-card/` |
| Monthly summary | `buildMonthlySummaryEmail` | Live HTML |

## Hosted assets

`https://klvzgfheneyqrwfxtfyg.supabase.co/storage/v1/object/public/email-assets/`

- `welcome-card/` — foodbowl, bag
- `fridge-card/` — phone.png (rasterized from mockup SVG)
- `savings-card/` — fruit, leaves

CTAs: confirm URL · `quillo://scan` · `quillo://waste`
