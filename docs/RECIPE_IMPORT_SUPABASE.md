# Recipe Import to Supabase (thousands)

This imports recipes into `public.recipes` for Explore so new users do not see empty sections.

The Spoonacular importer rotates through many search lanes (cuisine, type, diet, query) because a single API search can only paginate to offset 900 (~1,000 recipes).

## 1) Run migration first

Apply:

- `supabase/migrations/008_system_recipe_seed_support.sql`

This adds provider metadata and dedupe support:

- `is_system`
- `source`, `source_id`, `source_url`
- `license`
- `title_hash`
- unique constraint on `(source, source_id)`

## 2) Required env vars

Set these in your shell:

```bash
export SUPABASE_URL="https://<project-ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
export SEED_USER_ID="<existing-auth-user-uuid>"
export SPOONACULAR_API_KEY="<spoonacular-api-key>"
```

`SEED_USER_ID` must be a valid `auth.users.id` because `recipes.user_id` is required.

## 3) Import thousands of recipes

Default target is **5,000 unique** Spoonacular recipes:

```bash
python3 scripts/import_recipes.py --provider spoonacular --total 5000 --batch-size 100
```

Smaller run (e.g. 2,000):

```bash
python3 scripts/import_recipes.py --provider spoonacular --total 2000 --batch-size 100
```

You can re-run safely. It uses upsert with `on_conflict=source,source_id` and skips duplicate Spoonacular IDs across lanes.

**API points:** Each batch requests full recipe info (ingredients, steps, nutrition). A 5,000-recipe import uses substantial Spoonacular quota — watch the dashboard and use `--pause-ms 500` if you hit rate limits.

### Shortcut with Make

```bash
make import-recipes
```

Optional overrides:

```bash
PROVIDER=spoonacular TOTAL=5000 BATCH_SIZE=100 PAUSE_MS=250 make import-recipes
```

## Fallback provider (no Spoonacular key)

If Spoonacular returns 401/403, use TheMealDB fallback:

```bash
PROVIDER=themealdb TOTAL=500 BATCH_SIZE=50 make import-recipes
```

Or direct script call:

```bash
python3 scripts/import_recipes.py --provider themealdb --total 500 --batch-size 50
```

## 4) Verify in SQL editor

```sql
select count(*) as public_system_recipes
from public.recipes
where is_public = true and is_system = true;
```

## 5) Weekly refresh (optional)

Run the same command weekly (cron/GitHub Actions).  
Because it is an upsert on `(source, source_id)`, existing records update and new ones are inserted.

## Notes

- Keep `SPOONACULAR_API_KEY` and service-role key private.
- This importer writes directly to Supabase using REST + service role.
- The in-app DEV seed button is still useful for quick local smoke tests, but not for 1400-scale seeding.
- The importer now runs a Supabase preflight check first and fails fast with a clear 401 message if `SUPABASE_SERVICE_ROLE_KEY` is invalid.
