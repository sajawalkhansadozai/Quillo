import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/merged_shopping_list.dart';
import '../../services/shopping_list_service.dart';
import '../../theme/app_theme.dart';

/// Unified shopping list — all recipes, merged and sorted by aisle.
class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  MergedShoppingListResult _merged = MergedShoppingListResult.empty;
  bool _loading = true;
  bool _hideChecked = false;

  int get _toBuyCount => _merged.totalCount - _merged.checkedCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final merged = await ShoppingListService.getMergedList();
    if (!mounted) return;
    setState(() {
      _merged = merged;
      _loading = false;
    });
  }

  Future<void> _toggle(MergedShoppingItem item) async {
    final next = !item.checked;
    HapticFeedback.selectionClick();
    setState(() {
      _merged = _withChecked(item.key, next);
    });
    await ShoppingListService.toggleMergedItem(item, next);
  }

  MergedShoppingListResult _withChecked(String key, bool checked) {
    return MergedShoppingListResult(
      recipeCount: _merged.recipeCount,
      categories: _merged.categories
          .map(
            (cat) => ShoppingListCategory(
              id: cat.id,
              label: cat.label,
              items: cat.items
                  .map((i) => i.key == key ? i.copyWith(checked: checked) : i)
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  Future<void> _clearCompleted() async {
    if (_merged.checkedCount == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed items?'),
        content: Text(
          'Remove ${_merged.checkedCount} item${_merged.checkedCount == 1 ? '' : 's'} '
          'you already shopped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ShoppingListService.removeCompletedItems();
    if (!mounted) return;
    await _load();
  }

  List<ShoppingListCategory> get _visibleCategories {
    return _merged.categories
        .map((cat) {
          final items = _hideChecked
              ? cat.items.where((i) => !i.checked).toList()
              : cat.items;
          return ShoppingListCategory(
            id: cat.id,
            label: cat.label,
            items: items,
          );
        })
        .where((cat) => cat.items.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  _Header(
                    hideChecked: _hideChecked,
                    hasChecked: _merged.checkedCount > 0,
                    onBack: () => Navigator.pop(context),
                    onToggleHide: () =>
                        setState(() => _hideChecked = !_hideChecked),
                    onClearCompleted: _merged.checkedCount > 0
                        ? _clearCompleted
                        : null,
                  ),
                  Expanded(
                    child: _merged.totalCount == 0
                        ? RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [_EmptyState()],
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverToBoxAdapter(
                                  child: _SummarySection(
                                    itemsLeft: _toBuyCount,
                                    checkedCount: _merged.checkedCount,
                                    totalCount: _merged.totalCount,
                                    recipeCount: _merged.recipeCount,
                                  ),
                                ),
                                if (_visibleCategories.isEmpty &&
                                    _hideChecked &&
                                    _merged.checkedCount > 0)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(24, 32, 24, 16),
                                      child: Text(
                                        'All items are checked. Tap “Show checked” to see them again.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textMedium,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                for (final cat in _visibleCategories) ...[
                                  SliverToBoxAdapter(
                                    child: _CategoryHeader(
                                      label: cat.label,
                                      checkedCount: _merged.categories
                                          .firstWhere((c) => c.id == cat.id)
                                          .items
                                          .where((i) => i.checked)
                                          .length,
                                      totalCount: _merged.categories
                                          .firstWhere((c) => c.id == cat.id)
                                          .items
                                          .length,
                                    ),
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        final item = cat.items[i];
                                        return _IngredientRow(
                                          item: item,
                                          onTap: () => _toggle(item),
                                        );
                                      },
                                      childCount: cat.items.length,
                                    ),
                                  ),
                                ],
                                const SliverToBoxAdapter(
                                    child: SizedBox(height: 40)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool hideChecked;
  final bool hasChecked;
  final VoidCallback onBack;
  final VoidCallback onToggleHide;
  final VoidCallback? onClearCompleted;

  const _Header({
    required this.hideChecked,
    required this.hasChecked,
    required this.onBack,
    required this.onToggleHide,
    this.onClearCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textDark, size: 18),
            onPressed: onBack,
          ),
          const Expanded(
            child: Text(
              'Shopping list',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          if (hasChecked)
            TextButton(
              onPressed: onToggleHide,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                hideChecked ? 'Show checked' : 'Hide checked',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (onClearCompleted != null)
            IconButton(
              tooltip: 'Clear completed',
              icon: const Icon(Icons.playlist_remove_rounded,
                  color: AppColors.textLight, size: 22),
              onPressed: onClearCompleted,
            ),
        ],
      ),
    );
  }
}

// ── Summary + progress ────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  final int itemsLeft;
  final int checkedCount;
  final int totalCount;
  final int recipeCount;

  const _SummarySection({
    required this.itemsLeft,
    required this.checkedCount,
    required this.totalCount,
    required this.recipeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$itemsLeft item${itemsLeft == 1 ? '' : 's'} left',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$checkedCount of $totalCount in your basket'
            ' · $recipeCount recipe${recipeCount == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _SegmentedProgress(
            checkedCount: checkedCount,
            totalCount: totalCount,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int checkedCount;
  final int totalCount;

  const _SegmentedProgress({
    required this.checkedCount,
    required this.totalCount,
  });

  static const _empty = Color(0xFFE8E4DC);

  @override
  Widget build(BuildContext context) {
    if (totalCount <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap segment count so bars stay readable on long lists.
        final segments = totalCount.clamp(1, 40);
        final filledRatio =
            totalCount == 0 ? 0.0 : checkedCount / totalCount;
        final filled = (segments * filledRatio).round().clamp(0, segments);

        return Row(
          children: List.generate(segments, (i) {
            final isFilled = i < filled;
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(
                  right: i == segments - 1 ? 0 : 3,
                ),
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.primary : _empty,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Category ──────────────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String label;
  final int checkedCount;
  final int totalCount;

  const _CategoryHeader({
    required this.label,
    required this.checkedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ($checkedCount of $totalCount)',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE6E6EC)),
        ],
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final MergedShoppingItem item;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checked = item.checked;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? AppColors.primary : const Color(0xFFC8C8D4),
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: checked
                          ? AppColors.textLight
                          : AppColors.textDark,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textLight,
                    ),
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.note,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: checked
                            ? AppColors.textLight
                            : AppColors.textMedium,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.amount.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                item.amount,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: checked
                      ? AppColors.textLight
                      : AppColors.textMedium,
                  decoration:
                      checked ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your list is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add ingredients from any recipe. Everything shows up here, merged and sorted by aisle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMedium.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
