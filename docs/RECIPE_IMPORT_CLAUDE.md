# Import 5000 recipes via Claude → Supabase

Script: `scripts/import_recipes_claude.py`

## Prerequisites

1. Migration `008_system_recipe_seed_support.sql` applied (`source`, `source_id` upsert).
2. Env vars:

```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export SEED_USER_ID="uuid-from-auth-users"
export ANTHROPIC_API_KEY="your-anthropic-key"
```

Get `SEED_USER_ID`:

```sql
select id from auth.users limit 1;
```

## Run (5000 recipes)

```bash
python3 scripts/import_recipes_claude.py --total 5000 --per-call 10 --pause-ms 1500
```

- **~500** Anthropic API calls (10 recipes each).
- **~2–4 hours** runtime with default pause (rate limits may extend this).
- Progress saved to `data/claude_import_state.json` — safe to stop and resume:

```bash
python3 scripts/import_recipes_claude.py --total 5000 --resume
```

## Optional images

Uses Spoonacular search per recipe (slow + extra quota):

```bash
export SPOONACULAR_API_KEY="..."
python3 scripts/import_recipes_claude.py --total 5000 --with-images
```

## Smaller test first

```bash
python3 scripts/import_recipes_claude.py --total 20 --per-call 5
```

## Verify

```sql
select count(*) from public.recipes
where source = 'claude' and is_public = true and is_system = true;
```

## Cost note

Claude bulk generation is **much more expensive** than importing licensed API data (Spoonacular/Edamam). Use Claude seed if you need AI-original catalog copy; use Spoonacular for cost-effective thousands.

Rows are stored with `source = 'claude'`, `is_system = true`, `is_public = true`.
