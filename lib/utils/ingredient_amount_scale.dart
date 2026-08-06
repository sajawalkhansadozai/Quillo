/// Scale human-readable ingredient amount strings for serving adjustments.
class IngredientAmountScale {
  IngredientAmountScale._();

  static final _nonScalable = RegExp(
    r'\b(to taste|as needed|optional|a pinch|pinch|dash|some|for garnish)\b',
    caseSensitive: false,
  );

  static final _quantityPattern = RegExp(
    r'^((?:\d+\s+)?\d+(?:\.\d+)?(?:\s*/\s*\d+)?)\s*(.*)$',
  );

  /// Returns [amount] scaled by [factor] (e.g. 2.0 doubles "1/2 cup" → "1 cup").
  static String scale(String amount, double factor) {
    final trimmed = amount.trim();
    if (trimmed.isEmpty || (factor - 1).abs() < 0.0001) return amount;
    if (factor <= 0) return amount;
    if (_nonScalable.hasMatch(trimmed)) return amount;

    final match = _quantityPattern.firstMatch(trimmed);
    if (match == null) return amount;

    final value = _parseQuantity(match.group(1)!.trim());
    if (value == null || value <= 0) return amount;

    final scaled = value * factor;
    if (scaled <= 0) return amount;

    final rest = match.group(2)?.trim() ?? '';
    final formatted = _formatQuantity(scaled);
    return rest.isEmpty ? formatted : '$formatted $rest';
  }

  static double? _parseQuantity(String raw) {
    final mixed = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$').firstMatch(raw);
    if (mixed != null) {
      final whole = double.tryParse(mixed.group(1)!);
      final num = double.tryParse(mixed.group(2)!);
      final den = double.tryParse(mixed.group(3)!);
      if (whole == null || num == null || den == null || den == 0) return null;
      return whole + num / den;
    }

    final fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$').firstMatch(raw);
    if (fraction != null) {
      final num = double.tryParse(fraction.group(1)!);
      final den = double.tryParse(fraction.group(2)!);
      if (num == null || den == null || den == 0) return null;
      return num / den;
    }

    return double.tryParse(raw.replaceAll(' ', ''));
  }

  static String _formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < 0.05) {
      return value.round().toString();
    }

    const fractions = <(double, String)>[
      (0.125, '1/8'),
      (0.25, '1/4'),
      (0.333, '1/3'),
      (0.375, '3/8'),
      (0.5, '1/2'),
      (0.625, '5/8'),
      (0.667, '2/3'),
      (0.75, '3/4'),
      (0.875, '7/8'),
    ];

    final whole = value.floor();
    final frac = value - whole;

    for (final (threshold, label) in fractions) {
      if ((frac - threshold).abs() < 0.06) {
        if (whole == 0) return label;
        return '$whole $label';
      }
    }

    final rounded = (value * 10).roundToDouble() / 10;
    if ((rounded - rounded.roundToDouble()).abs() < 0.05) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
}
