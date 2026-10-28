import 'package:flutter/material.dart';
import '../../models/ingredient_item.dart';
import '../../widgets/ingredient_visual_icon.dart';
import '../../services/pantry_service.dart';
import '../../services/recipe_service.dart';
import '../../services/scan_service.dart';
import '../../services/scan_limit_service.dart';
import '../../services/streak_service.dart';
import '../../services/food_waste_service.dart';
import '../../services/ad_service.dart';
import '../../utils/non_food_ingredient_filter.dart';
import '../../widgets/scan_limit_sheet.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ad_banner.dart';
import 'recipe_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IngredientReviewScreen
// Shows OCR results as an editable list. User can add/edit/delete ingredients
// before tapping "Generate Recipes".
// ─────────────────────────────────────────────────────────────────────────────

class IngredientReviewScreen extends StatefulWidget {
  final String scanId;
  final List<IngredientItem> ingredients;
  /// True when quota was already consumed during receipt OCR (≥3 items).
  final bool receiptAlreadyCounted;
  /// Fewer than 3 OCR ingredients — show partial UX (§06).
  final bool isPartial;
  final String? partialMessage;

  const IngredientReviewScreen({
    super.key,
    required this.scanId,
    required this.ingredients,
    this.receiptAlreadyCounted = false,
    this.isPartial = false,
    this.partialMessage,
  });

  @override
  State<IngredientReviewScreen> createState() => _IngredientReviewScreenState();
}

class _IngredientReviewScreenState extends State<IngredientReviewScreen> {
  late List<IngredientItem> _ingredients;
  bool _isGenerating = false;
  final _addController = TextEditingController();
  final _scrollController = ScrollController();
  late List<String> _suggestions;

