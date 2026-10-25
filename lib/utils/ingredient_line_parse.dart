/// Splits a free-text ingredient amount into quantity + optional prep note.
///
/// Examples:
/// - `2 cloves, peeled and minced` → amount `2 cloves`, note `Peeled and minced`
/// - `1 tbsp (or soy sauce)` → amount `1 tbsp`, note `Or soy sauce`
/// - `½ cup` → amount `½ cup`, note ``
class IngredientLineParse {
  IngredientLineParse._();

  static ({String amount, String note}) splitAmountAndNote(
    String raw, {
    String? explicitNote,
  }) {
    final noteFromField = (explicitNote ?? '').trim();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return (amount: '', note: _capitalize(noteFromField));
    }

    // Explicit note from API wins; still clean amount of trailing paren/comma dupes.
    if (noteFromField.isNotEmpty) {
      return (
        amount: _stripTrailingNote(trimmed),
        note: _capitalize(noteFromField),
      );
    }

    final paren = RegExp(r'^(.+?)\s*\(([^)]+)\)\s*$').firstMatch(trimmed);
    if (paren != null) {
      final left = paren.group(1)!.trim();
      final right = paren.group(2)!.trim();
      if (left.isNotEmpty && right.isNotEmpty) {
        return (amount: left, note: _capitalize(right));
      }
    }

    final commaIdx = trimmed.indexOf(',');
    if (commaIdx > 0) {
      final left = trimmed.substring(0, commaIdx).trim();
      final right = trimmed.substring(commaIdx + 1).trim();
      if (right.isNotEmpty && RegExp(r'\d|½|¼|¾|⅓|⅔').hasMatch(left)) {
        return (amount: left, note: _capitalize(right));
      }
    }

    return (amount: trimmed, note: '');
  }

  static String _stripTrailingNote(String amount) {
    return amount
        .replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceFirst(RegExp(r',\s*[^,]+$'), '')
        .trim();
  }

  static String _capitalize(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    return '${t[0].toUpperCase()}${t.substring(1)}';
  }
}
