/** Strip non-food / non-cooking items before recipe generation (checklist 2.6). */

const BANNED_NON_FOOD = /\b(carrier\s*bag|shopping\s*bag|bag\s*charge|plastic\s*bag|detergent|bleach|disinfectant|cleaner|cleaning|soap|shampoo|toothpaste|deodorant|cosmetics?|makeup|lotion|wipes?|batter(?:y|ies)|light\s*bulb|toilet\s*roll|kitchen\s*roll|medicine|paracetamol|ibuprofen|vitamin\s*tablet|supplement\s*tablet|pet\s*food|cat\s*litter|dog\s*food|cigarette|tobacco|lottery|gift\s*card|delivery\s*fee|service\s*charge|vat|subtotal|total|loyalty)\b/i;

export function isFoodIngredientName(name: string): boolean {
  const t = name.trim();
  if (t.length < 2) return false;
  if (BANNED_NON_FOOD.test(t)) return false;
  return true;
}

export function filterFoodIngredients<T extends { name?: string | null }>(
  items: T[],
): T[] {
  return items.filter((i) => isFoodIngredientName(String(i.name ?? '')));
}
