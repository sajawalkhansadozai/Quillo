import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/generated_recipe.dart';
import '../theme/app_theme.dart';
import '../utils/recipe_image_source.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full nutrition breakdown — Premium (redesigned to match nutrition mockup).
// ─────────────────────────────────────────────────────────────────────────────

class RecipeFullNutritionSheet extends StatefulWidget {
  final GeneratedRecipe recipe;
  final int initialServings;

  const RecipeFullNutritionSheet({
    super.key,
    required this.recipe,
    this.initialServings = 0,
  });

  @override
  State<RecipeFullNutritionSheet> createState() =>
      _RecipeFullNutritionSheetState();
}

class _RecipeFullNutritionSheetState extends State<RecipeFullNutritionSheet> {
  static const _bg = Color(0xFFF3F3F5);
  static const _protein = Color(0xFF5B6CFF);
  static const _carbs = Color(0xFFD4A017);
  static const _fat = Color(0xFFA05A3C);
  static const _gaugeTrack = Color(0xFFE6E8F0);
  static const _highGold = Color(0xFFC9A227);

  static const _dvCalories = 2000.0;
  static const _dvProtein = 50.0;
  static const _dvCarbs = 275.0;
  static const _dvFat = 78.0;
  static const _dvFiber = 28.0;
  static const _dvSugar = 50.0;
  static const _dvSaturatedFat = 20.0;
  static const _dvSalt = 6.0;
  static const _dvIron = 14.0;
  static const _dvVitaminC = 80.0;
  static const _dvCalcium = 800.0;
  static const _dvPotassium = 4700.0;
  static const _dvCholesterol = 300.0;

  late int _baseServings;
  late int _servings;
  bool _perServing = true;

  @override
  void initState() {
    super.initState();
    _baseServings = widget.recipe.servings > 0 ? widget.recipe.servings : 1;
    _servings = widget.initialServings > 0
        ? widget.initialServings
        : _baseServings;
  }

  /// Stored nutrition is per serving.
  RecipeNutritionData get _displayNutrition {
    final per = widget.recipe.nutrition;
    if (_perServing) return per;
    return per.scaled(_servings.toDouble());
  }

  void _decrementServings() {
    if (_servings <= 1) return;
    setState(() => _servings--);
  }

  void _incrementServings() {
    if (_servings >= 12) return;
    setState(() => _servings++);
  }

