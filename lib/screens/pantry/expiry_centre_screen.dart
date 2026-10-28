import 'package:flutter/material.dart';
import '../../models/generated_recipe.dart';
import '../../models/pantry_item.dart';
import '../../services/food_waste_service.dart';
import '../../services/pantry_recipe_matcher.dart';
import '../../services/pantry_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ingredient_visual.dart';
import '../../widgets/ingredient_visual_icon.dart';
import '../scan/recipe_detail_page.dart';
import 'cook_from_pantry_screen.dart';
import 'pantry_insights_screen.dart';
import 'pantry_item_detail_screen.dart';
import 'pantry_ui.dart';

enum _Range { all, today, next3, week }

enum _Bucket { today, next3, laterThisWeek, later }

/// Expiry centre — everything ordered by best-before, with what to cook.
class ExpiryCentreScreen extends StatefulWidget {
  const ExpiryCentreScreen({super.key});

  @override
  State<ExpiryCentreScreen> createState() => _ExpiryCentreScreenState();
}

class _ExpiryCentreScreenState extends State<ExpiryCentreScreen> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<PantryItem> _items = [];
  List<GeneratedRecipe> _catalog = [];
  List<PantryUseEntry> _used = [];
  bool _loading = true;
  _Range _range = _Range.all;
  final Set<_Bucket> _collapsed = {_Bucket.later};

  @override
  void initState() {
    super.initState();
    _reload();
    RecipeService.listPublicRecipes().then((r) {
      if (mounted) setState(() => _catalog = r);
    });
  }

  Future<void> _reload() async {
    final items = await PantryService.getActive();
    final used = await PantryService.usedLog();
    if (!mounted) return;
    setState(() {
      _items = items
          .where((i) => i.bestBefore != null)
          .toList()
        ..sort((a, b) => a.daysUntilExpiry!.compareTo(b.daysUntilExpiry!));
      _used = used;
      _loading = false;
    });
  }

  _Bucket _bucketOf(PantryItem i) {
    final d = i.daysUntilExpiry!;
    if (d <= 0) return _Bucket.today;
    if (d <= 3) return _Bucket.next3;
    if (d <= 7) return _Bucket.laterThisWeek;
    return _Bucket.later;
  }

  bool _inRange(_Bucket b) {
    switch (_range) {
      case _Range.all:
        return true;
      case _Range.today:
        return b == _Bucket.today;
      case _Range.next3:
        return b == _Bucket.today || b == _Bucket.next3;
      case _Range.week:
        return b != _Bucket.later;
    }
  }

  Future<void> _openDetail(PantryItem item) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PantryItemDetailScreen(itemId: item.id),
    ));
    await _reload();
  }

  void _openRecipe(GeneratedRecipe r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          GeneratedRecipeDetailPage(recipe: r, accentColor: AppColors.primary),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: PantryColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final weekCount =
        _items.where((i) => _bucketOf(i) != _Bucket.later).length;
    final meals = PantryRecipeMatcher.match(_catalog, _items, minRatio: 0);
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);
    final savedThisMonth = _used
        .where((u) => u.rescued && !u.usedAt.isBefore(monthStart))
        .length;

    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            PantryHeader(
              eyebrow: 'Smart pantry',
              title: 'Expiry centre',
              subtitle: weekCount == 0
                  ? 'Nothing needs using this week.'
                  : '$weekCount ${weekCount == 1 ? 'item needs' : 'items need'} using this week. Nothing has to go to waste.',
              children: [
                const SizedBox(height: 18),
                _weekStrip(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PantrySegmented<_Range>(
                    options: const [
                      (label: 'All', value: _Range.all),
                      (label: 'Today', value: _Range.today),
                      (label: 'Next 3 days', value: _Range.next3),
                      (label: 'This week', value: _Range.week),
                    ],
                    selected: _range,
                    onSelect: (r) => setState(() => _range = r),
                  ),
                  const SizedBox(height: 20),
                  for (final b in _Bucket.values)
                    if (_inRange(b)) ..._section(b, meals),
                  const SizedBox(height: 8),
                  PantryPrimaryButton(
                    label: 'Cook with these items',
                    trailingIcon: Icons.chevron_right_rounded,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const CookFromPantryScreen(usesExpiring: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SavedCard(
                    count: savedThisMonth,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PantryInsightsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekStrip() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (_) {
              final day = today.add(Duration(days: i));
              final due = _items
                  .where((it) => it.daysUntilExpiry == i)
                  .toList();
              final hasDue = due.isNotEmpty;
              final isToday = i == 0;
              final accent = hasDue
                  ? (i <= 2 ? const Color(0xFFFFB4A8) : const Color(0xFFFFD58A))
                  : Colors.white;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                height: 104,
                decoration: BoxDecoration(
                  color: hasDue
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isToday
                      ? Border.all(color: Colors.white.withValues(alpha: 0.5))
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      isToday ? 'Today' : _weekdays[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        color: hasDue
                            ? accent
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: hasDue ? accent : Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (hasDue)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          ingredientVisualFor(due.first.name).assetPath!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }

  List<Widget> _section(_Bucket b, List<PantryMeal> meals) {
    final items = _items.where((i) => _bucketOf(i) == b).toList();
    final (title, icon, fg, bg) = switch (b) {
      _Bucket.today => (
          'Today',
          Icons.warning_amber_rounded,
          PantryColors.red,
          PantryColors.redBg
        ),
      _Bucket.next3 => (
          'Next 3 days',
          Icons.schedule_rounded,
          PantryColors.red,
          PantryColors.redBg
        ),
      _Bucket.laterThisWeek => (
          'Later this week',
          Icons.schedule_rounded,
          PantryColors.amber,
          PantryColors.amberBg
        ),
      _Bucket.later => (
          'Later',
          Icons.check_rounded,
          PantryColors.green,
          PantryColors.greenBg
        ),
    };
    if (items.isEmpty && b != _Bucket.today) return const [];
    final collapsed = _collapsed.contains(b);
    final countLabel = items.isEmpty
        ? 'None'
        : '${items.length} ${items.length == 1 ? 'item' : 'items'}';

    Widget body;
    if (items.isEmpty) {
      final next = _items.where((i) => i.daysUntilExpiry! > 0).firstOrNull;
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: pantryCard(),
        child: Text(
          next == null
              ? 'Nothing expires today.'
              : 'Nothing expires today. Next up: ${next.name.toLowerCase()}, '
                  'in about ${pantrySpan(next.daysUntilExpiry!)}.',
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppColors.textDark,
          ),
        ),
      );
    } else {
      body = Container(
        decoration: pantryCard(),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: PantryColors.border),
              _ExpiryRow(
                item: items[i],
                meals: PantryRecipeMatcher.forItem(meals, items[i]),
                onUpdate: () => _openDetail(items[i]),
                onRecipe: _openRecipe,
              ),
            ],
          ],
        ),
      );
    }

    return [
      InkWell(
        onTap: () => setState(() {
          if (!_collapsed.remove(b)) _collapsed.add(b);
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: pantryH2,
              ),
              const SizedBox(width: 6),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textMedium,
                ),
              ),
              const Spacer(),
              Icon(
                collapsed
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: AppColors.textMedium,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (!collapsed) ...[body, const SizedBox(height: 12)],
      const SizedBox(height: 12),
    ];
  }
}

class _ExpiryRow extends StatelessWidget {
  final PantryItem item;
  final List<PantryMeal> meals;
  final VoidCallback onUpdate;
  final ValueChanged<GeneratedRecipe> onRecipe;

  const _ExpiryRow({
    required this.item,
    required this.meals,
    required this.onUpdate,
    required this.onRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final d = item.daysUntilExpiry!;
    final tone = pantryUrgency(item) ??
        (fg: PantryColors.green, bg: PantryColors.greenBg);
    final best = meals.firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IngredientVisualIcon(ingredientName: item.name, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${item.quantityLabel} · '
                            '${item.bestBeforeEstimated ? 'est. ' : ''}'
                            '${pantryShortDate(item.bestBefore!)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PantryPill(
                      text: d < 0 ? 'Expired' : pantrySpan(d),
                      fg: tone.fg,
                      bg: tone.bg,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: best == null
                          ? const Text(
                              'No matching recipes yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => onRecipe(best.recipe),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Make it into',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                  Text(
                                    best.recipe.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: PantryColors.indigo,
                                    ),
                                  ),
                                  Text(
                                    meals.length == 1
                                        ? '1 recipe uses it'
                                        : '${meals.length} recipes use it',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: onUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        side: const BorderSide(color: Color(0xFFD5D3F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      child: const Text(
                        'Update',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _SavedCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final money = FoodWasteService.estimateMoneySaved(count);
    return Material(
      color: PantryColors.greenBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_outlined, color: PantryColors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 item saved this month'
                          : '$count items saved this month',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      count == 0
                          ? 'Mark items as used to track what you keep out of the bin.'
                          : 'That is approximately £${money.toStringAsFixed(2)} kept out of the bin.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: PantryColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textDark),
            ],
          ),
        ),
      ),
    );
  }
}
