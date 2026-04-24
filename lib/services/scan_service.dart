import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ingredient_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

class RateLimitException implements Exception {
  final String message;
  const RateLimitException(this.message);
  @override
  String toString() => message;
}

class ScanException implements Exception {
  final String message;
  const ScanException(this.message);
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanResult
// ─────────────────────────────────────────────────────────────────────────────

class ScanResult {
  final String scanId;
  final List<IngredientItem> ingredients;

  const ScanResult({required this.scanId, required this.ingredients});
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanService
// ─────────────────────────────────────────────────────────────────────────────

class ScanService {
  static final _client = Supabase.instance.client;
  static final _picker = ImagePicker();

  // ── Image picking ───────────────────────────────────────────────────────────

  static Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 3200,
    );
  }

  static Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
  }

  // ── Full scan pipeline: compress → upload → OCR ─────────────────────────────

  static Future<ScanResult> runScan(XFile imageFile) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const ScanException('You must be signed in to scan.');

    // 1. Compress image to under 800 KB
    final compressedBytes = await _compressImage(imageFile);
    if (compressedBytes == null || compressedBytes.isEmpty) {
      throw const ScanException('Could not process the image. Please try again.');
    }

    // 2. Upload to Supabase Storage
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '${user.id}/$timestamp.jpg';

    try {
      await _client.storage.from('receipt-images').uploadBinary(
            storagePath,
            compressedBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } on StorageException catch (e) {
      throw ScanException('Upload failed: ${e.message}');
    }

    // 3. Create scan record in DB
    final Map<String, dynamic> scanRow;
    try {
      scanRow = await _client.from('scans').insert({
        'user_id': user.id,
        'image_url': storagePath,
        'status': 'processing',
      }).select().single();
    } catch (e) {
      throw const ScanException('Failed to create scan record. Please try again.');
    }
    final scanId = scanRow['id'] as String;

    // 4. Get a signed URL for the Edge Function (valid 5 minutes)
    final String signedUrl;
    try {
      signedUrl = await _client.storage
          .from('receipt-images')
          .createSignedUrl(storagePath, 300);
    } on StorageException catch (e) {
      throw ScanException('Could not access image: ${e.message}');
    }

    // 5. Call ocr-scan Edge Function
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'ocr-scan',
        body: {
          'image_url': signedUrl,
          'scan_id': scanId,
          'user_id': user.id,
        },
      );
    } catch (e) {
      await _markScanFailed(scanId);
      throw const ScanException(
          'Could not read your receipt — please try again in better lighting.');
    }

    // 6. Handle errors from Edge Function
    if (response.status == 429) {
      throw const RateLimitException(
          'You have reached your daily scan limit. Upgrade to Premium for more scans.');
    }
    if (response.status != 200) {
      await _markScanFailed(scanId);
      final errorData = response.data as Map<String, dynamic>?;
      final msg = errorData?['error'] as String? ??
          'Could not read your receipt — please try again in better lighting.';
      throw ScanException(msg);
    }

    // 7. Parse ingredient list
    final data = response.data as Map<String, dynamic>;
    final rawList = data['ingredients'] as List<dynamic>? ?? [];
    final ingredients = rawList
        .map((i) => IngredientItem.fromJson(i as Map<String, dynamic>))
        .where((i) => i.name.trim().isNotEmpty)
        .toList();

    return ScanResult(scanId: scanId, ingredients: ingredients);
  }

  // ── Compression ─────────────────────────────────────────────────────────────

  static Future<Uint8List?> _compressImage(XFile file) async {
    final bytes = await file.readAsBytes();
    // If already under 800KB, return as-is
    if (bytes.length < 800 * 1024) return bytes;

    // Try compressing with decreasing quality until under 800KB
    for (final quality in [80, 65, 50]) {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.length < 800 * 1024) return compressed;
    }
    // Return best effort (50% quality)
    return FlutterImageCompress.compressWithList(
      bytes,
      quality: 50,
      format: CompressFormat.jpeg,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Future<void> _markScanFailed(String scanId) async {
    try {
      await _client.from('scans').update({'status': 'failed'}).eq('id', scanId);
    } catch (_) {}
  }
}