  @override
  Widget build(BuildContext context) {
    final n = _displayNutrition;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                _buildNavBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleRow(),
                        const SizedBox(height: 16),
                        _buildModeToggle(),
                        const SizedBox(height: 12),
                        _buildServingsCard(),
                        const SizedBox(height: 14),
                        _buildMacrosCard(n),
                        const SizedBox(height: 14),
                        _buildCalorieSourceCard(n),
                        const SizedBox(height: 14),
                        _buildOtherNutrientsCard(n),
                        const SizedBox(height: 16),
                        _buildDisclaimer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textDark, size: 18),
          ),
          const Expanded(
            child: Text(
              'Nutrition',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PREMIUM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    final url = resizedRecipeImageUrl(widget.recipe.imageUrl, width: 160);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.recipe.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: url != null && url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    errorWidget: (_, __, ___) => _thumbFallback(),
                  )
                : _thumbFallback(),
          ),
        ),
      ],
    );
  }

  Widget _thumbFallback() {
    return ColoredBox(
      color: AppColors.primaryLight,
      child: const Center(
        child: Text('🍽️', style: TextStyle(fontSize: 26)),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E2D8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Per serving',
              selected: _perServing,
              onTap: () => setState(() => _perServing = true),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Whole recipe',
              selected: !_perServing,
              onTap: () => setState(() => _perServing = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    size: 20, color: AppColors.textMedium),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Servings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _perServing
                          ? '1 of $_servings servings'
                          : '$_servings servings',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              _ServingBtn(icon: Icons.remove, onTap: _decrementServings),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$_servings',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              _ServingBtn(icon: Icons.add, onTap: _incrementServings),
            ],
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Per-serving values stay the same; whole-recipe totals change with servings.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosCard(RecipeNutritionData n) {
    final calPct = (n.calories / _dvCalories * 100).clamp(0, 999);
    final proteinPct = n.protein / _dvProtein;
    final carbsPct = n.carbs / _dvCarbs;
    final fatPct = n.fat / _dvFat;
    final insight = _insightText(n);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(220, 140),
                  painter: _SemiGaugePainter(
                    progress: (n.calories / _dvCalories).clamp(0.0, 1.0),
                    color: _protein,
                    trackColor: _gaugeTrack,
                  ),
                ),
                Positioned(
                  bottom: 4,
                  child: Column(
                    children: [
                      Text(
                        '${n.calories}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontFamily: 'Nunito',
                          height: 1,
                        ),
                      ),
                      const Text(
                        'kcal',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${calPct.round()}% of a 2,000 kcal day',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MacroRing(
                  label: 'Protein',
                  grams: n.protein,
                  progress: proteinPct.clamp(0.0, 1.0),
                  dvPct: (proteinPct * 100).round(),
                  color: _protein,
                ),
              ),
              Expanded(
                child: _MacroRing(
                  label: 'Carbs',
                  grams: n.carbs,
                  progress: carbsPct.clamp(0.0, 1.0),
                  dvPct: (carbsPct * 100).round(),
                  color: _carbs,
                ),
              ),
              Expanded(
                child: _MacroRing(
                  label: 'Fat',
                  grams: n.fat,
                  progress: fatPct.clamp(0.0, 1.0),
                  dvPct: (fatPct * 100).round(),
                  color: _fat,
                ),
              ),
            ],
          ),
          if (insight != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _protein,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('🍗', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _insightText(RecipeNutritionData n) {
    final proteinPct = (n.protein / _dvProtein * 100).round();
    final fiberPct =
        n.fiber != null ? (n.fiber! / _dvFiber * 100).round() : 0;
    final scope = _perServing ? 'One serving' : 'This recipe';

    if (proteinPct >= 20) {
      return 'High in protein. $scope gives $proteinPct% of the daily value.';
    }
    if (fiberPct >= 20) {
      return 'High in fibre. $scope gives $fiberPct% of the daily value.';
    }
    if (n.calories > 0) {
      final calPct = (n.calories / _dvCalories * 100).round();
      return '$scope provides $calPct% of a 2,000 kcal day.';
    }
    return null;
  }

  Widget _buildCalorieSourceCard(RecipeNutritionData n) {
    final pKcal = n.protein * 4;
    final cKcal = n.carbs * 4;
    final fKcal = n.fat * 9;
    final total = (pKcal + cKcal + fKcal).clamp(1, 99999);
    final pShare = pKcal / total;
    final cShare = cKcal / total;
    final fShare = fKcal / total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Where the calories come from',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  'kcal',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  'Share',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (pShare > 0)
                    Expanded(
                      flex: (pShare * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: _protein),
                    ),
                  if (cShare > 0)
                    Expanded(
                      flex: (cShare * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: _carbs),
                    ),
                  if (fShare > 0)
                    Expanded(
                      flex: (fShare * 1000).round().clamp(1, 1000),
                      child: const ColoredBox(color: _fat),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CalorieSourceRow(
            color: _protein,
            label: 'Protein',
            grams: n.protein,
            kcal: pKcal,
            pct: (pShare * 100).round(),
          ),
          const Divider(height: 20),
          _CalorieSourceRow(
            color: _carbs,
            label: 'Carbs',
            grams: n.carbs,
            kcal: cKcal,
            pct: (cShare * 100).round(),
          ),
          const Divider(height: 20),
          _CalorieSourceRow(
            color: _fat,
            label: 'Fat',
            grams: n.fat,
            kcal: fKcal,
            pct: (fShare * 100).round(),
          ),
          const SizedBox(height: 10),
          Text(
            '4 kcal per gram for protein and carbs, 9 for fat. '
            'Together: ${pKcal + cKcal + fKcal} of ${n.calories} kcal.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textLight.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherNutrientsCard(RecipeNutritionData n) {
    final sugarsFats = <_OtherNutrient>[
      if ((n.sugar ?? 0) > 0)
        _OtherNutrient(
          'Sugars',
          '${n.sugar} g',
          n.sugar! / _dvSugar,
          context: 'of ${n.carbs} g carbs',
        ),
      if ((n.saturatedFat ?? 0) > 0)
        _OtherNutrient(
          'Saturated fat',
          '${n.saturatedFat} g',
          n.saturatedFat! / _dvSaturatedFat,
          context: 'of ${n.fat} g fat',
        ),
      if ((n.fiber ?? 0) > 0)
        _OtherNutrient('Fibre', '${n.fiber} g', n.fiber! / _dvFiber),
    ];

    final salt = _saltGrams(n.sodium);
    final minerals = <_OtherNutrient>[
      if (salt > 0)
        _OtherNutrient('Salt', '${salt.toStringAsFixed(1)} g', salt / _dvSalt),
      if ((n.potassium ?? 0) > 0)
        _OtherNutrient(
            'Potassium', '${n.potassium} mg', n.potassium! / _dvPotassium),
      if ((n.cholesterol ?? 0) > 0)
        _OtherNutrient(
            'Cholesterol', '${n.cholesterol} mg', n.cholesterol! / _dvCholesterol),
      if ((n.iron ?? 0) > 0)
        _OtherNutrient('Iron', '${n.iron} mg', n.iron! / _dvIron),
      if ((n.calcium ?? 0) > 0)
        _OtherNutrient('Calcium', '${n.calcium} mg', n.calcium! / _dvCalcium),
      if ((n.vitaminC ?? 0) > 0)
        _OtherNutrient(
            'Vitamin C', '${n.vitaminC} mg', n.vitaminC! / _dvVitaminC),
    ];

    if (sugarsFats.isEmpty && minerals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Text(
          widget.recipe.nutrition.hasExtendedDetails
              ? 'No additional micronutrient values for this recipe.'
              : 'Micronutrient details appear for Explore catalog recipes. '
                  'Scan recipes show macro breakdown.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMedium.withValues(alpha: 0.95),
            height: 1.4,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Other nutrients',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
              Text(
                '% DV*',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
          if (sugarsFats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sugars, fats and fibre',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
                Text(
                  _perServing ? 'Per serving' : 'Whole recipe',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final item in sugarsFats)
              _OtherNutrientRow(item: item, perServing: _perServing),
          ],
          if (minerals.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Minerals and cholesterol',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
                Text(
                  '% DV*',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final item in minerals)
              _OtherNutrientRow(item: item, perServing: _perServing),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      '* Daily Value (DV) is the share of an average adult\'s daily '
      'reference intake that one serving provides, based on 2,000 kcal a day. '
      '"High" means 20% DV or more per serving and "low" 5% or less, '
      'following the FDA\'s 5/20 guide.',
      style: TextStyle(
        fontSize: 11,
        color: AppColors.textLight.withValues(alpha: 0.95),
        height: 1.4,
      ),
    );
  }

  static double _saltGrams(int? sodiumMg) {
    if (sodiumMg == null || sodiumMg <= 0) return 0;
    return (sodiumMg / 1000 * 2.5 * 10).round() / 10;
  }

  static BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      );
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.textDark : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

class _ServingBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ServingBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F6),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(icon, size: 18, color: AppColors.textDark),
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  final String label;
  final int grams;
  final double progress;
  final int dvPct;
  final Color color;

  const _MacroRing({
    required this.label,
    required this.grams,
    required this.progress,
    required this.dvPct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(84, 84),
                painter: _FullRingPainter(
                  progress: progress,
                  color: color,
                  trackColor: color.withValues(alpha: 0.15),
                ),
              ),
              Text(
                '$grams',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        Text(
          '$dvPct% DV*',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}

class _CalorieSourceRow extends StatelessWidget {
  final Color color;
  final String label;
  final int grams;
  final int kcal;
  final int pct;

  const _CalorieSourceRow({
    required this.color,
    required this.label,
    required this.grams,
    required this.kcal,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                '$grams g',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$kcal',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _OtherNutrient {
  final String label;
  final String amount;
  final double dvRatio;
  final String? context;

  const _OtherNutrient(this.label, this.amount, this.dvRatio, {this.context});

  int get dvPct => (dvRatio * 100).round();
  bool get isHigh => dvPct >= 20;
}

class _OtherNutrientRow extends StatelessWidget {
  final _OtherNutrient item;
  final bool perServing;

  const _OtherNutrientRow({required this.item, required this.perServing});

  @override
  Widget build(BuildContext context) {
    final scope = perServing ? 'one serving' : 'this recipe';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                      item.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    if (item.context != null)
                      Text(
                        item.context!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                item.amount,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 48,
                child: Text(
                  '${item.dvPct}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
            ],
          ),
          if (item.isHigh) ...[
            const SizedBox(height: 4),
            Text(
              'High · ${item.dvPct}% of the daily value in $scope.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _RecipeFullNutritionSheetState._highGold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _SemiGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _SemiGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 16.0;
    final center = Offset(size.width / 2, size.height - 8);
    final radius = size.width / 2 - stroke;
    const start = math.pi;
    const sweep = math.pi;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter old) =>
      old.progress != progress || old.color != color;
}

class _FullRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _FullRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const start = -math.pi / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 2,
      false,
      track,
    );

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FullRingPainter old) =>
      old.progress != progress || old.color != color;
}
