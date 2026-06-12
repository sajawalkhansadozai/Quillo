#!/usr/bin/env python3
"""Bulk import public recipes into Supabase.

Usage:
  python3 scripts/import_recipes.py --provider spoonacular --total 1400 --batch-size 100
  python3 scripts/import_recipes.py --provider themealdb --total 400 --batch-size 50

Required environment variables:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SEED_USER_ID

Provider-specific:
  - spoonacular: SPOONACULAR_API_KEY
  - edamam: EDAMAM_APP_ID, EDAMAM_APP_KEY

JSON file import (no API): scripts/import_recipes_json.py
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


def load_env_file(path: Path | str | None) -> None:
    """Load KEY=VALUE lines into os.environ (does not override existing vars)."""
    if path is None:
        return
    env_path = Path(path)
    if not env_path.is_file():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(
            f"Missing required environment variable: {name}\n"
            "Set with export (child processes need exported vars), e.g.:\n"
            f'  export {name}="..."\n'
            "Or put values in a .env file in the repo root (see .env.example)."
        )
    return value


def _http_json(url: str, headers: dict[str, str] | None = None) -> dict[str, Any]:
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = resp.read().decode("utf-8")
    return json.loads(body)


def _post_json(
    url: str,
    payload: list[dict[str, Any]],
    headers: dict[str, str],
) -> None:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120):
        return


def _validate_supabase_access(supabase_url: str, service_role_key: str) -> None:
    probe_url = f"{supabase_url}/rest/v1/recipes?select=id&limit=1"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }
    req = urllib.request.Request(probe_url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=30):
            return
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="ignore")
        if err.code == 401:
            raise RuntimeError(
                "Supabase authentication failed (401). "
                "SUPABASE_SERVICE_ROLE_KEY is invalid/placeholder/expired."
            ) from err
        raise RuntimeError(
            f"Supabase preflight failed ({err.code}): {body}"
        ) from err


def _difficulty_from_minutes(minutes: int) -> str:
    if minutes <= 20:
        return "easy"
    if minutes <= 45:
        return "medium"
    return "hard"


def _extract_nutrition(nutrition_obj: dict[str, Any] | None) -> dict[str, int]:
    nutrients = (nutrition_obj or {}).get("nutrients") or []
    values = {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
    for nutrient in nutrients:
        name = str(nutrient.get("name", "")).lower()
        amount = int(round(float(nutrient.get("amount", 0) or 0)))
        if name == "calories":
            values["calories"] = amount
        elif name == "protein":
            values["protein"] = amount
        elif name == "carbohydrates":
            values["carbs"] = amount
        elif name == "fat":
            values["fat"] = amount
    return values


def _format_ingredient_amount(item: dict[str, Any]) -> str:
    amount = item.get("amount")
    unit = item.get("unit") or ""
    if amount is None:
        return unit.strip() or "to taste"
    if isinstance(amount, float):
        amount_text = f"{amount:.2f}".rstrip("0").rstrip(".")
    else:
        amount_text = str(amount)
    return f"{amount_text} {unit}".strip()


def _to_recipe_row(spoon_recipe: dict[str, Any], seed_user_id: str) -> dict[str, Any]:
    title = str(spoon_recipe.get("title", "Untitled Recipe")).strip()
    source_id = str(spoon_recipe.get("id", "")).strip()
    cook_minutes = int(spoon_recipe.get("readyInMinutes") or 30)
    servings = int(spoon_recipe.get("servings") or 2)

    instructions = spoon_recipe.get("analyzedInstructions") or []
    primary_steps = []
    if instructions and isinstance(instructions, list):
        primary_steps = instructions[0].get("steps") or []

    steps = []
    for idx, step in enumerate(primary_steps, start=1):
        text = str(step.get("step", "")).strip()
        if not text:
            continue
        steps.append({"order": idx, "instruction": text})

    if not steps:
        summary = str(spoon_recipe.get("summary", "")).strip()
        fallback = summary[:240] if summary else "Follow recipe instructions."
        steps = [{"order": 1, "instruction": fallback}]

    ext_ingredients = spoon_recipe.get("extendedIngredients") or []
    ingredients_used = []
    for item in ext_ingredients:
        name = str(item.get("nameClean") or item.get("name") or "").strip()
        if not name:
            continue
        ingredients_used.append(
            {
                "name": name,
                "amount": _format_ingredient_amount(item),
            }
        )

    title_hash = hashlib.sha1(title.lower().encode("utf-8")).hexdigest()

    return {
        "user_id": seed_user_id,
        "scan_id": None,
        "title": title,
        "cook_time_minutes": cook_minutes,
        "difficulty": _difficulty_from_minutes(cook_minutes),
        "servings": servings,
        "steps": steps,
        "ingredients_used": ingredients_used,
        "missing_ingredients": [],
        "nutrition": _extract_nutrition(spoon_recipe.get("nutrition")),
        "image_url": spoon_recipe.get("image"),
        "is_public": True,
        "is_system": True,
        "source": "spoonacular",
        "source_id": source_id,
        "source_url": spoon_recipe.get("sourceUrl")
        or spoon_recipe.get("spoonacularSourceUrl"),
        "license": "Imported via Spoonacular API",
        "title_hash": title_hash,
    }


def _to_recipe_row_themealdb(
    meal: dict[str, Any],
    seed_user_id: str,
) -> dict[str, Any]:
    title = str(meal.get("strMeal") or "Untitled Recipe").strip()
    source_id = str(meal.get("idMeal") or "").strip()
    instructions = str(meal.get("strInstructions") or "").strip()
    category = str(meal.get("strCategory") or "").strip()

    ingredients_used = []
    for i in range(1, 21):
        ing = str(meal.get(f"strIngredient{i}") or "").strip()
        measure = str(meal.get(f"strMeasure{i}") or "").strip()
        if not ing:
            continue
        ingredients_used.append({"name": ing, "amount": measure or "to taste"})

    steps = []
    if instructions:
        chunks = [s.strip() for s in instructions.replace("\r", "\n").split("\n") if s.strip()]
        for idx, chunk in enumerate(chunks[:12], start=1):
            steps.append({"order": idx, "instruction": chunk})
    if not steps:
        steps = [{"order": 1, "instruction": "Follow recipe instructions."}]

    cook_minutes = 30
    if category.lower() in {"dessert", "starter"}:
        cook_minutes = 20
    elif category.lower() in {"beef", "lamb", "goat"}:
        cook_minutes = 45

    title_hash = hashlib.sha1(title.lower().encode("utf-8")).hexdigest()

    return {
        "user_id": seed_user_id,
        "scan_id": None,
        "title": title,
        "cook_time_minutes": cook_minutes,
        "difficulty": _difficulty_from_minutes(cook_minutes),
        "servings": 2,
        "steps": steps,
        "ingredients_used": ingredients_used,
        "missing_ingredients": [],
        "nutrition": {"calories": 0, "protein": 0, "carbs": 0, "fat": 0},
        "image_url": meal.get("strMealThumb"),
        "is_public": True,
        "is_system": True,
        "source": "themealdb",
        "source_id": source_id,
        "source_url": meal.get("strSource") or meal.get("strYoutube"),
        "license": "Imported via TheMealDB API",
        "title_hash": title_hash,
    }


# Spoonacular only allows offset 0–900 per search (~1k recipes max per lane).
SPOONACULAR_OFFSET_MAX = 900

# Extra search lanes diversify the catalog beyond a single popularity sort.
SPOONACULAR_LANES: list[dict[str, str]] = [
    {"sort": "popularity", "sortDirection": "desc"},
    *[{"cuisine": c} for c in (
        "african", "american", "british", "cajun", "caribbean", "chinese",
        "eastern european", "european", "french", "german", "greek", "indian",
        "irish", "italian", "japanese", "jewish", "korean", "latin american",
        "mediterranean", "mexican", "middle eastern", "nordic", "southern",
        "spanish", "thai", "vietnamese",
    )],
    *[{"type": t} for t in (
        "main course", "side dish", "dessert", "appetizer", "salad", "bread",
        "breakfast", "soup", "snack",
    )],
    *[{"diet": d} for d in ("vegetarian", "vegan", "gluten free")],
    *[{"query": q} for q in (
        "chicken", "beef", "pasta", "rice", "fish", "pork", "lamb", "tofu",
        "curry", "stew", "grill", "bake", "slow cooker", "air fryer",
    )],
]


def fetch_spoonacular_page(
    api_key: str,
    offset: int,
    page_size: int,
    lane: dict[str, str] | None = None,
) -> list[dict[str, Any]]:
    params: dict[str, str] = {
        "apiKey": api_key,
        "number": str(page_size),
        "offset": str(offset),
        "addRecipeInformation": "true",
        "fillIngredients": "true",
        "instructionsRequired": "true",
        "addRecipeNutrition": "true",
    }
    params.update(lane or {"sort": "popularity", "sortDirection": "desc"})
    url = (
        "https://api.spoonacular.com/recipes/complexSearch?"
        + urllib.parse.urlencode(params)
    )
    payload = _http_json(url)
    return payload.get("results") or []


def _lane_label(lane: dict[str, str]) -> str:
    if not lane:
        return "default"
    return ", ".join(f"{k}={v}" for k, v in lane.items())


def import_spoonacular(
    spoon_key: str,
    seed_user_id: str,
    supabase_url: str,
    service_role_key: str,
    total: int,
    page_size: int,
    pause_ms: int,
) -> int:
    """Import up to `total` unique Spoonacular recipes across multiple search lanes."""
    seen_ids: set[str] = set()
    imported = 0

    for lane in SPOONACULAR_LANES:
        if imported >= total:
            break

        offset = 0
        lane_name = _lane_label(lane)
        print(f"Lane: {lane_name}")

        while imported < total and offset <= SPOONACULAR_OFFSET_MAX:
            remaining = total - imported
            request_size = min(page_size, remaining, 100)
            print(
                f"  Fetching offset={offset} size={request_size} "
                f"| unique so far: {imported}/{total}"
            )

            try:
                source_recipes = fetch_spoonacular_page(
                    spoon_key, offset, request_size, lane
                )
            except urllib.error.HTTPError as err:
                message = err.read().decode("utf-8", errors="ignore")
                if err.code == 402:
                    print("Spoonacular quota exceeded (402). Stopping.")
                    return imported
                raise RuntimeError(
                    f"Spoonacular request failed ({err.code}): {message}\n"
                    "Check SPOONACULAR_API_KEY, quota, and plan permissions."
                ) from err

            if not source_recipes:
                print("  No more results in this lane.")
                break

            rows = []
            for item in source_recipes:
                source_id = str(item.get("id", "")).strip()
                if not source_id or source_id in seen_ids:
                    continue
                seen_ids.add(source_id)
                rows.append(_to_recipe_row(item, seed_user_id))

            if rows:
                upsert_batch(supabase_url, service_role_key, rows)
                imported += len(rows)
                print(f"  Upserted {len(rows)} new | unique total: {imported}/{total}")

            offset += len(source_recipes)
            if pause_ms > 0 and imported < total:
                time.sleep(pause_ms / 1000)

    return imported


def _edamam_source_id(uri: str) -> str:
    if "#recipe_" in uri:
        return uri.split("#recipe_", 1)[-1]
    return hashlib.sha1(uri.encode("utf-8")).hexdigest()[:40]


def _nutrient_amount(nutrients: dict[str, Any], key: str) -> int:
    entry = nutrients.get(key) or {}
    return int(round(float(entry.get("quantity", 0) or 0)))


def _to_recipe_row_edamam(hit: dict[str, Any], seed_user_id: str) -> dict[str, Any]:
    recipe = hit.get("recipe") or {}
    title = str(recipe.get("label", "Untitled Recipe")).strip()
    uri = str(recipe.get("uri", "")).strip()
    source_id = _edamam_source_id(uri) if uri else hashlib.sha1(title.encode()).hexdigest()[:40]

    ingredients_used = []
    for line in recipe.get("ingredientLines") or []:
        text = str(line).strip()
        if text:
            ingredients_used.append({"name": text, "amount": ""})

    steps = []
    instructions = recipe.get("instructions")
    if isinstance(instructions, list):
        for idx, step in enumerate(instructions, start=1):
            text = str(step).strip()
            if text:
                steps.append({"order": idx, "instruction": text})
    elif isinstance(instructions, str) and instructions.strip():
        chunks = [s.strip() for s in instructions.split("\n") if s.strip()]
        for idx, chunk in enumerate(chunks[:20], start=1):
            steps.append({"order": idx, "instruction": chunk})

    if not steps:
        source_url = str(recipe.get("url") or recipe.get("shareAs") or "").strip()
        fallback = (
            f"See full instructions at {source_url}"
            if source_url
            else "Follow the linked recipe for full instructions."
        )
        steps = [{"order": 1, "instruction": fallback}]

    nutrients = recipe.get("totalNutrients") or {}
    title_hash = hashlib.sha1(title.lower().encode("utf-8")).hexdigest()
    cook_minutes = int(recipe.get("totalTime") or 30)

    return {
        "user_id": seed_user_id,
        "scan_id": None,
        "title": title,
        "cook_time_minutes": cook_minutes,
        "difficulty": _difficulty_from_minutes(cook_minutes),
        "servings": max(1, int(recipe.get("yield") or 2)),
        "steps": steps,
        "ingredients_used": ingredients_used,
        "missing_ingredients": [],
        "nutrition": {
            "calories": _nutrient_amount(nutrients, "ENERC_KCAL"),
            "protein": _nutrient_amount(nutrients, "PROCNT"),
            "carbs": _nutrient_amount(nutrients, "CHOCDF"),
            "fat": _nutrient_amount(nutrients, "FAT"),
        },
        "image_url": recipe.get("image"),
        "is_public": True,
        "is_system": True,
        "source": "edamam",
        "source_id": source_id,
        "source_url": recipe.get("url") or recipe.get("shareAs"),
        "license": "Imported via Edamam Recipe API",
        "title_hash": title_hash,
    }


EDAMAM_QUERY_LANES = [
    "chicken", "beef", "pasta", "salad", "soup", "curry", "rice", "fish",
    "vegetarian", "vegan", "breakfast", "dessert", "italian", "mexican",
    "indian", "thai", "chinese", "mediterranean", "bbq", "baking",
]


def fetch_edamam_hits(
    app_id: str,
    app_key: str,
    query: str,
    from_idx: int,
    to_idx: int,
) -> list[dict[str, Any]]:
    params = {
        "type": "public",
        "q": query,
        "app_id": app_id,
        "app_key": app_key,
        "from": str(from_idx),
        "to": str(to_idx),
    }
    url = "https://api.edamam.com/api/recipes/v2?" + urllib.parse.urlencode(params)
    payload = _http_json(url)
    return payload.get("hits") or []


def import_edamam(
    app_id: str,
    app_key: str,
    seed_user_id: str,
    supabase_url: str,
    service_role_key: str,
    total: int,
    page_size: int,
    pause_ms: int,
) -> int:
    seen_ids: set[str] = set()
    imported = 0
    page_size = min(max(page_size, 1), 100)

    for query in EDAMAM_QUERY_LANES:
        if imported >= total:
            break

        from_idx = 0
        print(f"Lane: q={query}")

        while imported < total:
            to_idx = from_idx + page_size
            print(
                f"  Fetching from={from_idx} to={to_idx} "
                f"| unique: {imported}/{total}"
            )

            try:
                hits = fetch_edamam_hits(app_id, app_key, query, from_idx, to_idx)
            except urllib.error.HTTPError as err:
                message = err.read().decode("utf-8", errors="ignore")
                if err.code in (402, 429):
                    print(f"Edamam limit hit ({err.code}). Stopping.")
                    return imported
                raise RuntimeError(
                    f"Edamam request failed ({err.code}): {message}"
                ) from err

            if not hits:
                print("  No more results in this lane.")
                break

            rows = []
            for hit in hits:
                row = _to_recipe_row_edamam(hit, seed_user_id)
                sid = row["source_id"]
                if sid in seen_ids:
                    continue
                seen_ids.add(sid)
                rows.append(row)

            if rows:
                upsert_batch(supabase_url, service_role_key, rows)
                imported += len(rows)
                print(f"  Upserted {len(rows)} new | unique total: {imported}/{total}")

            from_idx = to_idx
            if len(hits) < page_size:
                break
            if pause_ms > 0 and imported < total:
                time.sleep(pause_ms / 1000)

    return imported


def fetch_themealdb_recipe_ids() -> list[str]:
    categories_url = "https://www.themealdb.com/api/json/v1/1/categories.php"
    categories_payload = _http_json(categories_url)
    categories = categories_payload.get("categories") or []
    ids: set[str] = set()

    for cat in categories:
        category = urllib.parse.quote(str(cat.get("strCategory", "")).strip())
        if not category:
            continue
        list_url = f"https://www.themealdb.com/api/json/v1/1/filter.php?c={category}"
        list_payload = _http_json(list_url)
        meals = list_payload.get("meals") or []
        for meal in meals:
            meal_id = str(meal.get("idMeal") or "").strip()
            if meal_id:
                ids.add(meal_id)
    return list(ids)


def fetch_themealdb_meal(meal_id: str) -> dict[str, Any] | None:
    url = f"https://www.themealdb.com/api/json/v1/1/lookup.php?i={urllib.parse.quote(meal_id)}"
    payload = _http_json(url)
    meals = payload.get("meals") or []
    if not meals:
        return None
    return meals[0]


def upsert_batch(
    supabase_url: str,
    service_role_key: str,
    rows: list[dict[str, Any]],
) -> None:
    endpoint = (
        f"{supabase_url}/rest/v1/recipes"
        "?on_conflict=source,source_id&columns=*"
    )
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    _post_json(endpoint, rows, headers)


def run(provider: str, total: int, page_size: int, pause_ms: int) -> None:
    supabase_url = _env("SUPABASE_URL").rstrip("/")
    service_role_key = _env("SUPABASE_SERVICE_ROLE_KEY")
    seed_user_id = _env("SEED_USER_ID")

    _validate_supabase_access(supabase_url, service_role_key)

    started = time.time()

    imported = 0
    if provider == "spoonacular":
        spoon_key = _env("SPOONACULAR_API_KEY")
        imported = import_spoonacular(
            spoon_key,
            seed_user_id,
            supabase_url,
            service_role_key,
            total,
            page_size,
            pause_ms,
        )
    elif provider == "edamam":
        imported = import_edamam(
            _env("EDAMAM_APP_ID"),
            _env("EDAMAM_APP_KEY"),
            seed_user_id,
            supabase_url,
            service_role_key,
            total,
            page_size,
            pause_ms,
        )
    else:
        all_ids = fetch_themealdb_recipe_ids()
        if not all_ids:
            raise RuntimeError("No recipes returned by TheMealDB.")
        print(f"Fetched {len(all_ids)} recipe ids from TheMealDB.")

        cursor = 0
        while imported < total and cursor < len(all_ids):
            batch_ids = all_ids[cursor : cursor + page_size]
            rows = []
            for meal_id in batch_ids:
                meal = fetch_themealdb_meal(meal_id)
                if not meal:
                    continue
                rows.append(_to_recipe_row_themealdb(meal, seed_user_id))

            if rows:
                upsert_batch(supabase_url, service_role_key, rows)
                imported += len(rows)
                print(f"Upserted batch: {len(rows)} | progress: {imported}/{total}")

            cursor += page_size
            if pause_ms > 0 and imported < total:
                time.sleep(pause_ms / 1000)

    elapsed = time.time() - started
    print(f"Done. Upserted {imported} recipes in {elapsed:.1f}s.")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bulk import recipes into Supabase.")
    parser.add_argument(
        "--provider",
        choices=["spoonacular", "edamam", "themealdb"],
        default="spoonacular",
        help="Recipe provider: spoonacular, edamam, or themealdb (free).",
    )
    parser.add_argument(
        "--total",
        type=int,
        default=5000,
        help="Target unique recipes to import (Spoonacular uses multiple search lanes).",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=100,
        help="Provider page size and upsert batch size.",
    )
    parser.add_argument(
        "--pause-ms",
        type=int,
        default=250,
        help="Delay between batches in milliseconds.",
    )
    return parser.parse_args(argv)


if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    run(
        provider=args.provider,
        total=args.total,
        page_size=args.batch_size,
        pause_ms=args.pause_ms,
    )
