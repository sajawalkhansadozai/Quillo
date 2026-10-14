/** Checklist 4.1 — clean search terms before API / cache lookups. */
export function normaliseSearchTerm(term: string): string {
  return term
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ');
}

/** Checklist 5.1 — UK → US synonym expansion for US-centric recipe APIs. */
const UK_TO_US_SYNONYMS: Record<string, string> = {
  prawn: 'shrimp',
  aubergine: 'eggplant',
  courgette: 'zucchini',
  coriander: 'cilantro',
  steak: 'beef steak',
  mince: 'ground beef',
  mincemeat: 'ground beef',
  chips: 'potato fries',
  biscuit: 'cookie',
  rocket: 'arugula',
  'spring onion': 'scallion',
  swede: 'rutabaga',
  mangetout: 'snow peas',
  'double cream': 'heavy cream',
  crisps: 'potato chips',
};

export function expandUkSynonyms(normalised: string): string {
  const term = normaliseSearchTerm(normalised);
  if (!term) return term;

  if (UK_TO_US_SYNONYMS[term]) {
    return `${term} ${UK_TO_US_SYNONYMS[term]}`;
  }

  // Multi-word keys (e.g. "spring onion", "double cream")
  const multiKeys = Object.keys(UK_TO_US_SYNONYMS)
    .filter((k) => k.includes(' '))
    .sort((a, b) => b.length - a.length);

  for (const key of multiKeys) {
    if (term === key || term.includes(` ${key} `) || term.startsWith(`${key} `) ||
      term.endsWith(` ${key}`)) {
      return `${term} ${UK_TO_US_SYNONYMS[key]}`;
    }
  }

  return term;
}

export function searchQueriesForApis(raw: string): {
  normalised: string;
  expanded: string;
} {
  const normalised = normaliseSearchTerm(raw);
  return {
    normalised,
    expanded: expandUkSynonyms(normalised),
  };
}
