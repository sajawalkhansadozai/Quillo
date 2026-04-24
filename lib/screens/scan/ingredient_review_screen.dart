import 'package:flutter/material.dart';
import '../../models/ingredient_item.dart';
import '../../services/recipe_service.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import 'recipe_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IngredientReviewScreen
// Shows OCR results as an editable list. User can add/edit/delete ingredients
// before tapping "Generate Recipes".
// ─────────────────────────────────────────────────────────────────────────────

class IngredientReviewScreen extends StatefulWidget {
  final String scanId;
  final List<IngredientItem> ingredients;

  const IngredientReviewScreen({
    super.key,
    required this.scanId,
    required this.ingredients,
  });

  @override
  State<IngredientReviewScreen> createState() => _IngredientReviewScreenState();
}

class _IngredientReviewScreenState extends State<IngredientReviewScreen> {
  late List<IngredientItem> _ingredients;
  bool _isGenerating = false;
  final _addController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.ingredients);
  }

  @override
  void dispose() {
    _addController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Generate recipes ────────────────────────────────────────────────────────

  Future<void> _generateRecipes() async {
    if (_ingredients.isEmpty) {
      _showSnack('Add at least one ingredient before generating recipes.');
      return;
    }
    setState(() => _isGenerating = true);

    try {
      final recipes = await RecipeService.generateRecipes(
        scanId: widget.scanId,
        ingredients: _ingredients,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw const ScanException(
            'Recipe generation is taking longer than usual — tap to retry.'),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeResultsScreen(
            scanId: widget.scanId,
            recipes: recipes,
          ),
        ),
      );
    } on RateLimitException catch (e) {
      setState(() => _isGenerating = false);
      _showSnack(e.message);
    } on ScanException catch (e) {
      setState(() => _isGenerating = false);
      _showSnack(e.message);
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnack('Recipe generation is taking longer than usual — tap to retry.');
    }
  }

  // ── Edit ingredient inline ──────────────────────────────────────────────────

  void _editIngredient(int index) {
    final item = _ingredients[index];
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(
        text: item.quantity != null
            ? (item.quantity! % 1 == 0
                ? item.quantity!.toInt().toString()
                : item.quantity!.toString())
            : '');
    final unitCtrl = TextEditingController(text: item.unit ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Ingredient',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito')),
            const SizedBox(height: 20),
            _EditField(label: 'NAME', controller: nameCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    flex: 2,
                    child: _EditField(
                        label: 'QUANTITY',
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    flex: 3,
                    child: _EditField(label: 'UNIT (e.g. g, kg, ml)', controller: unitCtrl)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.chipBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMedium)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() {
                        _ingredients[index] = IngredientItem(
                          name: name,
                          quantity: double.tryParse(qtyCtrl.text.trim()),
                          unit: unitCtrl.text.trim().isEmpty
                              ? null
                              : unitCtrl.text.trim(),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Save',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Add new ingredient ──────────────────────────────────────────────────────

  void _addIngredient() {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _ingredients.add(IngredientItem(name: name));
      _addController.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildList()),
            _buildAddRow(),
            _buildGenerateButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Review Ingredients',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        fontFamily: 'Nunito')),
                Text(
                  '${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'} found',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_ingredients.length}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Instruction banner ──────────────────────────────────────────────────────

  Widget _buildInstructionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('✏️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tap any ingredient to edit. Swipe left to delete.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.primary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ingredient list ─────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_ingredients.isEmpty) {
      return _buildEmptyState();
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _buildInstructionBanner(),
        ...List.generate(_ingredients.length, (i) {
          final item = _ingredients[i];
          return Dismissible(
            key: ValueKey('$i-${item.name}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) =>
                setState(() => _ingredients.removeAt(i)),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: const Color(0xFFE53935),
              child:
                  const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            ),
            child: GestureDetector(
              onTap: () => _editIngredient(i),
              child: _IngredientRow(item: item, index: i),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🫙', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('No ingredients found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito')),
          const SizedBox(height: 8),
          Text(
            'The OCR couldn\'t find any food items.\nAdd them manually below.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textMedium, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Add ingredient row ──────────────────────────────────────────────────────

  Widget _buildAddRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.chipBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: TextField(
                controller: _addController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Add ingredient...',
                  hintStyle: TextStyle(
                      fontSize: 14, color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primary, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _addIngredient(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _addIngredient,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ── Generate button ─────────────────────────────────────────────────────────

  Widget _buildGenerateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: GestureDetector(
        onTap: _isGenerating ? null : _generateRecipes,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isGenerating
                  ? [
                      AppColors.primary.withValues(alpha: 0.6),
                      const Color(0xFF9C8FFF).withValues(alpha: 0.6)
                    ]
                  : [AppColors.primary, const Color(0xFF9C8FFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isGenerating
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: _isGenerating
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      ),
                      SizedBox(width: 12),
                      Text('Generating recipes...',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Nunito')),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      const Text('Generate Recipes',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              fontFamily: 'Nunito')),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ingredient row widget
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final IngredientItem item;
  final int index;

  const _IngredientRow({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                if (item.displayAmount.isNotEmpty)
                  Text(item.displayAmount,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined,
              size: 18, color: AppColors.textLight),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit field
// ─────────────────────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMedium,
                letterSpacing: 1.1)),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.chipBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppColors.textDark),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}
