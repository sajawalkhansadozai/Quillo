import '../models/generated_recipe.dart';
import '../models/pantry_item.dart';
import '../utils/pantry_quantity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PantryRecipeMatcher — scores catalog recipes against the local pantry
// ─────────────────────────────────────────────────────────────────────────────

/// A recipe scored against what's in the pantry.
class PantryMeal {
  final GeneratedRecipe recipe;

  /// Recipe ingredient names the pantry covers, with the matching item.
  final List<({String name, PantryItem item})> have;

  /// Recipe ingredients the pantry doesn't cover (name + amount).
  final List<({String name, String amount})> missing;

  /// Use-first / use-soon pantry items this recipe uses.
  final List<PantryItem> usesExpiring;

  const PantryMeal({
    required this.recipe,
    required this.have,
    required this.missing,
    required this.usesExpiring,
  });

  int get total => have.length + missing.length;
  bool get hasAll => total > 0 && missing.isEmpty;
  double get ratio => total == 0 ? 0 : have.length / total;

  bool uses(PantryItem item) => have.any((h) => h.item.id == item.id);
}

class PantryRecipeMatcher {
  PantryRecipeMatcher._();

  static const _synonyms = <String, List<String>>{
    'scallion': ['spring onion', 'green onion'],
    'spring onion': ['scallion', 'green onion'],
    'cilantro': ['coriander'],
    'coriander': ['cilantro'],
    'zucchini': ['courgette'],
    'courgette': ['zucchini'],
    'eggplant': ['aubergine'],
    'aubergine': ['eggplant'],
    'bell pepper': ['pepper', 'capsicum'],
    'capsicum': ['bell pepper', 'pepper'],
    'ground beef': ['mince', 'minced beef', 'beef mince'],
    'mince': ['ground beef', 'minced beef'],
    'chickpea': ['garbanzo'],
    'garbanzo': ['chickpea'],
    'shrimp': ['prawn'],
    'prawn': ['shrimp'],
    'arugula': ['rocket'],
    'rocket': ['arugula'],
    'yogurt': ['yoghurt'],
    'yoghurt': ['yogurt'],
  };

