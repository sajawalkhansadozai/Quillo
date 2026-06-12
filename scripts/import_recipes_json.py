#!/usr/bin/env python3
"""Import recipes from a local JSON file into Supabase.

No third-party API — use for hand-curated data, Kaggle exports, or converted datasets.

Usage:
  python3 scripts/import_recipes_json.py --file data/recipes/sample_recipes.json

Required environment variables:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SEED_USER_ID

JSON format: array of objects. Required per item: title.
Optional: cook_time_minutes, difficulty, servings, steps, ingredients_used,
missing_ingredients, nutrition, image_url, source, source_id, source_url, license.

If source/source_id are omitted, source defaults to "json" and source_id is derived
from title (stable upsert key).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from import_recipes import _env, _validate_supabase_access, upsert_batch


def _slug(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:120] or "recipe"


def _normalize_row(raw: dict[str, Any], seed_user_id: str) -> dict[str, Any]:
    title = str(raw.get("title", "")).strip()
    if not title:
        raise ValueError("Each recipe must have a non-empty title.")

    source = str(raw.get("source") or "json").strip() or "json"
    source_id = str(raw.get("source_id") or _slug(title)).strip()
    title_hash = hashlib.sha1(title.lower().encode("utf-8")).hexdigest()

    difficulty = str(raw.get("difficulty") or "medium").strip().lower()
    if difficulty not in ("easy", "medium", "hard"):
        difficulty = "medium"

    nutrition = raw.get("nutrition") or {}
    if not isinstance(nutrition, dict):
        nutrition = {}

    return {
        "user_id": seed_user_id,
        "scan_id": None,
        "title": title,
        "cook_time_minutes": int(raw.get("cook_time_minutes") or 30),
        "difficulty": difficulty,
        "servings": int(raw.get("servings") or 2),
        "steps": raw.get("steps") or [{"order": 1, "instruction": "Follow recipe steps."}],
        "ingredients_used": raw.get("ingredients_used") or [],
        "missing_ingredients": raw.get("missing_ingredients") or [],
        "nutrition": {
            "calories": int(nutrition.get("calories") or 0),
            "protein": int(nutrition.get("protein") or 0),
            "carbs": int(nutrition.get("carbs") or 0),
            "fat": int(nutrition.get("fat") or 0),
        },
        "image_url": raw.get("image_url"),
        "is_public": bool(raw.get("is_public", True)),
        "is_system": bool(raw.get("is_system", True)),
        "source": source,
        "source_id": source_id,
        "source_url": raw.get("source_url"),
        "license": raw.get("license") or "Imported from JSON file",
        "title_hash": title_hash,
    }


def run(json_path: Path, batch_size: int) -> None:
    supabase_url = _env("SUPABASE_URL").rstrip("/")
    service_role_key = _env("SUPABASE_SERVICE_ROLE_KEY")
    seed_user_id = _env("SEED_USER_ID")

    _validate_supabase_access(supabase_url, service_role_key)

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise RuntimeError("JSON root must be an array of recipe objects.")

    rows = [_normalize_row(item, seed_user_id) for item in payload]
    if not rows:
        print("No recipes in file.")
        return

    imported = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i : i + batch_size]
        upsert_batch(supabase_url, service_role_key, batch)
        imported += len(batch)
        print(f"Upserted {imported}/{len(rows)}")

    print(f"Done. Upserted {imported} recipes from {json_path}.")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Import recipes from a JSON file into Supabase."
    )
    parser.add_argument(
        "--file",
        required=True,
        help="Path to JSON file (array of recipe objects).",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=50,
        help="Rows per Supabase upsert batch.",
    )
    return parser.parse_args(argv)


if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    path = Path(args.file)
    if not path.is_file():
        raise SystemExit(f"File not found: {path}")
    run(path, args.batch_size)