  static const _companions = <String, List<String>>{
    'chicken': ['garlic', 'lemon', 'onion', 'olive oil'],
    'beef': ['onion', 'garlic', 'tomato', 'potato'],
    'salmon': ['lemon', 'dill', 'asparagus', 'butter'],
    'pasta': ['garlic', 'olive oil', 'parmesan', 'tomato'],
    'rice': ['onion', 'garlic', 'egg', 'soy sauce'],
    'egg': ['butter', 'milk', 'cheese', 'bread'],
    'tomato': ['onion', 'garlic', 'basil', 'olive oil'],
    'milk': ['eggs', 'butter', 'flour', 'cheese'],
    'potato': ['onion', 'butter', 'garlic', 'cheese'],
    'bread': ['butter', 'cheese', 'egg', 'tomato'],
  };

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.ingredients);
    _suggestions = _buildSuggestions();
  }

  List<String> _buildSuggestions() {
    final have = _ingredients.map((e) => e.name.toLowerCase()).toSet();
    final out = <String>{};
    for (final item in _ingredients) {
      final key = item.name.toLowerCase();
      for (final entry in _companions.entries) {
        if (key.contains(entry.key)) {
          for (final s in entry.value) {
            if (!have.any((h) => h.contains(s)) &&
                !out.any((o) => o.toLowerCase() == s)) {
              out.add(s[0].toUpperCase() + s.substring(1));
            }
          }
        }
      }
    }
    return out.take(6).toList();
  }

  void _addSuggestion(String name) {
    setState(() {
      _ingredients.add(IngredientItem(name: name));
      _suggestions = _buildSuggestions();
    });
  }

  @override
  void dispose() {
    _addController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Checklist 01 — one scan fills recipes + pantry. Never throws into the scan.
  Future<int> _saveIngredientsToSmartPantry() async {
    try {
      final foodItems = NonFoodIngredientFilter.filter(
        _ingredients,
        (i) => i.name,
      );
      if (foodItems.isEmpty) return 0;
      final payload = foodItems
          .map((i) => (
                name: i.name,
                quantity: i.quantity,
                unit: i.unit,
              ))
          .toList();
      return await PantryService.addFromScan(
        scanId: widget.scanId,
        items: payload,
        receiptFingerprint: PantryService.receiptFingerprint(payload),
        sourceNote: 'Added from your receipt',
      );
    } catch (e) {
      debugPrint('Smart Pantry auto-save failed (scan continues): $e');
      return 0;
    }
  }

  // ── Generate recipes ────────────────────────────────────────────────────────

  Future<void> _generateRecipes() async {
    if (_ingredients.isEmpty) {
      _showSnack('Add at least one ingredient before generating recipes.');
      return;
    }
    if (!widget.receiptAlreadyCounted) {
      if (!await ScanLimitService.canScan()) {
        if (mounted) await showScanLimitSheet(context);
        return;
      }
    }
    setState(() => _isGenerating = true);

    // Checklist 01: pantry fills from the main scan after review, in parallel
    // with recipe generation — never blocked by recipe success/failure, and
    // never requiring a second pantry-only scan.
    final pantryFuture = _saveIngredientsToSmartPantry();

    // Show interstitial while recipes generate so results are ready when dismissed.
    final adFuture = AdService.showInterstitialIfFree(waitUntilDismissed: true);

    try {
      final recipes = await RecipeService.generateRecipes(
        scanId: widget.scanId,
        ingredients: _ingredients,
        isManualEntry: !widget.receiptAlreadyCounted,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw const ScanException(
            'Recipe generation is taking longer than usual — tap to retry.'),
      );

      if (!widget.receiptAlreadyCounted) {
        await ScanLimitService.recordScan();
      }
      await StreakService.recordScan();
      await FoodWasteService.recordIngredientsRescued(_ingredients);
      final pantryAdded = await pantryFuture;
      await adFuture;

      if (!mounted) return;
      final pantryNote = pantryAdded > 0
          ? ' · $pantryAdded saved to Smart Pantry'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_ingredients.length} ingredients found · ${recipes.length} recipes ready$pantryNote',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeResultsScreen(
            scanId: widget.scanId,
            recipes: recipes,
          ),
        ),
      );
    } on RateLimitException catch (e) {
      await pantryFuture;
      await adFuture;
      setState(() => _isGenerating = false);
      _showSnack(e.message);
    } on ScanException catch (e) {
      await pantryFuture;
      await adFuture;
      setState(() => _isGenerating = false);
      _showSnack(e.message);
    } catch (e) {
      await pantryFuture;
      await adFuture;
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
    return AdScaffold(
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
                  widget.isPartial
                      ? (_ingredients.isEmpty
                          ? 'No items detected — add what you bought'
                          : 'We found some — add any we missed')
                      : '${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'} found',
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
    if (widget.isPartial) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partialMessage ??
                  'We found some of your ingredients. Add any we missed below.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5D4037),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!widget.receiptAlreadyCounted) ...[
              const SizedBox(height: 6),
              Text(
                'This scan did not use one of your credits.',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF5D4037).withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('✏️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap any ingredient to edit. Swipe left to delete.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            // Acceptance test 8 — pantry write + premium gate copy.
            'Food items are saved to your Smart Pantry after this step. '
            'Smart Pantry unlocks with Premium.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsRow() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Did you also buy?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return ActionChip(
                label: Text(s),
                onPressed: () => _addSuggestion(s),
                backgroundColor: AppColors.primaryLight,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Ingredient list ─────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_ingredients.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          if (widget.isPartial) _buildInstructionBanner(),
          _buildEmptyState(),
          if (widget.isPartial) _buildSuggestionsRow(),
        ],
      );
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _buildInstructionBanner(),
        if (widget.isPartial) _buildSuggestionsRow(),
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
              child: _IngredientRow(item: item),
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
          Image.asset(
            'assets/food_3d/jar.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
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

  const _IngredientRow({required this.item});

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
          IngredientVisualIcon(ingredientName: item.name, size: 40),
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
