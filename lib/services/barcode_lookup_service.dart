import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pantry_item.dart';
import 'pantry_service.dart';

/// Product info resolved from a grocery barcode (Open Food Facts).
class BarcodeProduct {
  final String barcode;
  final String name;
  final String? quantityLabel;
  final String? brand;
  final String? imageUrl;

  const BarcodeProduct({
    required this.barcode,
    required this.name,
    this.quantityLabel,
    this.brand,
    this.imageUrl,
  });

  double get quantity {
    final q = quantityLabel;
    if (q == null) return 1;
    final m = RegExp(r'([\d.,]+)').firstMatch(q);
    if (m == null) return 1;
    return double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 1;
  }

  String get unit {
    final q = (quantityLabel ?? '').toLowerCase();
    for (final u in ['kg', 'g', 'ml', 'l', 'cl', 'oz', 'lb']) {
      if (q.contains(u)) return u == 'cl' ? 'ml' : u;
    }
    return 'pack';
  }

  PantryLocation get location => PantryService.guessLocation(name);
}

/// Looks up packaged food barcodes via Open Food Facts (no API key).
class BarcodeLookupService {
  BarcodeLookupService._();

  static const _ua = 'Quillo/1.0 (https://quilloai.co.uk; pantry barcode)';

  static Future<BarcodeProduct?> lookup(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json'
      '?fields=product_name,generic_name,brands,quantity,image_front_small_url,'
      'product_name_en',
    );
    try {
      final res = await http.get(uri, headers: {'User-Agent': _ua});
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;
      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      final name = (product['product_name'] as String?)?.trim().isNotEmpty == true
          ? (product['product_name'] as String).trim()
          : (product['product_name_en'] as String?)?.trim().isNotEmpty == true
              ? (product['product_name_en'] as String).trim()
              : (product['generic_name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      return BarcodeProduct(
        barcode: code,
        name: name,
        quantityLabel: (product['quantity'] as String?)?.trim(),
        brand: (product['brands'] as String?)?.trim(),
        imageUrl: (product['image_front_small_url'] as String?)?.trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
