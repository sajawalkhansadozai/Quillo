import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface UserRecipePreferences {
  dietary: string[];
  cuisines: string[];
  max_cook_time_minutes: number;
  cooking_skill: string;
  household_size: number;
}

export const EMPTY_PREFERENCES: UserRecipePreferences = {
  dietary: [],
  cuisines: [],
  max_cook_time_minutes: 45,
  cooking_skill: 'Intermediate',
  household_size: 2,
};

export function preferencesFromBody(
  raw?: Record<string, unknown>,
): UserRecipePreferences | null {
  if (!raw || typeof raw !== 'object') return null;

  return {
    dietary: Array.isArray(raw.dietary)
      ? raw.dietary.filter((v): v is string => typeof v === 'string')
      : [],
    cuisines: Array.isArray(raw.cuisines)
      ? raw.cuisines.filter((v): v is string => typeof v === 'string')
      : [],
    max_cook_time_minutes:
      typeof raw.max_cook_time_minutes === 'number'
        ? raw.max_cook_time_minutes
        : typeof raw.maxCookTimeMinutes === 'number'
        ? raw.maxCookTimeMinutes
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
  };
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
        .select('dietary_labels, cooking_skill, max_cook_time')
        .eq('user_id', userId)
        .maybeSingle(),
    ]);

    return {
      dietary: Array.isArray(prefsRow.data?.dietary_labels)
        ? prefsRow.data.dietary_labels.filter((v): v is string => typeof v === 'string')
        : [],
      cuisines: Array.isArray(userRow.data?.preferred_cuisine)
        ? userRow.data.preferred_cuisine.filter((v): v is string => typeof v === 'string')
        : [],
      max_cook_time_minutes: (prefsRow.data?.max_cook_time as number | null) ?? 45,
      cooking_skill: (prefsRow.data?.cooking_skill as string | null) ?? 'Intermediate',
      household_size: (userRow.data?.household_size as number | null) ?? 2,
    };
  } catch {
    return { ...EMPTY_PREFERENCES };
  }
}

export async function resolveUserPreferences(
  supabase: SupabaseClient,
  userId: string,
  body?: Record<string, unknown>,
): Promise<UserRecipePreferences> {
  const fromBody = preferencesFromBody(body?.preferences as Record<string, unknown> | undefined);
  if (fromBody) return fromBody;

  // Legacy flat body fields from older clients.
  if (Array.isArray(body?.cuisines) || Array.isArray(body?.dietary)) {
    return {
      ...EMPTY_PREFERENCES,
      cuisines: Array.isArray(body?.cuisines)
        ? body.cuisines.filter((v): v is string => typeof v === 'string')
        : [],
      dietary: Array.isArray(body?.dietary)
        ? body.dietary.filter((v): v is string => typeof v === 'string')
        : [],
    };
  }

  return loadUserPreferences(supabase, userId);
}
