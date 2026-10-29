import 'package:flutter/material.dart';
import '../../models/generated_recipe.dart';
import '../../models/pantry_item.dart';
import '../../services/pantry_recipe_matcher.dart';
import '../../services/pantry_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/ingredient_visual.dart';
import '../../widgets/recipe_thumbnail_image.dart';
import '../scan/recipe_detail_page.dart';
import 'cook_from_pantry_screen.dart';
import 'pantry_ui.dart';

/// Ingredient detail — edit amount, location, best before; mark used / remove.
class PantryItemDetailScreen extends StatefulWidget {
  final String itemId;

  const PantryItemDetailScreen({super.key, required this.itemId});

  @override
  State<PantryItemDetailScreen> createState() => _PantryItemDetailScreenState();
}

class _PantryItemDetailScreenState extends State<PantryItemDetailScreen> {
  PantryItem? _item;
  List<PantryItem> _all = [];
  List<GeneratedRecipe> _catalog = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRecipes();
  }

  Future<void> _load() async {
    final all = await PantryService.getAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      _item = all.where((i) => i.id == widget.itemId).firstOrNull;
      _loading = false;
    });
  }

  Future<void> _loadRecipes() async {
    final recipes = await RecipeService.listPublicRecipes(limit: 250);
    if (mounted) {
      setState(() => _catalog = PantryRecipeMatcher.uniqueRecipes(recipes));
    }
  }

  Future<void> _persist(PantryItem updated) async {
    setState(() {
      _item = updated;
      _all = [for (final i in _all) i.id == updated.id ? updated : i];
    });
    await PantryService.save(updated);
  }

  Future<void> _adjustQty(double delta) async {
    final item = _item;
    if (item == null) return;
    final step = PantryService.quantityStep(item.unit);
    final next = (item.quantity + delta * step).clamp(0.0, 9999.0);
    if (next <= 0) {
      await _confirmRemove();
      return;
    }
    await _persist(item.copyWith(quantity: next));
  }

  Future<void> _pickDate() async {
    final item = _item;
    if (item == null) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.bestBefore ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    final updated = item.copyWith(
      bestBefore: picked,
      bestBeforeEstimated: false,
    );
    await _persist(updated);
    // Checklist 3.4 — learn this correction for the ingredient.
    await PantryService.rememberShelfCorrection(updated);
  }

  Future<void> _markFrozen() async {
    final item = _item;
    if (item == null || item.location == PantryLocation.freezer) return;
    final updated = await PantryService.markFrozen(item);
    if (!mounted) return;
    setState(() {
      _item = updated;
      _all = [for (final i in _all) i.id == updated.id ? updated : i];
    });
  }

  Future<void> _editCategory() async {
    final item = _item;
    if (item == null) return;
    final ctrl = TextEditingController(text: item.categoryLabel);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value.isEmpty) return;
    await _persist(item.copyWith(categoryLabel: value));
  }

  Future<void> _editName() async {
    final item = _item;
    if (item == null) return;
    final ctrl = TextEditingController(text: item.name);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value.isEmpty) return;
    await _persist(item.copyWith(
      name: value,
      emoji: PantryService.emojiFor(value, item.location),
    ));
  }

  Future<void> _editUnit() async {
    final item = _item;
    if (item == null) return;
    const units = ['g', 'kg', 'ml', 'l', 'pack', 'bunch', 'pcs', ''];
    final picked = await showModalBottomSheet<String>(
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
            for (final u in units)
              ListTile(
                title: Text(u.isEmpty ? 'No unit' : u),
                trailing: u == item.unit
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, u),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _persist(item.copyWith(unit: picked));
  }

  Future<void> _setLocation(PantryLocation loc) async {
    final item = _item;
    if (item == null || item.location == loc) return;
    await _persist(item.copyWith(
      location: loc,
      categoryLabel: loc.sectionTitle,
    ));
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from pantry?'),
        content: Text(
          _item == null
              ? 'This item will be deleted.'
              : 'Remove ${_item!.name} from your kitchen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PantryColors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await PantryService.delete(widget.itemId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _markUsedUp() async {
    final item = _item;
    if (item == null) return;
    await PantryService.markUsed(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as used'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _addToList() async {
    final item = _item;
    if (item == null) return;
    await PantryService.addToShoppingList([(name: item.name, amount: '')]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to Pantry restock'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (_loading) {
      return const Scaffold(
        backgroundColor: PantryColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (item == null) {
      return Scaffold(
        backgroundColor: PantryColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Item not found'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final meals = PantryRecipeMatcher.forItem(
      PantryRecipeMatcher.match(_catalog, _all, minRatio: 0),
      item,
    );

    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            item: item,
            onDelete: _confirmRemove,
            onAddToList: _addToList,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AMOUNT LEFT', style: pantryCaps),
                const SizedBox(height: 10),
                _AmountCard(
                  item: item,
                  onMinus: () => _adjustQty(-1),
                  onPlus: () => _adjustQty(1),
                  onEditUnit: _editUnit,
                ),
                const SizedBox(height: 24),
                const Text('DETAILS', style: pantryCaps),
                const SizedBox(height: 10),
                _DetailsCard(
                  item: item,
                  onLocation: _setLocation,
                  onEditDate: _pickDate,
                  onEditCategory: _editCategory,
                  onEditName: _editName,
                  onMarkFrozen: item.location == PantryLocation.freezer
                      ? null
                      : _markFrozen,
                ),
                if (item.sourceNote != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _sourceLine(item),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ),
                ],
                if (meals.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('USE IT IN', style: pantryCaps),
                  const SizedBox(height: 10),
                  _UseItInCard(
                    item: item,
                    meal: meals.first,
                    onTap: () => _openRecipe(meals.first.recipe),
                  ),
                  if (meals.length > 1)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CookFromPantryScreen(initialQuery: item.name),
                        ),
                      ),
                      child: Text(
                        meals.length == 2
                            ? 'See both recipes with ${item.name.toLowerCase()}'
                            : 'See all ${meals.length} recipes with ${item.name.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PantryColors.indigo,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                PantryPrimaryButton(
                  label: 'Mark all as used',
                  icon: Icons.check_rounded,
                  onPressed: _markUsedUp,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineAction(
                        label: 'Add to list',
                        icon: Icons.playlist_add_rounded,
                        color: AppColors.textDark,
                        onTap: _addToList,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OutlineAction(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: PantryColors.red,
                        onTap: _confirmRemove,
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

  String _sourceLine(PantryItem item) {
    final a = item.addedAt;
    final now = DateTime.now();
    final sameDay =
        a.year == now.year && a.month == now.month && a.day == now.day;
    final hh = a.hour.toString().padLeft(2, '0');
    final mm = a.minute.toString().padLeft(2, '0');
    final when = sameDay ? 'today at $hh:$mm' : 'on ${pantryShortDate(a)}';
    return '${item.sourceNote} $when.';
  }
}

// ── Hero + freshness card ───────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final PantryItem item;
  final VoidCallback onDelete;
  final VoidCallback onAddToList;

  const _Hero({
    required this.item,
    required this.onDelete,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 4, 16, 20),
      decoration: const BoxDecoration(
        color: PantryColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                onSelected: (v) => v == 'delete' ? onDelete() : onAddToList(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'list', child: Text('Add to list')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              ingredientVisualFor(item.name).assetPath!,
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.categoryLabel,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 20),
          _FreshnessCard(item: item),
        ],
      ),
    );
  }
}

class _FreshnessCard extends StatelessWidget {
  final PantryItem item;
  const _FreshnessCard({required this.item});

  String get _title {
    final d = item.daysUntilExpiry;
    if (d == null) return 'No best-before date';
    if (d < 0) return 'Past its best-before';
    if (d == 0) return 'Use today';
    if (d == 1) return 'Use within 1 day';
    if (d <= 5) return 'Use within $d days';
    return 'Good for ${pantrySpan(d)}';
  }

  String get _advice {
    final est = item.bestBeforeEstimated;
    final base = est
        ? 'We estimated this from when it was added and where it’s stored, not the pack.'
        : 'This is the date you set from the pack.';
    switch (item.location) {
      case PantryLocation.fresh:
        return '$base Check it looks and smells fresh before cooking. If it’s slimy or smells off, throw it away.';
      case PantryLocation.fridge:
        return '$base Once opened, most fridge items keep for a few days.';
      case PantryLocation.freezer:
        return '$base Frozen food stays safe for longer, but quality drops over time.';
      case PantryLocation.pantry:
        return '$base Store dry and sealed once opened.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final band = item.freshness;
    final color = switch (band) {
      FreshnessBand.fresh => PantryColors.green,
      FreshnessBand.useSoon => PantryColors.amber,
      FreshnessBand.useFirst || FreshnessBand.expired => PantryColors.red,
    };
    final bg = switch (band) {
      FreshnessBand.fresh => PantryColors.greenBg,
      FreshnessBand.useSoon => PantryColors.amberBg,
      FreshnessBand.useFirst || FreshnessBand.expired => PantryColors.redBg,
    };
    final active = switch (band) {
      FreshnessBand.fresh => 0,
      FreshnessBand.useSoon => 1,
      FreshnessBand.useFirst || FreshnessBand.expired => 2,
    };
    const segColors = [
      Color(0xFFBFE6CF),
      Color(0xFFF7DDAE),
      PantryColors.red,
    ];
    const segLabels = ['Fresh', 'Use soon', 'Use first'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(Icons.schedule_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: color,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    if (item.bestBefore != null)
                      Text(
                        'Best before ${pantryShortDate(item.bestBefore!)}'
                        '${item.bestBeforeEstimated ? ' · estimated' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == active
                                ? color
                                : segColors[i].withValues(
                                    alpha: i == 2 ? 0.35 : 1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (i == active) ...[
                              Icon(Icons.change_history_rounded,
                                  size: 12, color: color),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              segLabels[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: i == active
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: i == active
                                    ? color
                                    : AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _advice,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Amount + details ────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final PantryItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onEditUnit;

  const _AmountCard({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onEditUnit,
  });

  @override
  Widget build(BuildContext context) {
    final step = PantryService.quantityStep(item.unit);
    final stepLabel = step == step.roundToDouble()
        ? step.round().toString()
        : step.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: pantryCard(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.quantityLabel,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                GestureDetector(
                  onTap: onEditUnit,
                  child: Text(
                    'Unit: ${item.unit.isEmpty ? 'none' : item.unit} · $stepLabel steps · Edit',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PantryColors.indigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _CircleBtn(icon: Icons.remove_rounded, onTap: onMinus),
          const SizedBox(width: 10),
          _CircleBtn(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: Color(0xFFD5D3F0))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: AppColors.textDark),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final PantryItem item;
  final ValueChanged<PantryLocation> onLocation;
  final VoidCallback onEditDate;
  final VoidCallback onEditCategory;
  final VoidCallback onEditName;
  final VoidCallback? onMarkFrozen;

  const _DetailsCard({
    required this.item,
    required this.onLocation,
    required this.onEditDate,
    required this.onEditCategory,
    required this.onEditName,
    this.onMarkFrozen,
  });

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 15, color: AppColors.textMedium);
    const value = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: AppColors.textDark,
    );
    Widget edit(VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Edit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: PantryColors.indigo,
              ),
            ),
          ),
        );
    const divider = Divider(height: 32, color: PantryColors.border);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: pantryCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Name', style: label),
              const Spacer(),
              Flexible(
                child: Text(
                  item.name,
                  textAlign: TextAlign.right,
                  style: value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              edit(onEditName),
            ],
          ),
          divider,
          const Text('Stored in', style: label),
          const SizedBox(height: 12),
          PantrySegmented<PantryLocation>(
            options: [
              for (final l in PantryLocation.values) (label: l.label, value: l),
            ],
            selected: item.location,
            onSelect: onLocation,
          ),
          if (onMarkFrozen != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onMarkFrozen,
                icon: const Icon(Icons.ac_unit_rounded, size: 18),
                label: const Text('Mark as frozen'),
                style: TextButton.styleFrom(
                  foregroundColor: PantryColors.indigo,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          divider,
          Row(
            children: [
              const Text('Best before', style: label),
              const Spacer(),
              Text(
                item.bestBefore == null
                    ? 'Not set'
                    : pantryLongDate(item.bestBefore!),
                style: value,
              ),
              if (item.bestBefore != null && item.bestBeforeEstimated) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PantryColors.segmentBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Estimate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ],
              edit(onEditDate),
            ],
          ),
          divider,
          Row(
            children: [
              const Text('Category', style: label),
              const Spacer(),
              Flexible(
                child: Text(
                  item.categoryLabel,
                  style: value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              edit(onEditCategory),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Use it in ───────────────────────────────────────────────────────────────

class _UseItInCard extends StatelessWidget {
  final PantryItem item;
  final PantryMeal meal;
  final VoidCallback onTap;

  const _UseItInCard({
    required this.item,
    required this.meal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = meal.recipe;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: pantryCard(),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: RecipeThumbnailImage(
                    imageUrl: r.imageUrl,
                    emoji: '🍽️',
                    placeholderColor: AppColors.primaryLight,
                    cacheWidth: 240,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Best match',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: PantryColors.indigo,
                      ),
                    ),
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
                      '${meal.hasAll ? 'You have everything' : '${meal.have.length} of ${meal.total} in your pantry'}'
                      ' · ${r.cookTimeLabel} · ${r.difficultyLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OutlineAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: Colors.white,
          side: const BorderSide(color: PantryColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
