import type { QuilloRecipePayload } from './recipe_types.ts';
import type { UserRecipePreferences } from './user_preferences.ts';

const CUISINE_KEYWORDS: Record<string, string[]> = {
  italian: ['italian', 'pasta', 'pizza', 'risotto', 'carbonara', 'lasagna', 'pesto', 'gnocchi'],
  french: ['french', 'croissant', 'ratatouille', 'bouillabaisse', 'quiche'],
  spanish: ['spanish', 'paella', 'tapas', 'chorizo'],
  greek: ['greek', 'gyro', 'tzatziki', 'feta', 'souvlaki'],
  turkish: ['turkish', 'kebab', 'lahmacun', 'baklava'],
  lebanese: ['lebanese', 'hummus', 'falafel', 'shawarma', 'tabbouleh'],
  'middle eastern': ['middle eastern', 'hummus', 'falafel', 'shawarma', 'tahini'],
  moroccan: ['moroccan', 'tagine', 'couscous', 'harissa'],
  persian: ['persian', 'tahdig', 'saffron', 'koobideh'],
  indian: ['indian', 'curry', 'tikka', 'masala', 'biryani', 'paneer', 'dal', 'naan'],
  pakistani: ['pakistani', 'biryani', 'karahi', 'nihari', 'achar'],
  bangladeshi: ['bangladeshi', 'biryani', 'bhuna'],
  thai: ['thai', 'pad thai', 'tom yum', 'green curry', 'basil'],
  vietnamese: ['vietnamese', 'pho', 'banh mi', 'spring roll'],
  chinese: ['chinese', 'stir fry', 'dim sum', 'wonton', 'fried rice'],
  japanese: ['japanese', 'ramen', 'sushi', 'miso', 'teriyaki', 'udon'],
  korean: ['korean', 'kimchi', 'bibimbap', 'bulgogi', 'gochujang'],
  indonesian: ['indonesian', 'nasi goreng', 'satay', 'rendang'],
  malaysian: ['malaysian', 'laksa', 'nasi lemak'],
  filipino: ['filipino', 'adobo', 'lumpia'],
  singaporean: ['singapore', 'chilli crab', 'laksa'],
  mexican: ['mexican', 'taco', 'burrito', 'enchilada', 'quesadilla', 'salsa'],
  'tex-mex': ['tex-mex', 'tex mex', 'fajita', 'nachos'],
  caribbean: ['caribbean', 'jerk', 'plantain', 'ackee'],
  brazilian: ['brazilian', 'feijoada', 'pao de queijo'],
  peruvian: ['peruvian', 'ceviche', 'aji'],
  argentinian: ['argentinian', 'asado', 'empanada', 'chimichurri'],
  american: ['american', 'burger', 'bbq', 'mac and cheese', 'wings'],
  'southern us': ['southern', 'gumbo', 'biscuit', 'grits'],
  'cajun / creole': ['cajun', 'creole', 'jambalaya'],
  british: ['british', 'fish and chips', 'shepherd', 'bangers'],
  irish: ['irish', 'colcannon', 'soda bread'],
  german: ['german', 'schnitzel', 'bratwurst', 'sauerkraut'],
  scandinavian: ['scandinavian', 'smorrebrod', 'gravlax'],
  polish: ['polish', 'pierogi', 'kielbasa'],
  russian: ['russian', 'borscht', 'pelmeni'],
  hungarian: ['hungarian', 'goulash', 'paprika'],
  ethiopian: ['ethiopian', 'injera', 'berbere'],
  'west african': ['west african', 'jollof', 'egusi'],
  'south african': ['south african', 'bobotie', 'biltong'],
  australian: ['australian', 'lamington', 'pavlova'],
  fusion: ['fusion'],
  international: ['international'],
};

const DIETARY_EXCLUSIONS: Record<string, string[]> = {
  vegan: [
    'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak',
    'fish', 'salmon', 'tuna', 'prawn', 'shrimp', 'crab', 'milk', 'cheese',
    'butter', 'cream', 'yogurt', 'egg', 'honey',
  ],
  vegetarian: [
    'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak',
    'fish', 'salmon', 'tuna', 'prawn', 'shrimp', 'crab',
  ],
  pescatarian: [
    'chicken', 'beef', 'pork', 'lamb', 'bacon', 'ham', 'sausage', 'steak',
  ],
  halal: ['pork', 'bacon', 'ham', 'wine', 'beer', 'alcohol', 'lard'],
  kosher: ['pork', 'bacon', 'ham', 'shellfish', 'prawn', 'shrimp', 'crab'],
  'gluten-free': ['wheat', 'flour', 'bread', 'pasta', 'noodle', 'barley', 'rye'],
  'wheat-free': ['wheat', 'flour', 'bread', 'pasta', 'semolina'],
  'dairy-free': ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'whey'],
  'lactose-free': ['milk', 'cheese', 'butter', 'cream', 'yogurt'],
  'egg-free': ['egg', 'mayonnaise', 'meringue'],
  'nut-free': ['almond', 'walnut', 'cashew', 'pecan', 'hazelnut', 'pistachio'],
  'peanut-free': ['peanut', 'groundnut'],
  'tree nut-free': ['almond', 'walnut', 'cashew', 'pecan', 'hazelnut', 'pistachio'],
  'soy-free': ['soy', 'tofu', 'tempeh', 'edamame', 'miso'],
  'sesame-free': ['sesame', 'tahini'],
  'shellfish-free': ['prawn', 'shrimp', 'crab', 'lobster', 'mussel', 'clam', 'oyster'],
  'fish-free': ['fish', 'salmon', 'tuna', 'cod', 'anchovy'],
  'no alcohol': ['wine', 'beer', 'vodka', 'rum', 'whisky', 'sake', 'alcohol'],
  'no red meat': ['beef', 'lamb', 'pork', 'bacon', 'steak', 'veal'],
  'no pork': ['pork', 'bacon', 'ham', 'prosciutto', 'chorizo', 'lard'],
  'low fodmap': ['garlic', 'onion', 'wheat', 'apple', 'honey'],
  keto: ['rice', 'pasta', 'bread', 'potato', 'sugar'],
  paleo: ['rice', 'pasta', 'bread', 'beans', 'lentil', 'dairy', 'cheese'],
};

