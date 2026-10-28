// ─────────────────────────────────────────────────────────────────────────────
// Smart pantry inventory item
// ─────────────────────────────────────────────────────────────────────────────

enum PantryLocation {
  fresh,
  fridge,
  pantry,
  freezer;

  String get label {
    switch (this) {
      case PantryLocation.fresh:
        return 'Fresh';
      case PantryLocation.fridge:
        return 'Fridge';
      case PantryLocation.pantry:
        return 'Pantry';
      case PantryLocation.freezer:
        return 'Freezer';
    }
  }

  String get sectionTitle {
    switch (this) {
      case PantryLocation.fresh:
        return 'Fresh produce';
      case PantryLocation.fridge:
        return 'Fridge';
      case PantryLocation.pantry:
        return 'Pantry staples';
      case PantryLocation.freezer:
        return 'Freezer';
    }
  }

  static PantryLocation fromId(String id) {
    return PantryLocation.values.firstWhere(
      (l) => l.name == id,
      orElse: () => PantryLocation.pantry,
    );
  }
}

enum FreshnessBand {
  fresh,
  useSoon,
  useFirst,
  expired;

  String get label {
    switch (this) {
      case FreshnessBand.fresh:
        return 'Fresh';
      case FreshnessBand.useSoon:
        return 'Use soon';
      case FreshnessBand.useFirst:
        return 'Use first';
      case FreshnessBand.expired:
        return 'Expired';
    }
  }
}

class PantryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final PantryLocation location;
  final String categoryLabel;
  final DateTime? bestBefore;
  final bool bestBeforeEstimated;
  final DateTime addedAt;
  final String? sourceNote;
  final String emoji;

  /// Receipt / scan that created or last restocked this row (checklist 1.6).
  final String? scanId;

  /// Normalised ingredient key used for dedupe (checklist 2.2 / 2.3).
  final String? ingredientKey;

  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.categoryLabel,
    this.bestBefore,
    this.bestBeforeEstimated = true,
    required this.addedAt,
    this.sourceNote,
    this.emoji = '🥬',
    this.scanId,
    this.ingredientKey,
  });

  int? get daysUntilExpiry {
    if (bestBefore == null) return null;
    final today = DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(bestBefore!.year, bestBefore!.month, bestBefore!.day);
    return b.difference(a).inDays;
  }

  FreshnessBand get freshness {
    final d = daysUntilExpiry;
    if (d == null) return FreshnessBand.fresh;
    if (d < 0) return FreshnessBand.expired;
    if (d <= 2) return FreshnessBand.useFirst;
    if (d <= 5) return FreshnessBand.useSoon;
    return FreshnessBand.fresh;
  }

  String get quantityLabel {
    final q = quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toStringAsFixed(quantity < 10 ? 1 : 0);
    return unit.isEmpty ? q : '$q $unit';
  }

  PantryItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    PantryLocation? location,
    String? categoryLabel,
    DateTime? bestBefore,
    bool? bestBeforeEstimated,
    DateTime? addedAt,
    String? sourceNote,
    String? emoji,
    String? scanId,
    String? ingredientKey,
    bool clearBestBefore = false,
    bool clearScanId = false,
  }) {
    return PantryItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      location: location ?? this.location,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      bestBefore: clearBestBefore ? null : (bestBefore ?? this.bestBefore),
      bestBeforeEstimated: bestBeforeEstimated ?? this.bestBeforeEstimated,
      addedAt: addedAt ?? this.addedAt,
      sourceNote: sourceNote ?? this.sourceNote,
      emoji: emoji ?? this.emoji,
      scanId: clearScanId ? null : (scanId ?? this.scanId),
      ingredientKey: ingredientKey ?? this.ingredientKey,
    );
  }

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
        unit: json['unit'] as String? ?? '',
        location: PantryLocation.fromId(json['location'] as String? ?? 'pantry'),
        categoryLabel: json['category_label'] as String? ?? 'Pantry staples',
        bestBefore: json['best_before'] != null
            ? DateTime.tryParse(json['best_before'] as String)
            : null,
        bestBeforeEstimated: json['best_before_estimated'] as bool? ?? true,
        addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ??
            DateTime.now(),
        sourceNote: json['source_note'] as String?,
        emoji: json['emoji'] as String? ?? '🥬',
        scanId: json['scan_id'] as String?,
        ingredientKey: json['ingredient_key'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'location': location.name,
        'category_label': categoryLabel,
        if (bestBefore != null) 'best_before': bestBefore!.toIso8601String(),
        'best_before_estimated': bestBeforeEstimated,
        'added_at': addedAt.toIso8601String(),
        if (sourceNote != null) 'source_note': sourceNote,
        'emoji': emoji,
        if (scanId != null) 'scan_id': scanId,
        if (ingredientKey != null) 'ingredient_key': ingredientKey,
      };
}
