# Public recipe catalog (Explore)

## Deploy

Run migrations on Supabase (includes `006_public_recipe_catalog.sql`):

```bash
supabase db push
```

## Behaviour

- New recipes are **public by default** (`is_public = true` on generate).
- Recipe owners can turn **Share to Explore** **off** on recipe detail to hide from the catalog.
- **Explore** loads and searches only `is_public = true` recipes from all users.
- **Home** still shows and searches only the signed-in user's recipes.

### Migration note

Run `007_recipes_public_by_default.sql` in the SQL Editor if you already applied `006` (changes the column default for future inserts).

## RLS

- `SELECT`: own rows **or** `is_public = true`
- `INSERT` / `UPDATE` / `DELETE`: own rows only

## RPC

- `search_public_recipes(p_query, p_limit)` — Explore search
- `search_user_recipes` — Home / my recipes search (unchanged)
