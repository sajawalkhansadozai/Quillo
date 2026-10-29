import 'package:flutter/material.dart';
import '../../models/generated_recipe.dart';
import '../../models/pantry_item.dart';
import '../../services/pantry_recipe_matcher.dart';
import '../../services/pantry_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/recipe_preference_filter.dart';
import '../../widgets/recipe_thumbnail_image.dart';
import '../scan/recipe_detail_page.dart';
import 'pantry_ui.dart';

enum _Diet { any, vegetarian }

/// Cook from your pantry — catalog recipes ranked by what you already have.
class CookFromPantryScreen extends StatefulWidget {
  final String initialQuery;
  final bool usesExpiring;

  const CookFromPantryScreen({
    super.key,
    this.initialQuery = '',
    this.usesExpiring = false,
  });

  @override
  State<CookFromPantryScreen> createState() => _CookFromPantryScreenState();
}

class _CookFromPantryScreenState extends State<CookFromPantryScreen> {
  static const _pageSize = 3;

  late final TextEditingController _searchCtrl;
  List<PantryItem> _items = [];
  List<GeneratedRecipe> _catalog = [];
  final Set<String> _savedIds = {};
  bool _loading = true;
  bool _under30 = false;
  late bool _usesExpiring;
  bool _easy = false;
  _Diet _diet = _Diet.any;
  int _shown = _pageSize;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _usesExpiring = widget.usesExpiring;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      PantryService.getActive(),
      RecipeService.listPublicRecipes(limit: 250),
    ]);
    if (!mounted) return;
    final recipes = results[1] as List<GeneratedRecipe>;
    setState(() {
      _items = results[0] as List<PantryItem>;
      _catalog = PantryRecipeMatcher.uniqueRecipes(recipes);
      _loading = false;
    });
    final saved = await RecipeService.loadSavedRecipes();
    if (!mounted) return;
    setState(() => _savedIds.addAll(saved.map((r) => r.id).whereType<String>()));
  }

  List<PantryMeal> get _meals {
    final q = _searchCtrl.text.trim().toLowerCase();
    // Searching for one ingredient shows every recipe that uses it.
    final minRatio = widget.initialQuery.isNotEmpty ? 0.0 : 0.6;
    final filtered =
        PantryRecipeMatcher.match(_catalog, _items, minRatio: minRatio)
            .where((m) {
      final r = m.recipe;
      if (_under30 && r.effectiveCookTimeMinutes > 30) return false;
      if (_usesExpiring && m.usesExpiring.isEmpty) return false;
      if (_easy && r.difficulty.toLowerCase() != 'easy') return false;
      if (_diet == _Diet.vegetarian &&
          !RecipePreferenceFilter.isVegetarian(r)) {
        return false;
      }
      if (q.isNotEmpty &&
          !r.title.toLowerCase().contains(q) &&
          !m.have.any((h) => h.name.toLowerCase().contains(q)) &&
          !m.missing.any((x) => x.name.toLowerCase().contains(q))) {
        return false;
      }
      return true;
    }).toList();
    // Filters can leave near-title variants adjacent; keep one dish only.
    return PantryRecipeMatcher.collapseNearTitleVariants(filtered);
  }

  void _openRecipe(GeneratedRecipe r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          GeneratedRecipeDetailPage(recipe: r, accentColor: AppColors.primary),
    ));
  }

  Future<void> _toggleSaved(GeneratedRecipe r) async {
    final id = r.id;
    if (id == null) return;
    final wasSaved = _savedIds.contains(id);
    setState(() => wasSaved ? _savedIds.remove(id) : _savedIds.add(id));
    final ok = wasSaved
        ? await RecipeService.unsaveRecipe(id)
        : await RecipeService.saveRecipe(r);
    if (!ok && mounted) {
      setState(() => wasSaved ? _savedIds.add(id) : _savedIds.remove(id));
    }
  }

  Future<void> _addMissing(PantryMeal m) async {
    await PantryService.addToShoppingList(m.missing);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m.missing.length == 1
            ? '${m.missing.first.name} added to Pantry restock'
            : '${m.missing.length} items added to Pantry restock'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMissing(PantryMeal m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You’re missing', style: pantryH2),
              const SizedBox(height: 8),
              for (final x in m.missing)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radio_button_unchecked_rounded,
                      color: AppColors.textMedium),
                  title: Text(x.name),
                  trailing: Text(
                    x.amount,
                    style: const TextStyle(color: AppColors.textMedium),
                  ),
                ),
              const SizedBox(height: 8),
              PantryPrimaryButton(
                label: 'Add to Pantry restock',
                onPressed: () {
                  Navigator.pop(ctx);
                  _addMissing(m);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _howWeRank() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How we rank'),
        content: const Text(
          'Recipes that use food closest to its best-before date come first. '
          'After that, we rank by how many of the ingredients you already have. '
          'Use the Dietary chip for Vegetarian recipes when you want that filter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDiet() async {
    final picked = await showModalBottomSheet<_Diet>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final d in _Diet.values)
              ListTile(
                title: Text(d == _Diet.any ? 'Any diet' : 'Vegetarian'),
                trailing: d == _diet
                    ? const Icon(Icons.check_rounded,
                        color: PantryColors.indigo)
                    : null,
                onTap: () => Navigator.pop(ctx, d),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _diet = picked);
  }

  @override
  Widget build(BuildContext context) {
    final meals = _loading ? <PantryMeal>[] : _meals;
    final best = meals.firstOrNull;
    final more = meals.skip(1).take(_shown).toList();
    final remaining = meals.length - 1 - more.length;

    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PantryHeader(
            compact: true,
            eyebrow: 'Smart recipes',
            title: 'Cook from your pantry',
            subtitle: _loading
                ? 'Finding recipes…'
                : '${meals.length} ${meals.length == 1 ? 'recipe' : 'recipes'} you can make now',
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _shown = _pageSize),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search recipes',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: 'Under 30 min',
                      selected: _under30,
                      onTap: () => setState(() => _under30 = !_under30),
                    ),
                    _Chip(
                      label: 'Uses expiring',
                      selected: _usesExpiring,
                      onTap: () =>
                          setState(() => _usesExpiring = !_usesExpiring),
                    ),
                    _Chip(
                      label: 'Easy',
                      selected: _easy,
                      onTap: () => setState(() => _easy = !_easy),
                    ),
                    _Chip(
                      label: _diet == _Diet.any ? 'Dietary' : 'Vegetarian',
                      selected: _diet != _Diet.any,
                      dropdown: true,
                      onTap: _pickDiet,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (best == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: pantryCard(),
                    child: Text(
                      _items.isEmpty
                          ? 'Add food to your pantry and we’ll show what you can cook.'
                          : 'No recipes match these filters yet. Try removing one.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMedium),
                    ),
                  )
                else ...[
                  _BestMatchCard(
                    meal: best,
                    saved: _savedIds.contains(best.recipe.id),
                    onOpen: () => _openRecipe(best.recipe),
                    onSave: () => _toggleSaved(best.recipe),
                    onMissing: best.missing.isEmpty
                        ? null
                        : () => _showMissing(best),
                  ),
                  if (more.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'More matches',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _howWeRank,
                          icon: const Icon(Icons.info_outline_rounded,
                              size: 16, color: PantryColors.indigo),
                          label: const Text(
                            'How we rank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PantryColors.indigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: pantryCard(),
                      child: Column(
                        children: [
                          for (var i = 0; i < more.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                  height: 1,
                                  indent: 20,
                                  endIndent: 20,
                                  color: PantryColors.border),
                            _MatchRow(
                              meal: more[i],
                              saved: _savedIds.contains(more[i].recipe.id),
                              onOpen: () => _openRecipe(more[i].recipe),
                              onSave: () => _toggleSaved(more[i].recipe),
                              onMissing: () => _showMissing(more[i]),
                              onAddMissing: () => _addMissing(more[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (remaining > 0) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () =>
                            setState(() => _shown += _pageSize),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD5D3F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          'Show ${remaining < _pageSize ? remaining : _pageSize} more ${remaining == 1 ? 'recipe' : 'recipes'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dropdown;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF15153A) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF15153A) : const Color(0xFFD5D3F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && !dropdown) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
            if (dropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool saved;
  final VoidCallback onTap;
  final bool filled;
  const _SaveButton({
    required this.saved,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: saved ? PantryColors.indigo : AppColors.textDark,
    );
    if (!filled) {
      return IconButton(onPressed: onTap, icon: icon);
    }
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8), child: icon),
      ),
    );
  }
}

class _BestMatchCard extends StatelessWidget {
  final PantryMeal meal;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback? onMissing;

  const _BestMatchCard({
    required this.meal,
    required this.saved,
    required this.onOpen,
    required this.onSave,
    this.onMissing,
  });

  @override
  Widget build(BuildContext context) {
    final r = meal.recipe;
    final shownItems = meal.usesExpiring.take(2).toList();
    final restCount = meal.have.length - shownItems.length;
    return Container(
      decoration: pantryCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: onOpen,
                  child: RecipeThumbnailImage(
                    imageUrl: r.imageUrl,
                    emoji: '🍽️',
                    placeholderColor: AppColors.primaryLight,
                    cacheWidth: 720,
                    zoom: 1,
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15153A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Best match',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: _SaveButton(saved: saved, onTap: onSave, filled: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${r.cookTimeLabel} total'),
                    const TextSpan(text: '   ·   '),
                    TextSpan(
                      text: r.difficultyLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ]),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                const Divider(height: 22, color: PantryColors.border),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'In your pantry',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '${meal.have.length} of ${meal.total}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: meal.hasAll
                            ? PantryColors.green
                            : PantryColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final item in shownItems)
                  _PantryLine(
                    label: item.name,
                    strong: true,
                    trailing: item.freshness == FreshnessBand.useSoon
                        ? ('Use soon', PantryColors.amber)
                        : ('Use first', PantryColors.red),
                  ),
                if (restCount > 0)
                  _PantryLine(
                    label: shownItems.isEmpty
                        ? 'You have $restCount of these'
                        : 'And $restCount more you already have',
                    strong: false,
                  ),
                if (meal.missing.isNotEmpty)
                  GestureDetector(
                    onTap: onMissing,
                    behavior: HitTestBehavior.opaque,
                    child: _PantryLine(
                      label: meal.missing.length == 1
                          ? '1 missing · tap to see'
                          : '${meal.missing.length} missing · tap to see',
                      strong: false,
                      missing: true,
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PantryColors.indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'View recipe',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PantryLine extends StatelessWidget {
  final String label;
  final bool strong;
  final bool missing;
  final (String, Color)? trailing;

  const _PantryLine({
    required this.label,
    required this.strong,
    this.missing = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: missing
                  ? PantryColors.segmentBg
                  : strong
                      ? PantryColors.green
                      : PantryColors.greenBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              missing ? Icons.remove_rounded : Icons.check_rounded,
              size: 14,
              color: missing
                  ? AppColors.textMedium
                  : strong
                      ? Colors.white
                      : PantryColors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: strong ? AppColors.textDark : AppColors.textMedium,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: trailing!.$2,
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final PantryMeal meal;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onMissing;
  final VoidCallback onAddMissing;

  const _MatchRow({
    required this.meal,
    required this.saved,
    required this.onOpen,
    required this.onSave,
    required this.onMissing,
    required this.onAddMissing,
  });

  String? get _expiringLine {
    final e = meal.usesExpiring;
    if (e.isEmpty) return null;
    if (e.length == 1) return 'Uses expiring ${e.first.name.toLowerCase()}';
    return 'Uses ${e.length} expiring ingredients';
  }

  @override
  Widget build(BuildContext context) {
    final r = meal.recipe;
    final expiring = _expiringLine;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: RecipeThumbnailImage(
                      imageUrl: r.imageUrl,
                      emoji: '🍽️',
                      placeholderColor: PantryColors.segmentBg,
                      cacheWidth: 260,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.cookTimeLabel} · ${r.difficultyLabel}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                      ),
                      if (expiring != null)
                        Text(
                          expiring,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PantryColors.amber,
                          ),
                        ),
                    ],
                  ),
                ),
                _SaveButton(saved: saved, onTap: onSave),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: PantryColors.bg,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: meal.missing.isEmpty ? null : onMissing,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${meal.have.length}/${meal.total}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: meal.missing.isEmpty
                              ? ' · all in'
                              : ' · ${meal.missing.length} missing',
                        ),
                      ]),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
                if (meal.missing.isNotEmpty)
                  FilledButton(
                    onPressed: onAddMissing,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Add missing',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: onOpen,
                    child: const Text(
                      'Cook it',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: PantryColors.indigo,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
