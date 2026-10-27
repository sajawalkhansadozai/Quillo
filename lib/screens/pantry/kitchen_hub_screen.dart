import 'package:flutter/material.dart';
import '../../models/generated_recipe.dart';
import '../../models/pantry_item.dart';
import '../../services/pantry_recipe_matcher.dart';
import '../../services/pantry_service.dart';
import '../../services/pantry_sync_service.dart';
import '../../services/recipe_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_thumbnail_image.dart';
import '../paywall_screen.dart';
import '../scan/recipe_detail_page.dart';
import 'add_pantry_screen.dart';
import 'cook_from_pantry_screen.dart';
import 'expiry_centre_screen.dart';
import 'pantry_insights_screen.dart';
import 'pantry_item_detail_screen.dart';
import 'pantry_ui.dart';

/// Your kitchen — smart pantry hub (bottom tab or pushed route).
class KitchenHubScreen extends StatefulWidget {
  /// When true (main tab), hide the back button.
  final bool asTab;

  const KitchenHubScreen({super.key, this.asTab = false});

  @override
  State<KitchenHubScreen> createState() => _KitchenHubScreenState();
}

class _KitchenHubScreenState extends State<KitchenHubScreen> {
  List<PantryItem> _items = [];
  List<GeneratedRecipe> _catalog = [];
  bool _loading = true;
  bool _isPremium = false;
  bool _searching = false;
  String _query = '';
  PantryLocation? _filter;
  final Set<PantryLocation> _expanded = {};

