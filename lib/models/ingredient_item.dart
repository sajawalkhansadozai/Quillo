// ─────────────────────────────────────────────────────────────────────────────
// IngredientItem — represents a single ingredient returned by the OCR pipeline
// ─────────────────────────────────────────────────────────────────────────────

class IngredientItem {
  String name;
  double? quantity;
  String? unit;

  IngredientItem({
    required this.name,
    this.quantity,
    this.unit,
  });

  factory IngredientItem.fromJson(Map<String, dynamic> json) {
    return IngredientItem(
      name: (json['name'] as String? ?? '').trim(),
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (quantity != null) 'quantity': quantity,
        if (unit != null) 'unit': unit,
      };

  String get displayAmount {
    if (quantity == null) return '';
    final q = quantity! % 1 == 0 ? quantity!.toInt().toString() : quantity!.toString();
    return unit != null ? '$q $unit' : q;
  }

  IngredientItem copyWith({String? name, double? quantity, String? unit}) {
    return IngredientItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}
