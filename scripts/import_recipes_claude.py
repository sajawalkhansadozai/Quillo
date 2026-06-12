#!/usr/bin/env python3
"""Generate catalog recipes with Claude and upsert into Supabase.

Usage:
  export ANTHROPIC_API_KEY="..."
  export SUPABASE_URL="..."
  export SUPABASE_SERVICE_ROLE_KEY="..."
  export SEED_USER_ID="..."
  python3 scripts/import_recipes_claude.py --total 5000 --per-call 10

Resume after interrupt:
  python3 scripts/import_recipes_claude.py --total 5000 --resume

Cost: ~500 Claude calls for 5000 recipes (10 per call) — often $100–400+.
For bulk catalog data, Spoonacular import is usually cheaper.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

from import_recipes import _env, _validate_supabase_access, load_env_file, upsert_batch

DEFAULT_STATE_PATH = Path(__file__).resolve().parents[1] / "data" / "claude_import_state.json"
CLAUDE_MODEL = "claude-sonnet-4-6"

# Cycled until --total is reached (~10 recipes per API call).
CLAUDE_LANES: list[tuple[str, str]] = [
    ("British", "comfort food dinners"),
    ("British", "quick weeknight meals"),
    ("British", "Sunday lunch classics"),
    ("Italian", "pasta dishes"),
    ("Italian", "risotto and rice"),
    ("Italian", "vegetarian Italian"),
    ("Mexican", "tacos and burritos"),
    ("Mexican", "bowls and salads"),
    ("Mexican", "one-pot Mexican"),
    ("Indian", "curry house favorites"),
    ("Indian", "South Indian home cooking"),
    ("Indian", "North Indian vegetarian"),
    ("Chinese", "stir-fry"),
    ("Chinese", "noodles and dumplings"),
    ("Chinese", "Sichuan spicy"),
    ("Japanese", "ramen and noodles"),
    ("Japanese", "donburi bowls"),
    ("Japanese", "bento-friendly lunches"),
    ("Thai", "curries"),
    ("Thai", "noodles and street food"),
    ("Korean", "BBQ and grilled"),
    ("Korean", "stews and rice bowls"),
    ("Mediterranean", "Greek inspired"),
    ("Mediterranean", "Middle Eastern mezze"),
    ("American", "burgers and sandwiches"),
    ("American", "BBQ and game day"),
    ("American", "Southern comfort"),
    ("French", "bistro classics"),
    ("French", "simple weeknight French"),
    ("Spanish", "tapas and sharing"),
    ("Spanish", "paella and rice dishes"),
    ("Middle Eastern", "Levantine dinners"),
    ("Middle Eastern", "Persian inspired"),
    ("African", "West African stews"),
    ("African", "East African plates"),
    ("Caribbean", "Jamaican favorites"),
    ("Caribbean", "island seafood"),
    ("Vietnamese", "pho and fresh herbs"),
    ("Vietnamese", "banh mi style fillings"),
    ("Turkish", "kebabs and grills"),
    ("Turkish", "Turkish breakfast-for-dinner"),
    ("German", "schnitzel and roasts"),
    ("German", "hearty soups"),
    ("Brazilian", "feijoada and rice plates"),
    ("Brazilian", "tropical flavors"),
    ("Moroccan", "tagines"),
    ("Moroccan", "couscous dishes"),
    ("Polish", "pierogi and hearty mains"),
    ("Irish", "stews and pub food"),
    ("global", "15-minute meals"),
    ("global", "slow cooker dinners"),
    ("global", "air fryer recipes"),
    ("global", "sheet pan dinners"),
    ("global", "high-protein fitness"),
    ("global", "low-carb dinners"),
    ("global", "vegan mains"),
    ("global", "gluten-free dinners"),
    ("global", "budget student meals"),
    ("global", "meal prep freezer-friendly"),
    ("global", "kids friendly family"),
    ("global", "holiday entertaining"),
    ("global", "summer grilling"),
    ("global", "winter soups"),
    ("global", "seafood quick"),
    ("global", "chicken thigh dinners"),
    ("global", "mince beef family"),
    ("global", "plant-based legumes"),
    ("global", "egg-based dinners"),
    ("global", "one-pan pasta"),
    ("global", "grain bowls"),
    ("global", "homemade takeaway"),
]


def _source_id(title: str) -> str:
    return hashlib.sha1(title.lower().encode("utf-8")).hexdigest()[:32]


def _parse_claude_json(raw: str) -> list[dict[str, Any]]:
    cleaned = raw.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    data = json.loads(cleaned)
    if not isinstance(data, list):
        raise ValueError("Claude response is not a JSON array.")
    return data


def _normalize_difficulty(value: str) -> str:
    d = value.strip().lower()
    return d if d in ("easy", "medium", "hard") else "medium"


def _to_row(recipe: dict[str, Any], seed_user_id: str, image_url: str | None) -> dict[str, Any]:
    title = str(recipe.get("title", "")).strip()
    if not title:
        raise ValueError("Recipe missing title")

    nutrition = recipe.get("nutrition") or {}
    if not isinstance(nutrition, dict):
        nutrition = {}

    steps = recipe.get("steps") or []
    if not steps:
        steps = [{"order": 1, "instruction": "Follow recipe instructions."}]

    return {
        "user_id": seed_user_id,
        "scan_id": None,
        "title": title,
        "cook_time_minutes": max(5, int(recipe.get("cook_time_minutes") or 30)),
        "difficulty": _normalize_difficulty(str(recipe.get("difficulty") or "medium")),
        "servings": max(1, int(recipe.get("servings") or 2)),
        "steps": steps,
        "ingredients_used": recipe.get("ingredients_used") or [],
        "missing_ingredients": recipe.get("missing_ingredients") or [],
        "nutrition": {
            "calories": int(nutrition.get("calories") or 0),
            "protein": int(nutrition.get("protein") or 0),
            "carbs": int(nutrition.get("carbs") or 0),
            "fat": int(nutrition.get("fat") or 0),
        },
        "image_url": image_url,
        "is_public": True,
        "is_system": True,
        "source": "claude",
        "source_id": _source_id(title),
        "source_url": None,
        "license": "AI-generated catalog seed via Claude",
        "title_hash": hashlib.sha1(title.lower().encode("utf-8")).hexdigest(),
    }


def _build_prompt(
    cuisine: str,
    theme: str,
    count: int,
    variation: int,
    avoid_titles: list[str],
) -> str:
    avoid = ""
    if avoid_titles:
        sample = "; ".join(avoid_titles[:30])
        avoid = f"\nDo NOT repeat or closely paraphrase these titles: {sample}"

    return f"""You are building a recipe catalog for the Quillo cooking app.