function recipeText(recipe: QuilloRecipePayload): string {
  const parts: string[] = [recipe.title ?? ''];
  for (const i of recipe.ingredients_used ?? []) {
    if (i?.name) parts.push(i.name);
  }
  for (const i of recipe.missing_ingredients ?? []) {
    if (i?.name) parts.push(i.name);
  }
  for (const s of recipe.steps ?? []) {
    if (s?.instruction) parts.push(s.instruction);
  }
  return parts.join(' ').toLowerCase();
}

function containsAny(haystack: string, needles: string[]): boolean {
  return needles.some((n) => haystack.includes(n));
}

function maxDifficultyRank(skill: string): number {
  switch (skill.toLowerCase()) {
    case 'beginner':
      return 1;
    case 'intermediate':
    case 'home cook':
      return 2;
    case 'advanced':
    case 'confident':
      return 3;
    default:
      return 3;
  }
}

function difficultyRank(difficulty: string | undefined): number {
  switch ((difficulty ?? 'medium').toLowerCase()) {
    case 'easy':
      return 1;
    case 'hard':
      return 3;
    default:
      return 2;
  }
}

function matchPercent(recipe: QuilloRecipePayload): number {
  const used = recipe.ingredients_used?.length ?? 0;
  const missing = recipe.missing_ingredients?.length ?? 0;
  const total = used + missing;
  if (total === 0) return 100;
  return Math.round((used / total) * 100);
}

export function recipeMatchesPreferences(
  recipe: QuilloRecipePayload,
  prefs: UserRecipePreferences,
): boolean {
  if (
    prefs.max_cook_time_minutes > 0 &&
    (recipe.cook_time_minutes ?? 0) > prefs.max_cook_time_minutes
  ) {
    return false;
  }

  if (difficultyRank(recipe.difficulty) > maxDifficultyRank(prefs.cooking_skill)) {
    return false;
  }

  const text = recipeText(recipe);
  for (const label of prefs.dietary) {
    const banned = DIETARY_EXCLUSIONS[label.toLowerCase()];
    if (banned?.length && containsAny(text, banned)) return false;
  }
  return true;
}

export function recipePreferenceScore(
  recipe: QuilloRecipePayload,
  prefs: UserRecipePreferences,
): number {
  if (!recipeMatchesPreferences(recipe, prefs)) return -1;

  let points = 0;
  const text = recipeText(recipe);

  for (const cuisine of prefs.cuisines) {
    const key = cuisine.toLowerCase();
    const keywords = CUISINE_KEYWORDS[key] ?? [key];
    if (containsAny(text, keywords)) points += 10;
  }

  if (prefs.max_cook_time_minutes > 0) {
    const slack = prefs.max_cook_time_minutes - recipe.cook_time_minutes;
    if (slack >= 0) points += 2;
    if (slack >= 15) points += 1;
  }

  points += Math.floor(matchPercent(recipe) / 10);
  return points;
}

export function applyRecipePreferences(
  recipes: QuilloRecipePayload[],
  prefs: UserRecipePreferences,
  options?: { strictCuisine?: boolean; limit?: number },
): QuilloRecipePayload[] {
  const hasAny =
    prefs.dietary.length > 0 ||
    prefs.cuisines.length > 0 ||
    prefs.max_cook_time_minutes > 0 ||
    prefs.cooking_skill.length > 0;

  if (!hasAny) {
    const copy = [...recipes];
    return options?.limit ? copy.slice(0, options.limit) : copy;
  }

  let filtered = recipes.filter((r) => recipeMatchesPreferences(r, prefs));

  if (options?.strictCuisine && prefs.cuisines.length > 0) {
    const cuisineMatched = filtered.filter((r) => {
      const text = recipeText(r);
      return prefs.cuisines.some((c) => {
        const key = c.toLowerCase();
        const keywords = CUISINE_KEYWORDS[key] ?? [key];
        return containsAny(text, keywords);
      });
    });
    if (cuisineMatched.length > 0) filtered = cuisineMatched;
  }

  filtered.sort((a, b) => {
    const sa = recipePreferenceScore(a, prefs);
    const sb = recipePreferenceScore(b, prefs);
    if (sa !== sb) return sb - sa;
    return matchPercent(b) - matchPercent(a);
  });

  return options?.limit ? filtered.slice(0, options.limit) : filtered;
}

export function pickFeaturedRecipe(
  recipes: QuilloRecipePayload[],
  prefs: UserRecipePreferences,
): QuilloRecipePayload | null {
  const pool = applyRecipePreferences(recipes, prefs);
  if (pool.length === 0) return null;
  const dayIndex = new Date().getDate() % pool.length;
  return pool[dayIndex] ?? null;
}
