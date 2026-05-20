import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/shopping_list.dart';
import '../../services/shopping_list_service.dart';
import '../../theme/app_theme.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  final String listId;

  const ShoppingListDetailScreen({super.key, required this.listId});

  @override
  State<ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  ShoppingList? _list;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ShoppingListService.getById(widget.listId);
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(int index, bool checked) async {
    await ShoppingListService.toggleItem(widget.listId, index, checked);
    HapticFeedback.selectionClick();
    await _load();
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete list?'),
        content: Text('Remove "${_list?.recipeName}" from your shopping lists?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ShoppingListService.delete(widget.listId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final list = _list;
    if (list == null) {
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
        ),
        body: const Center(
          child: Text('Shopping list not found',
              style: TextStyle(color: AppColors.textMedium)),
        ),
      );
    }

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
        title: Text(
          list.recipeName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
            onPressed: _deleteList,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${list.checkedCount}/${list.totalCount} checked',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: list.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = list.items[i];
                return GestureDetector(
                  onTap: () => _toggle(i, !item.checked),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.checked
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.chipBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: item.checked
                                ? AppColors.primary
                                : const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: item.checked
                                  ? AppColors.primary
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: item.checked
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
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
                                  color: item.checked
                                      ? AppColors.textLight
                                      : AppColors.textDark,
                                  decoration: item.checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (item.amount.isNotEmpty)
                                Text(
                                  item.amount,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item.checked
                                        ? AppColors.textLight
                                        : AppColors.textMedium,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
