// Normalised recipe shape used across Edamam, BigOven, and Spoonacular.

export type RecipeApiSource = 'edamam' | 'bigoven' | 'spoonacular';

export interface NormalizedIngredient {
  name: string;
  amount: string;
}

export interface NormalizedInstruction {
  order: number;
  instruction: string;
}

export interface NormalizedNutrition {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface NormalizedSearchRecipe {
  /** Prefixed id: edamam_, bigoven_, spoon_ */
  id: string;
  title: string;
  image_url?: string;
  source: RecipeApiSource;
  cook_time: number;
  servings: number;
  cuisine?: string;
  dietary_labels: string[];
  nutrition: NormalizedNutrition;
  ingredients: NormalizedIngredient[];
  instructions: NormalizedInstruction[];
  relevance_score: number;
  /** How many APIs returned this dish (after dedupe). */
  source_count: number;
  /** Raw provider id without prefix. */
  source_id: string;
  source_url?: string;
}

export interface QuilloRecipePayload {
  id?: string;
  title: string;
  difficulty: string;
  cook_time_minutes: number;
  servings: number;
  steps: NormalizedInstruction[];
  ingredients_used: NormalizedIngredient[];
  missing_ingredients: NormalizedIngredient[];
  nutrition: NormalizedNutrition;
  image_url?: string;
  is_public?: boolean;
  external_source?: string;
  external_id?: string;
  relevance_score?: number;
  source_count?: number;
  cuisine?: string;
  dietary_labels?: string[];
}

export function difficultyFromMinutes(minutes: number): string {
  if (minutes <= 25) return 'easy';
  if (minutes <= 45) return 'medium';
  return 'hard';
}

export function prefixedId(source: RecipeApiSource, rawId: string): string {
  const prefix = source === 'spoonacular' ? 'spoon' : source;
  return `${prefix}_${rawId}`;
}

export function parsePrefixedId(prefixed: string): { source: RecipeApiSource; sourceId: string } | null {
  if (prefixed.startsWith('edamam_')) {
    return { source: 'edamam', sourceId: prefixed.slice('edamam_'.length) };
  }
  if (prefixed.startsWith('bigoven_')) {
    return { source: 'bigoven', sourceId: prefixed.slice('bigoven_'.length) };
  }
  if (prefixed.startsWith('spoon_')) {
    return { source: 'spoonacular', sourceId: prefixed.slice('spoon_'.length) };
  }
  return null;
}

export async function titleHash(title: string): Promise<string> {
  const hash = await crypto.subtle.digest(
    'SHA-1',
    new TextEncoder().encode(title.toLowerCase()),
  );
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function normalizedToQuillo(r: NormalizedSearchRecipe): QuilloRecipePayload {
  return {
    title: r.title,
    difficulty: difficultyFromMinutes(r.cook_time),
    cook_time_minutes: r.cook_time,
    servings: r.servings,
    steps: r.instructions,
    ingredients_used: r.ingredients,
    missing_ingredients: [],
    nutrition: r.nutrition,
    image_url: r.image_url,
    is_public: true,
    external_source: r.source,
    external_id: r.source_id,
    relevance_score: r.relevance_score,
    source_count: r.source_count,
    cuisine: r.cuisine,
    dietary_labels: r.dietary_labels,
  };
}