  @override
  void initState() {
    super.initState();
    SubscriptionService.premiumNotifier.addListener(_onPremiumChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    SubscriptionService.premiumNotifier.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    final premium = SubscriptionService.isPremiumCached;
    if (!mounted || premium == _isPremium) return;
    setState(() => _isPremium = premium);
    if (premium) _bootstrap();
  }

  Future<void> _bootstrap() async {
    final premium = await SubscriptionService.isPremium();
    if (!mounted) return;
    setState(() {
      _isPremium = premium;
      if (!premium) _loading = false;
    });
    if (!premium) return;
    await Future.wait([_reload(), _loadRecipes()]);
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const PaywallScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        fullscreenDialog: true,
      ),
    );
    await _bootstrap();
  }

  Future<void> _reload() async {
    try {
      await PantrySync.pullAndMerge();
      await PantryService.mergeCloudActivity();
    } catch (_) {}
    final items = await PantryService.getAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _loadRecipes() async {
    final recipes = await RecipeService.listPublicRecipes(limit: 250);
    if (!mounted) return;
    setState(() => _catalog = recipes);
  }

  Future<void> _refresh() => Future.wait([_reload(), _loadRecipes()]);

  List<PantryItem> get _filtered {
    var list = _items;
    if (_filter != null) {
      list = list.where((i) => i.location == _filter).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.categoryLabel.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Map<PantryLocation, List<PantryItem>> get _grouped {
    final map = {for (final l in PantryLocation.values) l: <PantryItem>[]};
    for (final i in _filtered) {
      map[i.location]!.add(i);
    }
    for (final group in map.values) {
      group.sort((a, b) => (a.daysUntilExpiry ?? 9999)
          .compareTo(b.daysUntilExpiry ?? 9999));
    }
    return map;
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _reload();
  }

  Future<void> _openAdd() async {
    final added = await Navigator.of(context).push<PantryItem>(
      MaterialPageRoute(builder: (_) => const AddPantryScreen()),
    );
    await _reload();
    if (added != null && mounted) {
      await _push(PantryItemDetailScreen(itemId: added.id));
    }
  }

  Future<void> _openDetail(PantryItem item) =>
      _push(PantryItemDetailScreen(itemId: item.id));

  void _openRecipe(GeneratedRecipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeneratedRecipeDetailPage(
          recipe: recipe,
          accentColor: AppColors.primary,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isPremium && !_loading) {
      return Scaffold(
        backgroundColor: PantryColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Smart Pantry',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track ingredients from every receipt, get expiry alerts, and cook from what you already have.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontFamily: 'Nunito',
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'Premium feature',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Receipt scans still save ingredients here automatically — upgrade to unlock your Smart Pantry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontFamily: 'Nunito',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _openPaywall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Unlock Smart Pantry',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    final useFirst = PantryService.useFirst(_items);
    final counts = PantryService.countsByLocation(_items);
    final total = _items.length;
    final meals = PantryRecipeMatcher.match(_catalog, _items);

    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Header(
                    showBack: !widget.asTab,
                    total: total,
                    useFirstCount: useFirst.length,
                    mealCount: _catalog.isEmpty ? null : meals.length,
                    counts: counts,
                    searching: _searching,
                    onSearchToggle: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                    onQuery: (v) => setState(() => _query = v),
                    onAdd: _openAdd,
                    onInsights: () => _push(const PantryInsightsScreen()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                    child: total == 0
                        ? _EmptyState(onAdd: _openAdd)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (useFirst.isNotEmpty && _query.isEmpty) ...[
                                _UseFirstSection(
                                  items: useFirst,
                                  onTap: _openDetail,
                                  onSeeAll: () =>
                                      _push(const ExpiryCentreScreen()),
                                ),
                                const SizedBox(height: 32),
                              ],
                              if (meals.isNotEmpty && _query.isEmpty) ...[
                                _CookTonightSection(
                                  meal: meals.first,
                                  totalMeals: meals.length,
                                  onOpen: () => _openRecipe(meals.first.recipe),
                                  onSeeAll: () =>
                                      _push(const CookFromPantryScreen()),
                                ),
                                const SizedBox(height: 32),
                              ],
                              _buildEverything(),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEverything() {
    final grouped = _grouped;
    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text('Everything you have', style: pantryH2),
            ),
            Text(
              '${filtered.length} items',
              style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PantrySegmented<PantryLocation?>(
          options: [
            (label: 'All', value: null),
            for (final l in PantryLocation.values) (label: l.label, value: l),
          ],
          selected: _filter,
          onSelect: (l) => setState(() => _filter = l),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No items match',
                style: TextStyle(color: AppColors.textMedium),
              ),
            ),
          )
        else
          ...PantryLocation.values.expand((loc) {
            final group = grouped[loc] ?? [];
            if (group.isEmpty) return <Widget>[];
            final expanded = _filter != null ||
                _query.isNotEmpty ||
                _expanded.contains(loc);
            return [
              _LocationGroup(
                location: loc,
                items: group,
                expanded: expanded,
                onToggle: () => setState(() {
                  if (!_expanded.remove(loc)) _expanded.add(loc);
                }),
                onTap: _openDetail,
              ),
              const SizedBox(height: 12),
            ];
          }),
      ],
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool showBack;
  final int total;
  final int useFirstCount;
  final int? mealCount;
  final Map<PantryLocation, int> counts;
  final bool searching;
  final VoidCallback onSearchToggle;
  final ValueChanged<String> onQuery;
  final VoidCallback onAdd;
  final VoidCallback onInsights;

  const _Header({
    required this.showBack,
    required this.total,
    required this.useFirstCount,
    required this.mealCount,
    required this.counts,
    required this.searching,
    required this.onSearchToggle,
    required this.onQuery,
    required this.onAdd,
    required this.onInsights,
  });

  static const _segmentColors = {
    PantryLocation.fresh: Colors.white,
    PantryLocation.fridge: Color(0xFFC9C3FF),
    PantryLocation.pantry: Color(0xFFA59CFF),
    PantryLocation.freezer: Color(0xFF7F74FF),
  };

  String get _headline {
    if (total == 0) return 'Nothing here yet.';
    final first = useFirstCount == 0
        ? 'Nothing urgent.'
        : '$useFirstCount to use first.';
    return '$total ${total == 1 ? 'item' : 'items'} ready.\n$first';
  }

  String get _subline {
    if (total == 0) return 'Add what you have and we’ll suggest meals.';
    final m = mealCount;
    if (m == null || m == 0) {
      return 'Sorted by where it lives and what to use first.';
    }
    return 'Enough ingredients for $m personalised ${m == 1 ? 'meal' : 'meals'}.';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, 24),
      decoration: const BoxDecoration(
        color: PantryColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              const Text(
                'Your kitchen',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSearchToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      searching ? Icons.close_rounded : Icons.search_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onAdd,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded,
                            color: AppColors.textDark, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Add food',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (searching) ...[
            const SizedBox(height: 14),
            TextField(
              autofocus: true,
              onChanged: onQuery,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search your kitchen',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            _headline,
            style: const TextStyle(
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _subline,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 24),
            // Tapping the breakdown opens Pantry insights.
            GestureDetector(
              onTap: onInsights,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Where it all is',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$total items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: Colors.white.withValues(alpha: 0.85)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        for (final l in PantryLocation.values)
                          if ((counts[l] ?? 0) > 0)
                            Expanded(
                              flex: counts[l]!,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: _segmentColors[l],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      for (final l in PantryLocation.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _segmentColors[l],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${counts[l] ?? 0}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Use these first ─────────────────────────────────────────────────────────

class _UseFirstSection extends StatelessWidget {
  final List<PantryItem> items;
  final ValueChanged<PantryItem> onTap;
  final VoidCallback onSeeAll;

  const _UseFirstSection({
    required this.items,
    required this.onTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Use these first', style: pantryH2),
                  SizedBox(height: 2),
                  Text(
                    'Best-before dates are estimates',
                    style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'See all',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: PantryColors.indigo,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: pantryCard(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: PantryColors.border),
                _UseFirstRow(item: items[i], onTap: () => onTap(items[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _UseFirstRow extends StatelessWidget {
  final PantryItem item;
  final VoidCallback onTap;
  const _UseFirstRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = item.daysUntilExpiry;
    final tone = pantryUrgency(item) ??
        (fg: PantryColors.green, bg: PantryColors.greenBg);
    final date = item.bestBefore == null
        ? ''
        : ' · ${item.bestBeforeEstimated ? 'est. ' : ''}${pantryShortDate(item.bestBefore!)}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            PantryEmojiTile(item: item, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantityLabel}$date',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            PantryPill(
              text: d != null && d < 0 ? 'Expired' : pantrySpan(d ?? 0),
              fg: tone.fg,
              bg: tone.bg,
              icon: Icons.schedule_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cook them tonight ───────────────────────────────────────────────────────

class _CookTonightSection extends StatelessWidget {
  final PantryMeal meal;
  final int totalMeals;
  final VoidCallback onOpen;
  final VoidCallback onSeeAll;

  const _CookTonightSection({
    required this.meal,
    required this.totalMeals,
    required this.onOpen,
    required this.onSeeAll,
  });

  String? get _usesLine {
    final names = meal.usesExpiring.map((i) => i.name.toLowerCase()).toList();
    if (names.isEmpty) return null;
    final joined = names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Uses your $joined';
  }

  @override
  Widget build(BuildContext context) {
    final r = meal.recipe;
    final uses = _usesLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cook them tonight', style: pantryH2),
        const SizedBox(height: 12),
        Container(
          decoration: pantryCard(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RecipeThumbnailImage(
                        imageUrl: r.imageUrl,
                        emoji: '🍽️',
                        placeholderColor: AppColors.primaryLight,
                        cacheWidth: 800,
                        zoom: 1,
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded,
                                  size: 15, color: PantryColors.indigo),
                              const SizedBox(width: 6),
                              Text(
                                meal.hasAll
                                    ? 'You have all ${meal.total} ingredients'
                                    : 'You have ${meal.have.length} of ${meal.total} ingredients',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: PantryColors.indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (uses != null) ...[
                        Text(
                          uses,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: PantryColors.amber,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        r.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 15, color: AppColors.textMedium),
                          const SizedBox(width: 6),
                          Text(
                            '${r.cookTimeLabel} · ${r.difficultyLabel}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PantryPrimaryButton(
                        label: 'View recipe',
                        onPressed: onOpen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: onSeeAll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    totalMeals == 1
                        ? 'See the meal you can make'
                        : 'See all $totalMeals meals you can make',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PantryColors.indigo,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: PantryColors.indigo, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Everything you have ─────────────────────────────────────────────────────

class _LocationGroup extends StatelessWidget {
  final PantryLocation location;
  final List<PantryItem> items;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PantryItem> onTap;

  const _LocationGroup({
    required this.location,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.onTap,
  });

  /// Freezer items rarely need attention, so the collapsed view hides them.
  int get _previewCount => location == PantryLocation.freezer ? 0 : 2;

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? items : items.take(_previewCount).toList();
    final hidden = items.length > visible.length;
    final canCollapse = expanded && items.length > _previewCount;
    const divider = Divider(
        height: 1, indent: 16, endIndent: 16, color: PantryColors.border);
    return Container(
      decoration: pantryCard(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(pantryLocationIcon(location),
                    size: 18, color: PantryColors.indigo),
                const SizedBox(width: 10),
                Text(location.sectionTitle.toUpperCase(), style: pantryCaps),
                const Spacer(),
                Text(
                  '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          for (final item in visible) ...[
            divider,
            _GroupRow(item: item, onTap: () => onTap(item)),
          ],
          if (hidden || canCollapse) ...[
            divider,
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hidden
                            ? (visible.isEmpty
                                ? 'Show ${items.length} ${items.length == 1 ? 'item' : 'items'}'
                                : 'Show all ${items.length}')
                            : 'Show less',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PantryColors.indigo,
                        ),
                      ),
                    ),
                    Icon(
                      hidden
                          ? Icons.chevron_right_rounded
                          : Icons.expand_less_rounded,
                      color: PantryColors.indigo,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final PantryItem item;
  final VoidCallback onTap;
  const _GroupRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = item.daysUntilExpiry;
    final tone = pantryUrgency(item);
    final label = d == null
        ? null
        : d < 0
            ? 'Expired'
            : '${item.bestBeforeEstimated ? 'Est. ' : ''}${pantrySpan(d)}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            PantryEmojiTile(item: item, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.quantityLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (label != null)
              tone != null
                  ? PantryPill(text: label, fg: tone.fg, bg: tone.bg)
                  : Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: pantryCard(),
      child: Column(
        children: [
          const Text('🫙', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Your kitchen is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add what you already have — we’ll sort by fridge, pantry and freezer, and flag what to cook first.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          PantryPrimaryButton(label: 'Add your first item', onPressed: onAdd),
        ],
      ),
    );
  }
}
