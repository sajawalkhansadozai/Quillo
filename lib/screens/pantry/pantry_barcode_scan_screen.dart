import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/pantry_item.dart';
import '../../services/barcode_lookup_service.dart';
import '../../services/pantry_service.dart';
import '../../theme/app_theme.dart';
import 'pantry_ui.dart';

/// Scan a grocery barcode → Open Food Facts → confirm → pantry.
class PantryBarcodeScanScreen extends StatefulWidget {
  const PantryBarcodeScanScreen({super.key});

  @override
  State<PantryBarcodeScanScreen> createState() =>
      _PantryBarcodeScanScreenState();
}

class _PantryBarcodeScanScreenState extends State<PantryBarcodeScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  bool _handling = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .whereType<String>()
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;
    _handling = true;
    await _controller.stop();
    if (!mounted) return;
    setState(() => _status = 'Looking up $raw…');

    final product = await BarcodeLookupService.lookup(raw);
    if (!mounted) return;
    if (product == null) {
      setState(() => _status = 'No product found. Try again or add manually.');
      _handling = false;
      await _controller.start();
      return;
    }

    final item = await Navigator.of(context).push<PantryItem>(
      MaterialPageRoute(
        builder: (_) => _ConfirmBarcodePage(product: product),
      ),
    );
    if (!mounted) return;
    if (item != null) {
      Navigator.pop(context, item);
      return;
    }
    setState(() => _status = null);
    _handling = false;
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flash_on_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _status ??
                        'Point at a barcode on the pack. We’ll look up the product.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmBarcodePage extends StatefulWidget {
  final BarcodeProduct product;
  const _ConfirmBarcodePage({required this.product});

  @override
  State<_ConfirmBarcodePage> createState() => _ConfirmBarcodePageState();
}

class _ConfirmBarcodePageState extends State<_ConfirmBarcodePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late String _unit;
  late PantryLocation _location;
  DateTime? _bestBefore;
  bool _saving = false;

  static const _units = ['g', 'kg', 'ml', 'l', 'pack', 'pcs'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.name);
    _qtyCtrl = TextEditingController(
      text: p.quantity == p.quantity.roundToDouble()
          ? p.quantity.round().toString()
          : p.quantity.toStringAsFixed(1),
    );
    _unit = _units.contains(p.unit) ? p.unit : 'pack';
    _location = p.location;
    _bestBefore = PantryService.defaultBestBefore(_location, p.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (name.isEmpty || qty <= 0) return;
    setState(() => _saving = true);
    final item = await PantryService.addOrMerge(
      name: name,
      quantity: qty,
      unit: _unit,
      location: _location,
      bestBefore: _bestBefore,
      estimated: true,
      sourceNote: 'Scanned barcode ${widget.product.barcode}',
    );
    if (!mounted) return;
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: PantryColors.bg,
      appBar: AppBar(
        backgroundColor: PantryColors.bg,
        elevation: 0,
        title: const Text(
          'Confirm item',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            fontFamily: 'Nunito',
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (p.brand != null && p.brand!.isNotEmpty)
            Text(
              p.brand!,
              style: const TextStyle(color: AppColors.textMedium),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? 'pack'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Stored in',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PantryLocation.values.map((loc) {
              final selected = _location == loc;
              return ChoiceChip(
                label: Text(loc.label),
                selected: selected,
                onSelected: (_) => setState(() {
                  _location = loc;
                  _bestBefore =
                      PantryService.defaultBestBefore(loc, _nameCtrl.text);
                }),
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textDark,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          PantryPrimaryButton(
            label: 'Add to pantry',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
