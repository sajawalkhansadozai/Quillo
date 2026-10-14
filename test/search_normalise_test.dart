import 'package:flutter_test/flutter_test.dart';
import 'package:quillo/services/local_db_service.dart';

void main() {
  group('search term normalisation', () {
    test('lowercases, trims, strips punctuation', () {
      expect(LocalDbService.normalizeSearchTerm('  Chicken! '), 'chicken');
      expect(LocalDbService.normalizeSearchTerm('STEAK'), 'steak');
      expect(LocalDbService.normalizeSearchTerm('spag-hetti'), 'spaghetti');
      expect(LocalDbService.normalizeSearchTerm('spring   onion'), 'spring onion');
    });
  });
}
