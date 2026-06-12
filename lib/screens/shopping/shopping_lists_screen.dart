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
  bool _showCompleted = false;

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
          'you already shopped. Your list will only show what you still need to buy.',
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
    setState(() => _showCompleted = false);
    await _load();
  }

  List<ShoppingListCategory> _categories({required bool completedOnly}) {
    return _merged.categories
        .map((cat) {
          final items = cat.items
              .where((i) => completedOnly ? i.checked : !i.checked)
              .toList();
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
    final toBuy = _categories(completedOnly: false);
    final completed = _categories(completedOnly: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shopping List',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
        actions: [
          if (_merged.checkedCount > 0)
            IconButton(
              tooltip: 'Clear completed',
              icon: const Icon(Icons.playlist_remove_rounded,
                  color: AppColors.textDark),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _merged.totalCount == 0
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
                      SliverToBoxAdapter(child: _SummaryBar(
                        recipeCount: _merged.recipeCount,
                        toBuyCount: _toBuyCount,
                        completedCount: _merged.checkedCount,
                      )),
                      if (toBuy.isEmpty && _merged.checkedCount > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Text(
                              'Everything is checked off. Clear completed items '
                              'before your next shop, or add a new recipe.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMedium.withValues(alpha: 0.9),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ..._categorySlivers(toBuy, muted: false),
                      if (_merged.checkedCount > 0) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _showCompleted = !_showCompleted),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showCompleted
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: AppColors.textMedium,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _showCompleted
                                          ? 'Hide completed'
                                          : 'Show ${_merged.checkedCount} completed',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_showCompleted) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Text(
                                'ALREADY SHOPPED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textLight.withValues(alpha: 0.9),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          ..._categorySlivers(completed, muted: true),
                        ],
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _categorySlivers(List<ShoppingListCategory> categories,
      {required bool muted}) {
    return [
      for (final cat in categories) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              cat.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final item = cat.items[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _IngredientRow(
                  item: item,
                  muted: muted,
                  onTap: () => _toggle(item),
                ),
              );
            },
            childCount: cat.items.length,
          ),
        ),
      ],
    ];
  }
}

class _SummaryBar extends StatelessWidget {
  final int recipeCount;
  final int toBuyCount;
  final int completedCount;

  const _SummaryBar({
    required this.recipeCount,
    required this.toBuyCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$toBuyCount item${toBuyCount == 1 ? '' : 's'} to buy',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$recipeCount recipe${recipeCount == 1 ? '' : 's'}'
              '${completedCount > 0 ? ' · $completedCount already shopped' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final MergedShoppingItem item;
  final bool muted;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.item,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checked = item.checked || muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: muted ? const Color(0xFFF8F8FA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked
                ? AppColors.primary.withValues(alpha: muted ? 0.2 : 0.4)
                : AppColors.chipBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checked
                    ? AppColors.primary.withValues(alpha: muted ? 0.5 : 1)
                    : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: checked
                      ? AppColors.primary.withValues(alpha: muted ? 0.5 : 1)
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: checked
                          ? AppColors.textLight
                          : AppColors.textDark,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.amount.isNotEmpty)
                    Text(
                      item.amount,
                      style: TextStyle(
                        fontSize: 12,
                        color: checked
                            ? AppColors.textLight
                            : AppColors.textMedium,
                        decoration:
                            checked ? TextDecoration.lineThrough : null,
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
            decoration: BoxDecoration(
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
