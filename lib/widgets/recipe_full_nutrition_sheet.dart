import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/generated_recipe.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full nutrition breakdown — Premium (matches design mockup).
// Servings stepper rescales all figures live.
// ─────────────────────────────────────────────────────────────────────────────

class RecipeFullNutritionSheet extends StatefulWidget {
  final GeneratedRecipe recipe;

  /// Current serving count from recipe detail (defaults to recipe.servings).
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
  static const _headerBg = Color(0xFF12122A);

  late int _baseServings;
  late int _servings;

  @override
  void initState() {
    super.initState();
    _baseServings = widget.recipe.servings > 0 ? widget.recipe.servings : 1;
    _servings = widget.initialServings > 0
        ? widget.initialServings
        : _baseServings;
  }

  /// Nutrition in JSON is per serving — scale to selected serving count.
  RecipeNutritionData get _nutrition =>
      widget.recipe.nutrition.scaled(_servings / _baseServings);

  bool get _showScaledLabel => _servings != _baseServings;

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
    final n = _nutrition;
    final rows = _buildRows(n);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FA),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServingsCard(),
                  const SizedBox(height: 14),
                  _buildSummaryCard(n),
                  const SizedBox(height: 20),
                  Text(
                    _showScaledLabel
                        ? 'FULL BREAKDOWN — FOR $_servings SERVINGS'
                        : 'FULL BREAKDOWN — PER SERVING',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBreakdownCard(rows),
                  if (!widget.recipe.nutrition.hasExtendedDetails) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Micronutrient details appear for Explore catalog recipes. '
                      'Scan recipes show macro breakdown.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 18),
      decoration: const BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
          Expanded(
            child: Text(
              widget.recipe.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
            ),
            child: const Text(
              'Premium',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Servings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          _ServingBtn(icon: Icons.remove, onTap: _decrementServings),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
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
    );
  }

  Widget _buildSummaryCard(RecipeNutritionData n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _CalorieRing(calories: n.calories),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MacroTile(
                    label: 'Protein',
                    value: '${n.protein}g',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroTile(
                    label: 'Carbs',
                    value: '${n.carbs}g',
                    color: const Color(0xFF26A69A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroTile(
                    label: 'Fat',
                    value: '${n.fat}g',
                    color: const Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(List<_NutrientRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _NutrientBreakdownTile(row: rows[i]),
          ],
        ],
      ),
    );
  }

  List<_NutrientRow> _buildRows(RecipeNutritionData n) {
    final rows = <_NutrientRow>[
      _NutrientRow('Calories', n.calories.toDouble(), 'kcal', _dvCalories,
          barColor: const Color(0xFF6C63FF)),
      _NutrientRow('Protein', n.protein.toDouble(), 'g', _dvProtein,
          barColor: const Color(0xFF7E57C2)),
      _NutrientRow('Carbohydrates', n.carbs.toDouble(), 'g', _dvCarbs,
          barColor: const Color(0xFF26A69A)),
    ];

    if ((n.sugar ?? 0) > 0) {
      final idx = rows.length - 1;
      final parentColor = rows[idx].barColor;
      rows[idx] = rows[idx].copyWith(
        subRows: [
          _NutrientRow(
            'of which sugars',
            n.sugar!.toDouble(),
            'g',
            _dvSugar,
            isSub: true,
            barColor: parentColor,
          ),
        ],
      );
    }

    rows.add(_NutrientRow('Fat', n.fat.toDouble(), 'g', _dvFat,
        barColor: const Color(0xFFFF9800)));
    if ((n.saturatedFat ?? 0) > 0) {
      final idx = rows.length - 1;
      final parentColor = rows[idx].barColor;
      rows[idx] = rows[idx].copyWith(
        subRows: [
          _NutrientRow(
            'of which saturated',
            n.saturatedFat!.toDouble(),
            'g',
            _dvSaturatedFat,
            isSub: true,
            barColor: parentColor,
          ),
        ],
      );
    }

    if ((n.fiber ?? 0) > 0) {
      rows.add(_NutrientRow('Fibre', n.fiber!.toDouble(), 'g', _dvFiber,
          barColor: const Color(0xFF66BB6A)));
    }

    final saltG = _saltGrams(n.sodium);
    if (saltG > 0) {
      rows.add(_NutrientRow('Salt', saltG, 'g', _dvSalt,
          barColor: const Color(0xFF78909C)));
    }

    if ((n.iron ?? 0) > 0) {
      rows.add(_NutrientRow('Iron', n.iron!.toDouble(), 'mg', _dvIron,
          barColor: const Color(0xFF8D6E63)));
    }
    if ((n.vitaminC ?? 0) > 0) {
      rows.add(_NutrientRow('Vitamin C', n.vitaminC!.toDouble(), 'mg', _dvVitaminC,
          barColor: const Color(0xFFFFCA28)));
    }
    if ((n.calcium ?? 0) > 0) {
      rows.add(_NutrientRow('Calcium', n.calcium!.toDouble(), 'mg', _dvCalcium,
          barColor: const Color(0xFF42A5F5)));
    }
    if ((n.potassium ?? 0) > 0) {
      rows.add(_NutrientRow('Potassium', n.potassium!.toDouble(), 'mg', _dvPotassium,
          barColor: const Color(0xFFEC407A)));
    }
    if ((n.cholesterol ?? 0) > 0) {
      rows.add(_NutrientRow(
          'Cholesterol', n.cholesterol!.toDouble(), 'mg', _dvCholesterol,
          barColor: const Color(0xFFE57373)));
    }

    return rows;
  }

  static double _saltGrams(int? sodiumMg) {
    if (sodiumMg == null || sodiumMg <= 0) return 0;
    return (sodiumMg / 1000 * 2.5 * 10).round() / 10;
  }

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
}

// ── Row model ───────────────────────────────────────────────────────────────

class _NutrientRow {
  final String label;
  final double amount;
  final String unit;
  final double dailyValue;
  final bool isSub;
  final List<_NutrientRow> subRows;
  final Color barColor;

  const _NutrientRow(
    this.label,
    this.amount,
    this.unit,
    this.dailyValue, {
    this.isSub = false,
    this.subRows = const [],
    this.barColor = AppColors.primary,
  });

  _NutrientRow copyWith({List<_NutrientRow>? subRows}) => _NutrientRow(
        label,
        amount,
        unit,
        dailyValue,
        isSub: isSub,
        subRows: subRows ?? this.subRows,
        barColor: barColor,
      );

  double get dailyPercent =>
      dailyValue > 0 ? (amount / dailyValue * 100).clamp(0, 999) : 0;

  String get displayAmount {
    if (unit == 'kcal') return '${amount.round()} kcal';
    if (unit == 'g') {
      final v = amount % 1 == 0 ? amount.round().toString() : amount.toStringAsFixed(1);
      return '$v g';
    }
    return '${amount.round()} $unit';
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────────

class _ServingBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ServingBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.textDark),
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  final int calories;

  const _CalorieRing({required this.calories});

  @override
  Widget build(BuildContext context) {
    final pct = (calories / _RecipeFullNutritionSheetState._dvCalories)
        .clamp(0.0, 1.0);

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(88, 88),
            painter: _RingPainter(progress: pct),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$calories',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito',
                ),
              ),
              const Text(
                'kcal',
                style: TextStyle(fontSize: 11, color: AppColors.textMedium),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const start = -math.pi / 2;
    const sweep = math.pi * 2;

    final track = Paint()
      ..color = const Color(0xFFEEECFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    final fill = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF9C8CFF), Color(0xFF6C63FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _MacroTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          bottom: BorderSide(color: color, width: 2.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientBreakdownTile extends StatelessWidget {
  final _NutrientRow row;

  const _NutrientBreakdownTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, row.isSub ? 6 : 14, 16, row.isSub ? 6 : 8),
          child: _BreakdownRow(row: row),
        ),
        for (final sub in row.subRows)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _BreakdownRow(row: sub),
          ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final _NutrientRow row;

  const _BreakdownRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = row.dailyPercent / 100;
    final barColor =
        row.isSub ? row.barColor.withValues(alpha: 0.45) : row.barColor;
    final pctColor = row.isSub ? AppColors.textLight : row.barColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                row.label,
                style: TextStyle(
                  fontSize: row.isSub ? 12 : 14,
                  fontWeight: row.isSub ? FontWeight.w600 : FontWeight.w800,
                  color: row.isSub ? AppColors.textMedium : AppColors.textDark,
                  fontStyle: row.isSub ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            Text(
              row.displayAmount,
              style: TextStyle(
                fontSize: row.isSub ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: row.isSub ? AppColors.textMedium : AppColors.textDark,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                '${row.dailyPercent.round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: pctColor,
                ),
              ),
            ),
          ],
        ),
        if (!row.isSub) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.05, 1.0),
              minHeight: 5,
              backgroundColor: barColor.withValues(alpha: 0.15),
              color: barColor,
            ),
          ),
        ],
      ],
    );
  }
}
