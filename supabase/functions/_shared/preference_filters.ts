// Maps the app's preference chip labels (see lib/screens/onboarding/preferences_screen.dart)
// onto Edamam's recipe-search filters so search results honour what the user picked.
//
// Edamam v2 search supports three relevant filters:
//   cuisineType — OR semantics across multiple values
//   health      — AND semantics across multiple values (allergens / lifestyle)
//   diet        — AND semantics across multiple values
//
// Only well-known Edamam tokens are mapped; ambiguous app labels with no Edamam
// equivalent are intentionally skipped so we never send an invalid value (a bad
// token makes Edamam reject the whole request and return zero results).

export interface EdamamSearchFilters {
  cuisineType: string[];
  health: string[];
  diet: string[];
  maxReadyTime?: number;
}

// App cuisine label → Edamam cuisineType. Edamam's taxonomy is coarse, so several
// app cuisines collapse into the same bucket (e.g. Pakistani → indian).
const CUISINE_TO_EDAMAM: Record<string, string> = {
  'italian': 'italian',
  'french': 'french',
  'spanish': 'mediterranean',
  'greek': 'greek',
  'turkish': 'middle eastern',
  'lebanese': 'middle eastern',
  'middle eastern': 'middle eastern',
  'moroccan': 'middle eastern',
  'persian': 'middle eastern',
  'indian': 'indian',
  'pakistani': 'indian',
  'bangladeshi': 'indian',
  'thai': 'south east asian',
  'vietnamese': 'south east asian',
  'chinese': 'chinese',
  'japanese': 'japanese',
  'korean': 'korean',
  'indonesian': 'south east asian',
  'malaysian': 'south east asian',
  'filipino': 'south east asian',
  'singaporean': 'south east asian',
  'mexican': 'mexican',
  'tex-mex': 'mexican',
  'caribbean': 'caribbean',
  'brazilian': 'south american',
  'peruvian': 'south american',
  'argentinian': 'south american',
  'american': 'american',
  'southern us': 'american',
  'cajun / creole': 'american',
  'british': 'british',
  'irish': 'british',
  'german': 'central europe',
  'scandinavian': 'nordic',
  'polish': 'eastern europe',
  'russian': 'eastern europe',
  'hungarian': 'eastern europe',
  'ethiopian': 'world',
  'west african': 'world',
  'south african': 'world',
  'australian': 'world',
  'fusion': 'world',
  'international': 'world',
};

// App dietary / lifestyle label → Edamam health labels (one app label can imply several).
const DIETARY_TO_HEALTH: Record<string, string[]> = {
  'vegan': ['vegan'],
  'vegetarian': ['vegetarian'],
  'pescatarian': ['pescatarian'],
  'halal': ['pork-free', 'alcohol-free'],
  'kosher': ['kosher'],
  'gluten-free': ['gluten-free'],
  'wheat-free': ['wheat-free'],
  'dairy-free': ['dairy-free'],
  'lactose-free': ['dairy-free'],
  'egg-free': ['egg-free'],
  'nut-free': ['tree-nut-free', 'peanut-free'],
  'peanut-free': ['peanut-free'],
  'tree nut-free': ['tree-nut-free'],
  'soy-free': ['soy-free'],
  'sesame-free': ['sesame-free'],
  'shellfish-free': ['shellfish-free'],
  'fish-free': ['fish-free'],
  'no alcohol': ['alcohol-free'],
  'no red meat': ['red-meat-free'],
  'no pork': ['pork-free'],
  'low fodmap': ['fodmap-free'],
  'diabetic-friendly': ['low-sugar'],
  'sugar-free': ['low-sugar'],
  'keto': ['keto-friendly'],
  'paleo': ['paleo'],
};

// App lifestyle label → Edamam diet labels.
const DIETARY_TO_DIET: Record<string, string[]> = {
  'low-carb': ['low-carb'],
  'high-protein': ['high-protein'],
  'high-fibre': ['high-fiber'],
  'low-sodium': ['low-sodium'],
};

function normalizeLabel(label: string): string {
  return label.trim().toLowerCase();
}

/**
 * Translate the user's selected cuisines + dietary labels into Edamam filters.
 * Unknown labels are ignored. Returns deduplicated value lists.
 */
