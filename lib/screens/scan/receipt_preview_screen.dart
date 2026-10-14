import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ad_banner.dart';

/// Preview after capture: brightness slider (default +20%) + Retake / Scan.
/// Pops with a prepared [XFile] on Scan, or `null` on Retake.
class ReceiptPreviewScreen extends StatefulWidget {
  final XFile imageFile;

  const ReceiptPreviewScreen({super.key, required this.imageFile});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  /// 1.0 = neutral, 1.2 = +20% (checklist default).
  double _brightness = 1.2;
  Uint8List? _previewBytes;
  bool _loadingPreview = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rebuildPreview();
  }

  Future<void> _rebuildPreview() async {
    setState(() => _loadingPreview = true);
    try {
      final raw = await widget.imageFile.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        _previewBytes = raw;
      } else {
        final adjusted = img.adjustColor(decoded, brightness: _brightness);
        _previewBytes = Uint8List.fromList(img.encodeJpg(adjusted, quality: 85));
      }
    } catch (_) {
      _previewBytes = await widget.imageFile.readAsBytes();
    }
    if (mounted) setState(() => _loadingPreview = false);
  }

  Future<void> _onScan() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final prepared = await applyBrightnessToFile(widget.imageFile, _brightness);
      if (!mounted) return;
      Navigator.of(context).pop(prepared);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare image. Try again.')),
        );
      }
    }
  }

  void _onRetake() => Navigator.of(context).pop<XFile?>(null);

  @override
  Widget build(BuildContext context) {
    return AdScaffold(
      backgroundColor: const Color(0xFF07070F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _submitting ? null : _onRetake,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  const Expanded(
                    child: Text(
                      'Adjust brightness',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.black,
                    child: _loadingPreview || _previewBytes == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : InteractiveViewer(
                            child: Image.memory(
                              _previewBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined,
                          color: Colors.white54, size: 18),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: 0.6,
                          max: 1.8,
                          divisions: 24,
                          activeColor: AppColors.primary,
                          inactiveColor: Colors.white24,
                          label: '${((_brightness - 1) * 100).round()}%',
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _brightness = v),
                          onChangeEnd: (_) => _rebuildPreview(),
                        ),
                      ),
                      const Icon(Icons.wb_sunny,
                          color: Colors.white70, size: 20),
                    ],
                  ),
                  Text(
                    _brightness >= 1.0
                        ? '+${((_brightness - 1) * 100).round()}% brightness'
                        : '${((_brightness - 1) * 100).round()}% brightness',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _onRetake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Retake',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _onScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Scan receipt',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apply brightness to JPEG bytes and write a temp file for the OCR pipeline.
Future<XFile> applyBrightnessToFile(XFile source, double brightness) async {
  final raw = await source.readAsBytes();
  if ((brightness - 1.0).abs() < 0.01) {
    return source;
  }
  final decoded = img.decodeImage(raw);
  if (decoded == null) return source;

  final adjusted = img.adjustColor(decoded, brightness: brightness);
  final out = Uint8List.fromList(img.encodeJpg(adjusted, quality: 90));

  final dir = await getTemporaryDirectory();
  final path = p.join(
    dir.path,
    'receipt_bright_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await File(path).writeAsBytes(out, flush: true);
  return XFile(path, mimeType: 'image/jpeg');
}