  static String _norm(String s) {
    var t = s.toLowerCase().trim();
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Drop common prep words so "chopped onion" ≈ "onion".
    for (final w in [
      'fresh', 'chopped', 'diced', 'sliced', 'minced', 'large', 'small',
      'medium', 'organic', 'free range', 'extra virgin',
    ]) {
      t = t.replaceAll(RegExp('\\b$w\\b'), ' ');
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.endsWith('s') && t.length > 3 ? t.substring(0, t.length - 1) : t;
  }

  static Set<String> _aliases(String norm) {
    final out = {norm};
    for (final e in _synonyms.entries) {
      final key = _norm(e.key);
      if (norm.contains(key) || key.contains(norm)) {
        out.addAll(e.value.map(_norm));
        out.add(key);
      }
      for (final v in e.value) {
        final vn = _norm(v);
        if (norm.contains(vn) || vn.contains(norm)) {
          out.add(key);
          out.addAll(e.value.map(_norm));
        }
      }
    }
    return out;
  }

  static PantryItem? matchIngredient(String ingredient, List<PantryItem> items) {
    final ing = _norm(ingredient);
    if (ing.isEmpty) return null;
    final ingAliases = _aliases(ing);
    PantryItem? best;
    var bestScore = 0;
    for (final item in items) {
      final p = _norm(item.name);
      if (p.isEmpty) continue;
      final pantryAliases = _aliases(p);
      var score = 0;
      if (ing == p) {
        score = 100;
      } else if (ingAliases.any(pantryAliases.contains)) {
        score = 90;
      } else if (PantryQuantity.specificSubset(ing, p) ||
          PantryQuantity.specificSubset(p, ing)) {
        // "onion" matches "red onion", but "oil" does not match "olive oil".
        score = 80;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 70 ? best : null;
  }

  static const _titleStopWords = {
    'a', 'an', 'and', 'the', 'with', 'of', 'for', 'in', 'on', 'to', 'from', 'or',
  };

  /// Stable key so the same dish never appears twice in pantry meal lists.
  static String recipeDedupeKey(GeneratedRecipe r) {
    final id = r.id?.trim();
    if (id != null && id.isNotEmpty) return 'id:$id';
    final source = r.externalSource?.trim();
    final sourceId = r.externalId?.trim();
    if (source != null &&
        source.isNotEmpty &&
        sourceId != null &&
        sourceId.isNotEmpty) {
      return 'ext:$source:$sourceId';
    }
    return 'title:${_norm(r.title)}';
  }

  static String _stemToken(String w) {
    if (w.endsWith('ies') && w.length > 4) {
      return '${w.substring(0, w.length - 3)}y';
    }
    if (w.endsWith('ses') && w.length > 4) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('s') && w.length > 3 && !w.endsWith('ss')) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  /// Significant title words used to collapse near-identical recipe variants
  /// (e.g. "Prawn … Bap" vs "Prawn Cocktail … Baps").
  static Set<String> titleTokens(String title) {
    final raw = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (raw.isEmpty) return {};
    final out = <String>{};
    for (final part in raw.split(' ')) {
      if (part.isEmpty || _titleStopWords.contains(part)) continue;
      final w = _stemToken(part);
      if (w.isNotEmpty) out.add(w);
    }
    return out;
  }

  /// Sorted token key so "Bap" / "Baps" variants share one list slot.
  static String titleFamilyKey(String title) {
    final tokens = titleTokens(title).toList()..sort();
    return tokens.join(' ');
  }

  /// Prefer title-family collapse for meal lists; fall back to id / source.
  static String listDedupeKey(GeneratedRecipe r) {
    final family = titleFamilyKey(r.title);
    if (family.split(' ').where((t) => t.isNotEmpty).length >= 3) {
      return 'family:$family';
    }
    return recipeDedupeKey(r);
  }

  /// True when two titles are near-duplicates of the same dish.
  static bool isNearTitleVariant(String a, String b) {
    final ta = titleTokens(a);
    final tb = titleTokens(b);
    if (ta.isEmpty || tb.isEmpty) return false;
    if (ta.containsAll(tb) || tb.containsAll(ta)) return true;
    final intersection = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    if (union == 0) return false;
    // Same dish with a small wording tweak (e.g. optional "Cocktail").
    if (intersection / union >= 0.65) return true;
    final smaller = ta.length < tb.length ? ta.length : tb.length;
    return smaller > 0 && intersection / smaller >= 0.85;
  }

  /// Keep the first (best-ranked) meal of each near-title family.
  static List<PantryMeal> collapseNearTitleVariants(List<PantryMeal> meals) {
    final kept = <PantryMeal>[];
    for (final meal in meals) {
      final isVariant = kept.any(
        (k) => isNearTitleVariant(k.recipe.title, meal.recipe.title),
      );
      if (!isVariant) kept.add(meal);
    }
    return kept;
  }

  /// Drop near-title variants from a catalog before matching / display.
  static List<GeneratedRecipe> uniqueRecipes(List<GeneratedRecipe> recipes) {
    final seen = <String>{};
    final unique = <GeneratedRecipe>[];
    for (final r in recipes) {
      final key = listDedupeKey(r);
      if (key == 'title:' || key == 'family:' || !seen.add(key)) continue;
      // Also skip if an already-kept recipe is a near title variant.
      if (unique.any((u) => isNearTitleVariant(u.title, r.title))) continue;
      unique.add(r);
    }
    return unique;
  }

  /// Recipes the pantry covers at least [minRatio] of, best first: recipes
  /// that use expiring items rank above fuller matches.
  /// Exact duplicates (id / external id / title) and near-title variants of
  /// the same dish appear at most once, so "Best match" is not repeated under
  /// "More matches".
  static List<PantryMeal> match(
    List<GeneratedRecipe> catalog,
    List<PantryItem> items, {
    double minRatio = 0.6,
  }) {
    if (items.isEmpty || catalog.isEmpty) return [];
    final expiringIds = items
        .where((i) => (i.daysUntilExpiry ?? 999) <= 5)
        .map((i) => i.id)
        .toSet();
    final meals = <PantryMeal>[];
    final seenRecipes = <String>{};
    for (final r in uniqueRecipes(catalog)) {
      final dedupeKey = listDedupeKey(r);
      if (dedupeKey == 'title:' ||
          dedupeKey == 'family:' ||
          seenRecipes.contains(dedupeKey)) {
        continue;
      }
      seenRecipes.add(dedupeKey);

      final ingredients = <({String name, String amount})>[
        ...r.ingredientsUsed.map((i) => (name: i.name, amount: i.amount)),
        ...r.missingIngredients.map((i) => (name: i.name, amount: i.amount)),
      ];
      if (ingredients.isEmpty) continue;
      final have = <({String name, PantryItem item})>[];
      final missing = <({String name, String amount})>[];
      final expiring = <String, PantryItem>{};
      for (final ing in ingredients) {
        final m = matchIngredient(ing.name, items);
        if (m == null) {
          missing.add(ing);
          continue;
        }
        have.add((name: ing.name, item: m));
        if (expiringIds.contains(m.id)) expiring[m.id] = m;
      }
      if (have.isEmpty) continue;
      final meal = PantryMeal(
        recipe: r,
        have: have,
        missing: missing,
        usesExpiring: expiring.values.toList()
          ..sort((a, b) => (a.daysUntilExpiry ?? 999)
              .compareTo(b.daysUntilExpiry ?? 999)),
      );
      if (meal.ratio >= minRatio) meals.add(meal);
    }
    meals.sort((a, b) {
      final byExpiring =
          b.usesExpiring.length.compareTo(a.usesExpiring.length);
      if (byExpiring != 0) return byExpiring;
      return b.ratio.compareTo(a.ratio);
    });
    return collapseNearTitleVariants(meals);
  }

  /// Meals that use [item], best first.
  static List<PantryMeal> forItem(List<PantryMeal> meals, PantryItem item) =>
      meals.where((m) => m.uses(item)).toList();

  /// Items whose best-before falls within [days] (includes expired).
  static List<PantryItem> expiringWithin(List<PantryItem> items, int days) =>
      items.where((i) => (i.daysUntilExpiry ?? 9999) <= days).toList()
        ..sort((a, b) =>
            (a.daysUntilExpiry ?? 0).compareTo(b.daysUntilExpiry ?? 0));
}