export function mapPreferencesToEdamamFilters(
  cuisines: string[] = [],
  dietary: string[] = [],
  maxCookTimeMinutes = 0,
): EdamamSearchFilters {
  const cuisineType = new Set<string>();
  for (const c of cuisines) {
    const mapped = CUISINE_TO_EDAMAM[normalizeLabel(c)];
    if (mapped) cuisineType.add(mapped);
  }

  const health = new Set<string>();
  const diet = new Set<string>();
  for (const d of dietary) {
    const key = normalizeLabel(d);
    for (const h of DIETARY_TO_HEALTH[key] ?? []) health.add(h);
    for (const v of DIETARY_TO_DIET[key] ?? []) diet.add(v);
  }

  return {
    cuisineType: [...cuisineType],
    health: [...health],
    diet: [...diet],
    maxReadyTime: maxCookTimeMinutes > 0 ? maxCookTimeMinutes : undefined,
  };
}

export function hasAnyEdamamFilter(filters: EdamamSearchFilters): boolean {
  return (
    filters.cuisineType.length > 0 ||
    filters.health.length > 0 ||
    filters.diet.length > 0 ||
    (filters.maxReadyTime != null && filters.maxReadyTime > 0)
  );
}

export interface SpoonacularSearchFilters {
  diet?: string;
  intolerances: string[];
  cuisine: string[];
  maxReadyTime?: number;
}

const DIETARY_TO_SPOON_DIET: Record<string, string> = {
  vegan: 'vegan',
  vegetarian: 'vegetarian',
  pescatarian: 'pescetarian',
  keto: 'ketogenic',
  paleo: 'paleo',
  'gluten-free': 'gluten free',
};

const DIETARY_TO_SPOON_INTOLERANCE: Record<string, string[]> = {
  'dairy-free': ['dairy'],
  'lactose-free': ['dairy'],
  'egg-free': ['egg'],
  'nut-free': ['tree nut', 'peanut'],
  'peanut-free': ['peanut'],
  'tree nut-free': ['tree nut'],
  'soy-free': ['soy'],
  'sesame-free': ['sesame'],
  'shellfish-free': ['shellfish'],
  'fish-free': ['seafood'],
  'wheat-free': ['wheat'],
  'gluten-free': ['gluten'],
  halal: [], // enforced via post-filter (pork)
};

const CUISINE_TO_SPOON: Record<string, string> = {
  italian: 'italian',
  french: 'french',
  greek: 'greek',
  indian: 'indian',
  pakistani: 'indian',
  bangladeshi: 'indian',
  chinese: 'chinese',
  japanese: 'japanese',
  korean: 'korean',
  thai: 'thai',
  vietnamese: 'vietnamese',
  mexican: 'mexican',
  american: 'american',
  british: 'british',
  irish: 'irish',
  german: 'german',
  spanish: 'spanish',
  mediterranean: 'mediterranean',
  'middle eastern': 'middle eastern',
  turkish: 'middle eastern',
  lebanese: 'middle eastern',
};

export function mapPreferencesToSpoonacularFilters(
  cuisines: string[] = [],
  dietary: string[] = [],
  maxCookTimeMinutes = 0,
): SpoonacularSearchFilters {
  let diet: string | undefined;
  const intolerances = new Set<string>();
  const cuisine = new Set<string>();

  for (const d of dietary) {
    const key = normalizeLabel(d);
    const mappedDiet = DIETARY_TO_SPOON_DIET[key];
    if (mappedDiet && !diet) diet = mappedDiet;
    for (const item of DIETARY_TO_SPOON_INTOLERANCE[key] ?? []) {
      intolerances.add(item);
    }
  }

  for (const c of cuisines) {
    const mapped = CUISINE_TO_SPOON[normalizeLabel(c)];
    if (mapped) cuisine.add(mapped);
  }

  return {
    diet,
    intolerances: [...intolerances],
    cuisine: [...cuisine],
    maxReadyTime: maxCookTimeMinutes > 0 ? maxCookTimeMinutes : undefined,
  };
}

export function hasAnySpoonacularFilter(filters: SpoonacularSearchFilters): boolean {
  return (
    !!filters.diet ||
    filters.intolerances.length > 0 ||
    filters.cuisine.length > 0 ||
    (filters.maxReadyTime != null && filters.maxReadyTime > 0)
  );
}
