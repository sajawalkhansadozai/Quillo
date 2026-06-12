# Ways to import recipes into Supabase

All methods write to `public.recipes` with `is_public = true` for Explore.  
Apply migration `008_system_recipe_seed_support.sql` first (for `source`, `source_id`, upserts).

You need:

```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export SEED_USER_ID="uuid-from-auth-users"
```

---

## 1. Spoonacular API (current default)

Best if the client already pays for Spoonacular. Imports thousands via many search lanes.

```bash
export SPOONACULAR_API_KEY="..."
python3 scripts/import_recipes.py --provider spoonacular --total 5000
```

See [RECIPE_IMPORT_SUPABASE.md](./RECIPE_IMPORT_SUPABASE.md).

---

## 2. Edamam Recipe API (second API)

Larger catalog (~2M+), different cuisines than Spoonacular. Sign up at [Edamam Developer](https://developer.edamam.com/) for `app_id` + `app_key`.

```bash
export EDAMAM_APP_ID="..."
export EDAMAM_APP_KEY="..."
python3 scripts/import_recipes.py --provider edamam --total 3000 --batch-size 50
```

Note: Some plans return ingredients but link out for full steps (stored as a single step with source URL).

---

## 3. TheMealDB (free, no API key)

~300 meals, good for dev/smoke tests — not thousands.

```bash
python3 scripts/import_recipes.py --provider themealdb --total 300 --batch-size 25
```

---

## 4. Local JSON file (no API quota)

Hand-curated recipes, Kaggle exports, or any dataset converted to JSON.

Format: array of objects (see `data/recipes/sample_recipes.json`).

```bash
python3 scripts/import_recipes_json.py --file data/recipes/sample_recipes.json
```

Or with Make:

```bash
make import-recipes-json FILE=data/recipes/my_export.json
```

**Open datasets:** Search Kaggle/GitHub for “recipe dataset JSON”, map fields to the sample shape, then import. You own licensing for that data.

---

## 5. Supabase SQL Editor

Paste `INSERT` rows from a spreadsheet or export. Useful for dozens of recipes, not thousands.

```sql
INSERT INTO public.recipes (
  user_id, title, cook_time_minutes, difficulty, servings,
  steps, ingredients_used, missing_ingredients, nutrition,
  image_url, is_public, is_system, source, source_id, license
) VALUES (
  'YOUR_SEED_USER_ID',
  'Example Dish',
  30, 'easy', 4,
  '[{"order":1,"instruction":"Step one."}]'::jsonb,
  '[{"name":"Rice","amount":"2 cups"}]'::jsonb,
  '[]'::jsonb,
  '{"calories":400,"protein":10,"carbs":60,"fat":8}'::jsonb,
  'https://example.com/image.jpg',
  true, true, 'manual', 'example-dish', 'Internal seed data'
);
```

---

## 6. Supabase Table Editor / CSV

1. Export a template from one imported row (SQL or Table Editor).
2. Build a CSV with matching columns (JSON columns as JSON strings).
3. Import via **Table Editor → Insert → Import CSV** (small/medium batches).

Works well for ops teams; awkward for large `steps` / `ingredients_used` JSON.

---

## 7. In-app debug seed (Flutter)

`DevRecipeSeedService` inserts a small hardcoded set when signed in (debug only). Good for local QA, not production scale.

---

## 8. Claude bulk generation

Generate thousands with the same schema as `generate-recipes`, written by `import_recipes_claude.py`.

```bash
export ANTHROPIC_API_KEY="..."
python3 scripts/import_recipes_claude.py --total 5000 --per-call 10
```

See [RECIPE_IMPORT_CLAUDE.md](./RECIPE_IMPORT_CLAUDE.md). **Expensive** at scale — prefer Spoonacular for catalog volume.

---

## 9. Organic growth (no import)

`generate-recipes` Edge Function already saves scan-based recipes. Mark good ones `is_public = true` so Explore grows from real users.

---

## Choosing a approach

| Goal | Method |
|------|--------|
| Thousands, client has Spoonacular | **1** |
| Even wider catalog, second API bill | **2** |
| Free dev data | **3** |
| Custom/licensed/static data | **4** or **5** |
| Long-term moat | **8** + public sharing |

You can **combine** sources: e.g. Spoonacular 5k + JSON curated regional dishes + TheMealDB. Upsert on `(source, source_id)` avoids duplicates per provider.

Verify:

```sql
select source, count(*) from public.recipes
where is_system = true and is_public = true
group by source order by count desc;
```
