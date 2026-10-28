import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pantry_item.dart';
import '../models/shopping_list.dart';
import '../utils/pantry_quantity.dart';
import 'local_db_service.dart';
import 'pantry_recipe_matcher.dart';
import 'pantry_sync_service.dart';

/// One item the user marked as used (kept locally for insights + restock).
class PantryUseEntry {
  final String name;
  final String emoji;
  final PantryLocation location;
  final DateTime usedAt;

  /// True when it was used on or before its best-before date.
  final bool rescued;

  const PantryUseEntry({
    required this.name,
    required this.emoji,
    required this.location,
    required this.usedAt,
    required this.rescued,
  });

  factory PantryUseEntry.fromJson(Map<String, dynamic> json) => PantryUseEntry(
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🥬',
        location: PantryLocation.fromId(json['location'] as String? ?? ''),
        usedAt: DateTime.tryParse(json['used_at'] as String? ?? '') ??
            DateTime.now(),
        rescued: json['rescued'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'location': location.name,
        'used_at': usedAt.toIso8601String(),
        'rescued': rescued,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// PantryService — local smart pantry inventory
// ─────────────────────────────────────────────────────────────────────────────

class PantryService {
  PantryService._();

  static Future<List<PantryItem>> getAll() => LocalDbService.loadAllPantryItems();

  static Future<PantryItem?> getById(String id) =>
      LocalDbService.loadPantryItem(id);

  static Future<void> save(PantryItem item) async {
    await LocalDbService.savePantryItem(item);
    // Fire-and-forget cloud sync when available.
    // ignore: unawaited_futures
    _syncUpsert(item);
  }

  static Future<void> delete(String id) async {
    await LocalDbService.deletePantryItem(id);
    // ignore: unawaited_futures
    _syncDelete(id);
  }

  static Future<void> _syncUpsert(PantryItem item) async {
    try {
      // Deferred import pattern avoided — sync via optional callback.
      await PantrySync.upsert(item);
    } catch (_) {}
  }

  static Future<void> _syncDelete(String id) async {
    try {
      await PantrySync.delete(id);
    } catch (_) {}
  }

  static const _processedScansKey = 'pantry_processed_scan_ids';
  static const _processedFingerprintsKey = 'pantry_processed_receipt_fingerprints';
  static const _collectionEnabledKey = 'pantry_collection_enabled';
  static const _shelfOverridesKey = 'pantry_shelf_overrides_v1';

  /// Days past best-before before a row is archived from the active pantry (2.5).
  static const archiveGraceDays = 14;

  static Map<String, int> _shelfOverrides = {};
  static bool _shelfOverridesLoaded = false;

  static Future<PantryItem> addManual({
    required String name,
    required double quantity,
    required String unit,
    required PantryLocation location,
    DateTime? bestBefore,
    bool estimated = true,
    String? sourceNote,
    String? scanId,
  }) =>
      addOrMerge(
        name: name,
        quantity: quantity,
        unit: unit,
        location: location,
        bestBefore: bestBefore,
        estimated: estimated,
        sourceNote: sourceNote ?? 'Added manually',
        scanId: scanId,
      );

  /// Normalised ingredient key so "PHILA LGHT" and "Philadelphia Light" merge (2.3).
  static String normalizeIngredientKey(String raw) {
    var t = raw.toLowerCase().trim();
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    for (final e in _receiptAliases.entries) {
      if (t == e.key || t.contains(e.key)) {
        t = e.value;
        break;
      }
    }
    for (final w in const [
      'fresh', 'chopped', 'diced', 'sliced', 'minced', 'large', 'small',
      'medium', 'organic', 'free range', 'extra virgin', 'lght', 'light',
    ]) {
      t = t.replaceAll(RegExp('\\b${RegExp.escape(w)}\\b'), ' ');
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.endsWith('s') && t.length > 3) t = t.substring(0, t.length - 1);
    return t;
  }

  static const _receiptAliases = <String, String>{
    'phila': 'philadelphia',
    'phila lght': 'philadelphia',
    'phila light': 'philadelphia',
    'philadelphia light': 'philadelphia',
    'philadelphia lght': 'philadelphia',
    's-milk': 'milk',
    'smilk': 'milk',
    'semi skimmed milk': 'milk',
    'semi-skimmed milk': 'milk',
    'skimmed milk': 'milk',
    'whole milk': 'milk',
    'full fat milk': 'milk',
    'free range egg': 'egg',
    'free range eggs': 'egg',
    'fr eggs': 'egg',
    'fr egg': 'egg',
    'ckn': 'chicken',
    'chk breast': 'chicken breast',
    'chicken brst': 'chicken breast',
    'bsto': 'pesto',
    'tom puree': 'tomato puree',
    'chopped tom': 'chopped tomato',
    'passata': 'tomato passata',
    'grd beef': 'beef mince',
    'beef mince': 'beef mince',
    'minced beef': 'beef mince',
    'saus': 'sausage',
    'pot': 'potato',
    'new pot': 'potato',
    'spuds': 'potato',
    'ban': 'banana',
    'strawbs': 'strawberry',
    'bluebs': 'blueberry',
    'rasp': 'raspberry',
    'avoc': 'avocado',
    'courg': 'courgette',
    'aumbergine': 'aubergine',
    'bell pep': 'bell pepper',
    'red pep': 'bell pepper',
    'grn bean': 'green bean',
    'brussel': 'brussels sprout',
    'yog': 'yogurt',
    'greekyog': 'yogurt',
    'chedd': 'cheddar',
    'mozarella': 'mozzarella',
    'moz': 'mozzarella',
    'oj': 'orange juice',
    'cranberry jce': 'cranberry juice',
  };

  /// Content fingerprint so the same receipt can't double-fill (2.1).
  static String receiptFingerprint(
    Iterable<({String name, double? quantity, String? unit})> items,
  ) {
    final parts = items
        .map((i) {
          final k = normalizeIngredientKey(i.name);
          if (k.isEmpty) return null;
          final q = i.quantity ?? 1;
          final u = (i.unit ?? '').trim().toLowerCase();
          return '$k|$q|$u';
        })
        .whereType<String>()
        .toList()
      ..sort();
    return parts.join('::');
  }

  static Future<bool> isCollectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_collectionEnabledKey) ?? true;
  }

  static Future<void> setCollectionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_collectionEnabledKey, enabled);
  }

  static Future<void> clearAllItems() async {
    final all = await getAll();
    for (final item in all) {
      await delete(item.id);
    }
  }

  static Future<void> ensureShelfOverridesLoaded() async {
    if (_shelfOverridesLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_shelfOverridesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _shelfOverrides = {
            for (final e in decoded.entries)
              e.key.toString(): (e.value as num).toInt(),
          };
        }
      }
    } catch (_) {}
    _shelfOverridesLoaded = true;
  }

  /// Checklist 3.4 — remember a user-corrected shelf life for this ingredient.
  static Future<void> rememberShelfCorrection(PantryItem item) async {
    if (item.bestBefore == null || item.bestBeforeEstimated) return;
    final added = DateTime(item.addedAt.year, item.addedAt.month, item.addedAt.day);
    final best = DateTime(
      item.bestBefore!.year,
      item.bestBefore!.month,
      item.bestBefore!.day,
    );
    final days = best.difference(added).inDays;
    if (days < 1 || days > 400) return;
    await ensureShelfOverridesLoaded();
    final key = item.ingredientKey?.isNotEmpty == true
        ? item.ingredientKey!
        : normalizeIngredientKey(item.name);
    if (key.isEmpty) return;
    _shelfOverrides[key] = days;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_shelfOverridesKey, jsonEncode(_shelfOverrides));
    } catch (_) {}
  }

  /// One-tap frozen mark (3.5).
  static Future<PantryItem> markFrozen(PantryItem item) async {
    final updated = item.copyWith(
      location: PantryLocation.freezer,
      categoryLabel: PantryLocation.freezer.sectionTitle,
      bestBefore: defaultBestBefore(PantryLocation.freezer, item.name),
      bestBeforeEstimated: true,
      emoji: emojiFor(item.name, PantryLocation.freezer),
    );
    await save(updated);
    return updated;
  }

  /// Active pantry only — past shelf-life (+ grace) rows are archived (2.5).
  static Future<List<PantryItem>> getActive() async {
    final all = await getAll();
    final active = <PantryItem>[];
    for (final item in all) {
      if (_shouldArchive(item)) {
        try {
          await delete(item.id);
        } catch (_) {}
        continue;
      }
      active.add(item);
    }
    return active;
  }

  static bool _shouldArchive(PantryItem item) {
    final days = item.daysUntilExpiry;
    if (days != null && days < -archiveGraceDays) return true;
    final shelf = estimatedShelfLifeDays(item.location, item.name);
    final age = DateTime.now().difference(item.addedAt).inDays;
    return age > shelf + archiveGraceDays;
  }

  /// Adds a new item, or merges quantity into an existing same-key row.
  /// Restocking resets the freshness clock (checklist 2.2 / 2.4).
  static Future<PantryItem> addOrMerge({
    required String name,
    required double quantity,
    required String unit,
    required PantryLocation location,
    DateTime? bestBefore,
    bool estimated = true,
    String? sourceNote,
    String? scanId,
  }) async {
    final trimmed = name.trim();
    final u = unit.trim();
    final key = normalizeIngredientKey(trimmed);
    final existing = await getAll();
    PantryItem? match;
    for (final i in existing) {
      final existingKey = i.ingredientKey?.isNotEmpty == true
          ? i.ingredientKey!
          : normalizeIngredientKey(i.name);
      final sameKey = existingKey == key && key.isNotEmpty;
      final sameLegacy = i.name.toLowerCase() == trimmed.toLowerCase() &&
          i.unit.toLowerCase() == u.toLowerCase() &&
          i.location == location;
      if (sameKey || sameLegacy) {
        match = i;
        break;
      }
    }
    final now = DateTime.now();
    final refreshedBestBefore =
        bestBefore ?? defaultBestBefore(location, trimmed);
    if (match != null) {
      // Restock resets the clock — never average purchase dates (2.4).
      final merged = match.copyWith(
        name: trimmed.isNotEmpty ? trimmed : match.name,
        quantity: match.quantity + quantity,
        unit: u.isNotEmpty ? u : match.unit,
        location: location,
        bestBefore: refreshedBestBefore,
        bestBeforeEstimated: estimated,
        addedAt: now,
        sourceNote: sourceNote ?? match.sourceNote,
        emoji: emojiFor(trimmed, location),
        scanId: scanId ?? match.scanId,
        ingredientKey: key.isNotEmpty ? key : match.ingredientKey,
      );
      await save(merged);
      return merged;
    }
    final item = PantryItem(
      id: 'pantry_${now.millisecondsSinceEpoch}_${key.hashCode.abs()}',
      name: trimmed,
      quantity: quantity,
      unit: u,
      location: location,
      categoryLabel: location.sectionTitle,
      bestBefore: refreshedBestBefore,
      bestBeforeEstimated: estimated || bestBefore == null,
      addedAt: now,
      sourceNote: sourceNote,
      emoji: emojiFor(trimmed, location),
      scanId: scanId,
      ingredientKey: key.isNotEmpty ? key : null,
    );
    await save(item);
    return item;
  }

  /// Checklist 01 — write food items from the main scan review.
  /// Never throws; rescanning the same [scanId] / fingerprint is a no-op (2.1).
  /// Manual entry (empty scan id) still writes, with a one-off batch id.
  static Future<int> addFromScan({
    required String scanId,
    required List<({String name, double? quantity, String? unit})> items,
    String sourceNote = 'Added from your receipt',
    String? receiptFingerprint,
  }) async {
    if (items.isEmpty) return 0;
    if (!await isCollectionEnabled()) return 0;

    final sid = scanId.trim().isNotEmpty
        ? scanId.trim()
        : 'manual_${DateTime.now().millisecondsSinceEpoch}';
    final fingerprint =
        (receiptFingerprint ?? PantryService.receiptFingerprint(items)).trim();

    try {
      await ensureShelfOverridesLoaded();
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_processedScansKey) ?? [];
      final seenFp = prefs.getStringList(_processedFingerprintsKey) ?? [];
      if (seen.contains(sid) ||
          (fingerprint.isNotEmpty && seenFp.contains(fingerprint))) {
        // Same receipt already written — don't double quantities.
        return 0;
      }

      var saved = 0;
      for (final raw in items) {
        final name = raw.name.trim();
        if (name.isEmpty) continue;
        try {
          final location = guessLocation(name);
          await addOrMerge(
            name: name,
            quantity: raw.quantity ?? 1,
            unit: (raw.unit ?? '').trim(),
            location: location,
            bestBefore: defaultBestBefore(location, name),
            estimated: true,
            sourceNote: sourceNote,
            scanId: sid,
          );
          saved++;
        } catch (_) {
          // One bad row must never fail the scan (1.4).
        }
      }

      if (saved > 0) {
        final next = [...seen, sid];
        await prefs.setStringList(
          _processedScansKey,
          next.length > 200 ? next.sublist(next.length - 200) : next,
        );
        if (fingerprint.isNotEmpty) {
          final nextFp = [...seenFp, fingerprint];
          await prefs.setStringList(
            _processedFingerprintsKey,
            nextFp.length > 200 ? nextFp.sublist(nextFp.length - 200) : nextFp,
          );
        }
        try {
          await PantrySync.pushAll();
        } catch (_) {}
      }
      return saved;
    } catch (e) {
      // Pantry must never fail the scan (1.4).
      return 0;
    }
  }

  /// Remove every row that came from [scanId] (1.6).
  static Future<int> deleteByScanId(String scanId) async {
    final sid = scanId.trim();
    if (sid.isEmpty) return 0;
    final all = await getAll();
    var n = 0;
    for (final item in all) {
      if (item.scanId == sid) {
        await delete(item.id);
        n++;
      }
    }
    return n;
  }

  /// Finds pantry items that match recipe ingredient names (for cook deduct).
  static Future<List<PantryItem>> matchingIngredients(
    Iterable<String> ingredientNames,
  ) async {
    final items = await getAll();
    final found = <String, PantryItem>{};
    for (final name in ingredientNames) {
      final m = _matchName(name, items);
      if (m != null) found[m.id] = m;
    }
    return found.values.toList();
  }

  static PantryItem? _matchName(String ingredient, List<PantryItem> items) =>
      PantryRecipeMatcher.matchIngredient(ingredient, items);

  /// How a recipe line changed a pantry row.
  static const useFinished = 'finished';
  static const useReduced = 'reduced';
  static const useUnchanged = 'unchanged';

  /// Subtracts [amount] (e.g. "2 tbsp") from [item]. Removes the row only
  /// when the quantity is used up. Leaves it alone when units don't match.
  static Future<String> applyRecipeUse(PantryItem item, String amount) async {
    final current = await getById(item.id);
    if (current == null) return useUnchanged;
    final parsed = PantryQuantity.parse(amount);
    if (parsed == null) return useUnchanged;
    final left = PantryQuantity.remaining(
      have: current.quantity,
      haveUnit: current.unit,
      use: parsed.value,
      useUnit: parsed.unit,
    );
    if (left == null) return useUnchanged;
    if (left <= 0) {
      await markUsed(current);
      return useFinished;
    }
    await save(current.copyWith(quantity: left));
    return useReduced;
  }

  static DateTime defaultBestBefore(PantryLocation location, String name) {
    final days = estimatedShelfLifeDays(location, name);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  static int estimatedShelfLifeDays(PantryLocation location, String name) {
    final key = normalizeIngredientKey(name);
    final override = _shelfOverrides[key];
    if (override != null && override > 0) return override;

    final n = name.toLowerCase();
    // Frozen products named on the receipt (3.5).
    if (n.contains('frozen') || n.contains('ice cream')) return 90;
    if (location == PantryLocation.freezer) return 90;
    if (location == PantryLocation.pantry) {
      if (n.contains('milk') || n.contains('bread')) return 7;
      return 180;
    }
    if (location == PantryLocation.fridge) {
      if (n.contains('egg')) return 21;
      if (n.contains('milk') || n.contains('yoghurt') || n.contains('yogurt')) {
        return 7;
      }
      if (n.contains('meat') || n.contains('chicken') || n.contains('fish')) {
        return 3;
      }
      return 10;
    }
    // Fresh
    if (n.contains('spinach') || n.contains('salad') || n.contains('herb')) {
      return 4;
    }
    if (n.contains('banana') || n.contains('berry')) return 4;
    if (n.contains('onion') || n.contains('potato') || n.contains('garlic')) {
      return 14;
    }
    return 5;
  }

  static String emojiFor(String name, PantryLocation location) {
    final n = name.toLowerCase();
    if (n.contains('egg')) return '🥚';
    if (n.contains('spinach') || n.contains('lettuce') || n.contains('salad')) {
      return '🥬';
    }
    if (n.contains('onion')) return '🧅';
    if (n.contains('tomato')) return '🍅';
    if (n.contains('milk')) return '🥛';
    if (n.contains('rice')) return '🍚';
    if (n.contains('noodle') || n.contains('pasta')) return '🍜';
    if (n.contains('chicken')) return '🍗';
    if (n.contains('fish') || n.contains('salmon')) return '🐟';
    if (n.contains('cheese')) return '🧀';
    if (n.contains('bread')) return '🍞';
    if (n.contains('banana')) return '🍌';
    if (n.contains('apple')) return '🍎';
    switch (location) {
      case PantryLocation.fresh:
        return '🥦';
      case PantryLocation.fridge:
        return '🧊';
      case PantryLocation.pantry:
        return '🫙';
      case PantryLocation.freezer:
        return '❄️';
    }
  }

  static List<PantryItem> useFirst(List<PantryItem> items, {int limit = 3}) {
    final sorted = items.where((i) => i.bestBefore != null).toList()
      ..sort((a, b) {
        final da = a.daysUntilExpiry ?? 999;
        final db = b.daysUntilExpiry ?? 999;
        return da.compareTo(db);
      });
    return sorted
        .where((i) => (i.daysUntilExpiry ?? 999) <= 7)
        .take(limit)
        .toList();
  }

  static Map<PantryLocation, int> countsByLocation(List<PantryItem> items) {
    final map = {for (final l in PantryLocation.values) l: 0};
    for (final i in items) {
      map[i.location] = (map[i.location] ?? 0) + 1;
    }
    return map;
  }

  // ── Usage log (local) ─────────────────────────────────────────────────────

  static const _useLogKey = 'pantry_use_log';
  static const _dismissedRestockKey = 'pantry_restock_dismissed';
  static const _activityUpdatedKey = 'pantry_activity_updated_at';
  static const restockListId = ShoppingList.pantryRestockId;

  /// Records [item] as used and removes it from the pantry.
  static Future<void> markUsed(PantryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList(_useLogKey) ?? [];
    final entry = PantryUseEntry(
      name: item.name,
      emoji: item.emoji,
      location: item.location,
      usedAt: DateTime.now(),
      rescued: (item.daysUntilExpiry ?? 0) >= 0,
    );
    log.add(jsonEncode(entry.toJson()));
    // Keep roughly a year of history.
    final trimmed = log.length > 500 ? log.sublist(log.length - 500) : log;
    await prefs.setStringList(_useLogKey, trimmed);
    await _stampActivity(prefs);
    await delete(item.id);
    await _pushActivity();
  }

  static Future<List<PantryUseEntry>> usedLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_useLogKey) ?? [];
    return raw
        .map((s) {
          try {
            return PantryUseEntry.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PantryUseEntry>()
        .toList();
  }

  static Future<Set<String>> dismissedRestock() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dismissedRestockKey) ?? []).toSet();
  }

  static Future<void> dismissRestock(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_dismissedRestockKey) ?? []).toSet()
      ..add(name.toLowerCase());
    await prefs.setStringList(_dismissedRestockKey, set.toList());
    await _stampActivity(prefs);
    await _pushActivity();
  }

  /// Pulls used-items and dismissed restock ideas when the account copy is newer.
  static Future<void> mergeCloudActivity() async {
    try {
      final remote = await PantrySync.fetchActivity();
      final prefs = await SharedPreferences.getInstance();
      final localUpdated =
          DateTime.tryParse(prefs.getString(_activityUpdatedKey) ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
      if (remote == null) {
        final log = prefs.getStringList(_useLogKey) ?? [];
        final dismissed = prefs.getStringList(_dismissedRestockKey) ?? [];
        if (log.isEmpty && dismissed.isEmpty) return;
        await _pushActivity();
        return;
      }
      if (!remote.updatedAt.isAfter(localUpdated)) {
        await _pushActivity();
        return;
      }
      final encoded = remote.useLog
          .map((e) => e is String ? e : jsonEncode(e))
          .toList();
      await prefs.setStringList(_useLogKey, encoded);
      await prefs.setStringList(_dismissedRestockKey, remote.dismissed);
      await prefs.setString(
        _activityUpdatedKey,
        remote.updatedAt.toIso8601String(),
      );
    } catch (_) {}
  }

  static Future<void> _stampActivity(SharedPreferences prefs) async {
    await prefs.setString(
      _activityUpdatedKey,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> _pushActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated =
          DateTime.tryParse(prefs.getString(_activityUpdatedKey) ?? '') ??
              DateTime.now();
      final raw = prefs.getStringList(_useLogKey) ?? [];
      final useLog = raw
          .map((s) {
            try {
              final decoded = jsonDecode(s);
              if (decoded is Map<String, dynamic>) return decoded;
              if (decoded is Map) return Map<String, dynamic>.from(decoded);
            } catch (_) {}
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      await PantrySync.saveActivity(
        useLog: useLog,
        dismissed: prefs.getStringList(_dismissedRestockKey) ?? [],
        updatedAt: updated,
      );
    } catch (_) {}
  }

  /// Clears local use / restock prefs (e.g. after account deletion).
  static Future<void> clearLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_useLogKey);
    await prefs.remove(_dismissedRestockKey);
    await prefs.remove(_activityUpdatedKey);
    await prefs.remove(_processedScansKey);
    await prefs.remove(_processedFingerprintsKey);
    await prefs.remove(_collectionEnabledKey);
    await prefs.remove(_shelfOverridesKey);
    await prefs.remove('pantry_upgrade_last_shown');
    await prefs.remove('pantry_upgrade_last_dismiss');
    await prefs.remove('pantry_upgrade_dismiss_count');
    _shelfOverrides = {};
    _shelfOverridesLoaded = false;
  }

  /// Adds names to a "Pantry restock" shopping list (created on first use).
  static Future<void> addToShoppingList(
    List<({String name, String amount})> entries,
  ) async {
    if (entries.isEmpty) return;
    final existing = await LocalDbService.loadShoppingList(restockListId);
    final items = [...?existing?.items];
    for (final e in entries) {
      final dup = items.any(
          (i) => i.name.toLowerCase() == e.name.toLowerCase() && !i.checked);
      if (!dup) items.add(ShoppingListItem(name: e.name, amount: e.amount));
    }
    await LocalDbService.saveShoppingList(ShoppingList(
      id: restockListId,
      recipeName: 'Pantry restock',
      items: items,
      createdAt: existing?.createdAt ?? DateTime.now(),
    ));
  }

  /// Best guess at where a scanned ingredient is stored.
  static PantryLocation guessLocation(String name) {
    final n = name.toLowerCase();
    bool any(List<String> words) => words.any(n.contains);
    if (any(['frozen', 'ice cream', 'peas'])) return PantryLocation.freezer;
    if (any([
      'milk', 'egg', 'cheese', 'yoghurt', 'yogurt', 'butter', 'cream',
      'chicken', 'beef', 'pork', 'fish', 'salmon', 'ham', 'bacon', 'paste',
      'tofu', 'hummus',
    ])) {
      return PantryLocation.fridge;
    }
    if (any([
      'spinach', 'onion', 'tomato', 'lettuce', 'salad', 'apple', 'banana',
      'berry', 'berries', 'pepper', 'carrot', 'potato', 'garlic', 'herb',
      'lemon', 'lime', 'avocado', 'cucumber', 'mushroom', 'broccoli',
      'courgette', 'ginger', 'fruit', 'veg',
    ])) {
      return PantryLocation.fresh;
    }
    return PantryLocation.pantry;
  }

  static double quantityStep(String unit) {
    final u = unit.toLowerCase();
    if (u == 'g' || u == 'ml') return 50;
    if (u == 'kg' || u == 'l') return 0.1;
    return 1;
  }
}