Generate exactly {count} different, authentic, cookable {cuisine} recipes focused on: {theme}.
This is variation batch #{variation + 1} — use different dish names than typical prior batches.

Rules:
- Mix difficulties: easy, medium, hard.
- servings between 2 and 6.
- Each recipe: 5–8 clear steps with order numbers.
- ingredients_used: 6–12 items with realistic amounts (strings).
- missing_ingredients: always [].
- nutrition: estimated integers per serving (calories, protein, carbs, fat).
- Use specific dish names (not "Chicken Dinner #3").
{avoid}

Return ONLY a valid JSON array. No markdown, no code fences:
[
  {{
    "title": "Recipe Name",
    "difficulty": "easy",
    "cook_time_minutes": 25,
    "servings": 4,
    "steps": [{{"order": 1, "instruction": "..."}}],
    "ingredients_used": [{{"name": "Chicken", "amount": "300g"}}],
    "missing_ingredients": [],
    "nutrition": {{"calories": 450, "protein": 32, "carbs": 38, "fat": 14}}
  }}
]"""


def _call_claude(api_key: str, prompt: str, max_tokens: int) -> str:
    payload = {
        "model": CLAUDE_MODEL,
        "max_tokens": max_tokens,
        "temperature": 0.85,
        "messages": [{"role": "user", "content": prompt}],
    }
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    for block in body.get("content") or []:
        if block.get("type") == "text":
            return str(block.get("text", ""))
    return "[]"


def _http_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _fetch_spoonacular_image(title: str, api_key: str) -> str | None:
    for query in (title.strip(), " ".join(title.split()[:2])):
        if not query:
            continue
        params = {
            "apiKey": api_key,
            "query": query,
            "number": "1",
            "addRecipeInformation": "false",
        }
        url = (
            "https://api.spoonacular.com/recipes/complexSearch?"
            + urllib.parse.urlencode(params)
        )
        try:
            payload = _http_json(url)
            results = payload.get("results") or []
            if results and results[0].get("image"):
                return results[0]["image"]
        except Exception:
            continue
    return None


def _load_state(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"call_index": 0, "imported": 0, "seen_ids": []}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {
        "call_index": int(data.get("call_index", data.get("lane_index", 0))),
        "imported": int(data.get("imported", 0)),
        "seen_ids": list(data.get("seen_ids") or []),
    }


def _save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2), encoding="utf-8")


def run(
    total: int,
    per_call: int,
    pause_ms: int,
    max_tokens: int,
    with_images: bool,
    resume: bool,
    state_path: Path,
    dry_run: bool,
) -> None:
    calls_needed = (total + per_call - 1) // per_call
    state = _load_state(state_path) if resume else {"call_index": 0, "imported": 0, "seen_ids": []}
    call_index = int(state.get("call_index", 0))
    imported = int(state.get("imported", 0))

    print(
        f"Target: {total} unique recipes | {per_call}/call | "
        f"~{calls_needed} Claude calls | resume={resume} | call_index={call_index}"
    )
    if dry_run:
        print("DRY RUN — no API calls.")
        return

    supabase_url = _env("SUPABASE_URL").rstrip("/")
    service_role_key = _env("SUPABASE_SERVICE_ROLE_KEY")
    seed_user_id = _env("SEED_USER_ID")
    anthropic_key = _env("ANTHROPIC_API_KEY")
    spoon_key = os.getenv("SPOONACULAR_API_KEY", "").strip() if with_images else ""

    if with_images and not spoon_key:
        raise RuntimeError("--with-images requires SPOONACULAR_API_KEY")

    _validate_supabase_access(supabase_url, service_role_key)

    seen_ids: set[str] = set(state.get("seen_ids") or [])
    recent_titles: list[str] = []

    started = time.time()
    lane_count = len(CLAUDE_LANES)

    while imported < total:
        cuisine, theme = CLAUDE_LANES[call_index % lane_count]
        variation = call_index // lane_count
        remaining = total - imported
        batch_count = min(per_call, remaining)

        prompt = _build_prompt(cuisine, theme, batch_count, variation, recent_titles)
        print(
            f"\nCall {call_index + 1} (~{calls_needed} total): "
            f"{cuisine} — {theme} (variation {variation + 1})"
        )

        backoff = 2.0
        recipes: list[dict[str, Any]] = []
        for attempt in range(5):
            try:
                raw = _call_claude(anthropic_key, prompt, max_tokens)
                recipes = _parse_claude_json(raw)
                break
            except (urllib.error.HTTPError, json.JSONDecodeError, ValueError) as err:
                if attempt == 4:
                    print(f"  Failed after retries: {err}")
                    break
                print(f"  Retry {attempt + 1}/5: {err}")
                time.sleep(backoff)
                backoff *= 2

        rows = []
        for recipe in recipes:
            try:
                row = _to_row(recipe, seed_user_id, None)
            except ValueError:
                continue
            sid = row["source_id"]
            if sid in seen_ids:
                continue
            if with_images:
                row["image_url"] = _fetch_spoonacular_image(row["title"], spoon_key)
                time.sleep(0.15)
            seen_ids.add(sid)
            rows.append(row)
            recent_titles.append(row["title"])
            if len(recent_titles) > 40:
                recent_titles.pop(0)

        if rows:
            upsert_batch(supabase_url, service_role_key, rows)
            imported += len(rows)
            print(f"  Upserted {len(rows)} | total unique: {imported}/{total}")

        call_index += 1
        _save_state(
            state_path,
            {"call_index": call_index, "imported": imported, "seen_ids": sorted(seen_ids)},
        )

        if pause_ms > 0 and imported < total:
            time.sleep(pause_ms / 1000)

    elapsed = time.time() - started
    print(f"\nDone in {elapsed:.0f}s. Unique recipes imported: {imported}/{total}")
    print(f"State saved to {state_path}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate recipes with Claude and upsert into Supabase."
    )
    parser.add_argument("--total", type=int, default=5000, help="Target unique recipes.")
    parser.add_argument(
        "--per-call",
        type=int,
        default=10,
        help="Recipes per Claude call (5–15 recommended).",
    )
    parser.add_argument("--pause-ms", type=int, default=1500, help="Delay between calls.")
    parser.add_argument("--max-tokens", type=int, default=8192, help="Claude max_tokens.")
    parser.add_argument("--with-images", action="store_true", help="Spoonacular image lookup.")
    parser.add_argument("--resume", action="store_true", help="Resume from state file.")
    parser.add_argument("--state-file", default=str(DEFAULT_STATE_PATH))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--env-file",
        default=None,
        help="Load env vars from file (default: .env in repo root if present).",
    )
    return parser.parse_args(argv)


def _resolve_env_file(explicit: str | None) -> Path | None:
    if explicit:
        return Path(explicit)
    default = Path(__file__).resolve().parents[1] / ".env"
    return default if default.is_file() else None


if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    load_env_file(_resolve_env_file(args.env_file))
    if args.per_call < 1 or args.per_call > 20:
        raise SystemExit("--per-call must be between 1 and 20")
    run(
        total=args.total,
        per_call=args.per_call,
        pause_ms=args.pause_ms,
        max_tokens=args.max_tokens,
        with_images=args.with_images,
        resume=args.resume,
        state_path=Path(args.state_file),
        dry_run=args.dry_run,
    )
