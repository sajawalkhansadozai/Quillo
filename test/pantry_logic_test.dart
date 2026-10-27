import 'package:flutter_test/flutter_test.dart';
import 'package:quillo/models/pantry_item.dart';
import 'package:quillo/services/pantry_recipe_matcher.dart';
import 'package:quillo/utils/pantry_quantity.dart';
import 'package:quillo/utils/pantry_sync_decision.dart';

PantryItem _item(String name) => PantryItem(
      id: name,
      name: name,
      quantity: 1,
      unit: 'pcs',
      location: PantryLocation.pantry,
      categoryLabel: 'Pantry staples',
      addedAt: DateTime(2026),
    );

void main() {
  group('pantry sync', () {
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 2, 1);

    test('keeps a local edit that is newer than the cloud copy', () {
      expect(
        decidePantrySync(localUpdated: newer, remoteUpdated: older),
        PantrySyncAction.keepLocal,
      );
    });

    test('takes the cloud copy when it is newer', () {
      expect(
        decidePantrySync(localUpdated: older, remoteUpdated: newer),
        PantrySyncAction.takeRemote,
      );
    });

    test('does not resurrect a local edit that predates a cloud delete', () {
      expect(
        decidePantrySync(
          localUpdated: older,
          remoteUpdated: newer,
          remoteDeleted: newer,
        ),
        PantrySyncAction.deleteLocal,
      );
    });

    test('keeps a local edit made after the cloud delete', () {
      expect(
        decidePantrySync(
          localUpdated: newer,
          remoteUpdated: older,
          remoteDeleted: older,
        ),
        PantrySyncAction.keepLocal,
      );
    });
  });

  group('recipe amounts', () {
    test('subtracts grams from grams', () {
      expect(
        PantryQuantity.remaining(
          have: 500,
          haveUnit: 'g',
          use: 200,
          useUnit: 'g',
        ),
        300,
      );
    });

    test('converts kilograms and grams', () {
      expect(
        PantryQuantity.remaining(
          have: 1,
          haveUnit: 'kg',
          use: 250,
          useUnit: 'g',
        ),
        0.75,
      );
    });

    test('converts tablespoons into millilitres', () {
      expect(
        PantryQuantity.remaining(
          have: 100,
          haveUnit: 'ml',
          use: 2,
          useUnit: 'tbsp',
        ),
        70,
      );
    });

    test('returns zero when the item is used up', () {
      expect(
        PantryQuantity.remaining(
          have: 1,
          haveUnit: 'pcs',
          use: 2,
          useUnit: 'piece',
        ),
        0,
      );
    });

    test('refuses to compare oil in ml with a count', () {
      expect(
        PantryQuantity.remaining(
          have: 1,
          haveUnit: 'pcs',
          use: 15,
          useUnit: 'ml',
        ),
        isNull,
      );
    });
  });

  group('ingredient matching', () {
    final items = [_item('Olive oil'), _item('Red onion'), _item('Milk')];

    test('does not treat oil as olive oil', () {
      expect(PantryRecipeMatcher.matchIngredient('oil', items), isNull);
      expect(PantryRecipeMatcher.matchIngredient('olive oil', items)?.name,
          'Olive oil');
    });

    test('matches a more specific name to the staple', () {
      expect(PantryRecipeMatcher.matchIngredient('onion', items)?.name,
          'Red onion');
    });

    test('does not treat oat milk as milk', () {
      expect(
        PantryRecipeMatcher.matchIngredient('oat milk', [_item('Milk')]),
        isNull,
      );
    });
  });
}
