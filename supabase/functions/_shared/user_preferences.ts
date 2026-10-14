import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface UserRecipePreferences {
  dietary: string[];
  cuisines: string[];
  max_cook_time_minutes: number;
  cooking_skill: string;
  household_size: number;
  /** Hard exclusions — never appear in ingredients / title / steps */
  excluded_ingredients: string[];
}

export const EMPTY_PREFERENCES: UserRecipePreferences = {
  dietary: [],
  cuisines: [],
  max_cook_time_minutes: 45,
  cooking_skill: 'Intermediate',
  household_size: 2,
  excluded_ingredients: [],
};

function stringArray(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((v): v is string => typeof v === 'string')
    .map((v) => v.trim())
    .filter(Boolean);
}

export function preferencesFromBody(
  raw?: Record<string, unknown>,
): UserRecipePreferences | null {
  if (!raw || typeof raw !== 'object') return null;

  return {
    dietary: stringArray(raw.dietary ?? raw.dietary_labels),
    cuisines: stringArray(raw.cuisines ?? raw.preferred_cuisines),
    max_cook_time_minutes:
      typeof raw.max_cook_time_minutes === 'number'
        ? raw.max_cook_time_minutes
        : typeof raw.maxCookTimeMinutes === 'number'
        ? raw.maxCookTimeMinutes
        : typeof raw.max_cook_time === 'number'
        ? raw.max_cook_time
        : 45,
    cooking_skill:
      typeof raw.cooking_skill === 'string'
        ? raw.cooking_skill
        : typeof raw.cookingSkill === 'string'
        ? raw.cookingSkill
        : 'Intermediate',
    household_size:
      typeof raw.household_size === 'number'
        ? raw.household_size
        : typeof raw.householdSize === 'number'
        ? raw.householdSize
        : 2,
    excluded_ingredients: stringArray(
      raw.excluded_ingredients ?? raw.exclude_ingredients,
    ),
  };
}

/** True when dietary / cook-time / exclusions / skill must never be relaxed. */
export function hasHardPreferenceConstraints(prefs: UserRecipePreferences): boolean {
  return (
    prefs.dietary.length > 0 ||
    prefs.excluded_ingredients.length > 0 ||
    prefs.max_cook_time_minutes > 0 ||
    prefs.cooking_skill.trim().length > 0
  );
}

export async function loadUserPreferences(
  supabase: SupabaseClient,
  userId: string,
): Promise<UserRecipePreferences> {
  try {
    const [userRow, prefsRow] = await Promise.all([
      supabase
        .from('users')
        .select('household_size, preferred_cuisine')
        .eq('id', userId)
        .maybeSingle(),
      supabase
        .from('user_preferences')
        .select('dietary_labels, cooking_skill, max_cook_time, exclude_ingredients')
        .eq('user_id', userId)
        .maybeSingle(),
    ]);

    return {
      dietary: stringArray(prefsRow.data?.dietary_labels),
      cuisines: stringArray(userRow.data?.preferred_cuisine),
      max_cook_time_minutes: (prefsRow.data?.max_cook_time as number | null) ?? 45,
      cooking_skill: (prefsRow.data?.cooking_skill as string | null) ?? 'Intermediate',
      household_size: (userRow.data?.household_size as number | null) ?? 2,
      excluded_ingredients: stringArray(prefsRow.data?.exclude_ingredients),
    };
  } catch {
    return { ...EMPTY_PREFERENCES };
  }
}

/**
 * Resolve prefs for a request.
 * Body preferences (if present) win for provided fields; missing hard fields
 * are filled from the DB so legacy clients can't drop max cook time / diet.
 */
export async function resolveUserPreferences(
  supabase: SupabaseClient,
  userId: string,
  body?: Record<string, unknown>,
): Promise<UserRecipePreferences> {
  const db = await loadUserPreferences(supabase, userId);
  const fromBody = preferencesFromBody(
    (body?.preferences as Record<string, unknown> | undefined) ?? undefined,
  );

  if (fromBody) {
    return {
      dietary: fromBody.dietary.length > 0 ? fromBody.dietary : db.dietary,
      cuisines: fromBody.cuisines.length > 0 ? fromBody.cuisines : db.cuisines,
      max_cook_time_minutes: fromBody.max_cook_time_minutes > 0
        ? fromBody.max_cook_time_minutes
        : db.max_cook_time_minutes,
      cooking_skill: fromBody.cooking_skill.trim()
        ? fromBody.cooking_skill
        : db.cooking_skill,
      household_size: fromBody.household_size > 0
        ? fromBody.household_size
        : db.household_size,
      excluded_ingredients: fromBody.excluded_ingredients.length > 0
        ? fromBody.excluded_ingredients
        : db.excluded_ingredients,
    };
  }

  // Legacy flat body fields — merge onto DB (never replace hard constraints with defaults).
  if (Array.isArray(body?.cuisines) || Array.isArray(body?.dietary) ||
      Array.isArray(body?.dietary_labels) || Array.isArray(body?.preferred_cuisines)) {
    const dietary = stringArray(body?.dietary ?? body?.dietary_labels);
    const cuisines = stringArray(body?.cuisines ?? body?.preferred_cuisines);
    return {
      ...db,
      dietary: dietary.length > 0 ? dietary : db.dietary,
      cuisines: cuisines.length > 0 ? cuisines : db.cuisines,
      household_size:
        typeof body?.household_size === 'number'
          ? body.household_size
          : db.household_size,
    };
  }

  return db;
}
