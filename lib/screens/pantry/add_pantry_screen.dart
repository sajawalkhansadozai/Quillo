import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../../services/pantry_service.dart';
import '../../theme/app_theme.dart';
import 'pantry_barcode_scan_screen.dart';
import 'pantry_receipt_review_screen.dart';
import 'pantry_ui.dart';

/// A batch of items that came in from one receipt.
class _Import {
  final String title;
  final DateTime date;
  final List<PantryItem> items;
  const _Import(this.title, this.date, this.items);
}

/// Add to pantry — chooser + manual entry + receipt import.
class AddPantryScreen extends StatefulWidget {
  const AddPantryScreen({super.key});

  @override
  State<AddPantryScreen> createState() => _AddPantryScreenState();
}

class _AddPantryScreenState extends State<AddPantryScreen> {
  static final _receiptNote = RegExp(r'^Added from your (.+) receipt$');

  List<_Import> _imports = [];
  bool _showAllImports = false;

  @override
  void initState() {
    super.initState();
    _loadImports();
  }

  Future<void> _loadImports() async {
    final items = await PantryService.getAll();
    final groups = <String, _Import>{};
    for (final i in items) {
      final note = i.sourceNote;
      if (note == null || !note.contains('receipt')) continue;
      final store = _receiptNote.firstMatch(note)?.group(1) ?? 'Receipt';
      final day = DateTime(i.addedAt.year, i.addedAt.month, i.addedAt.day);
      final key = '$store|$day';
      groups.putIfAbsent(key, () => _Import(store, day, [])).items.add(i);
    }
    final list = groups.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _imports = list);
  }

  String _when(DateTime d) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(d).inDays;
    if (diff == 0) return 'Today · receipt';
    if (diff == 1) return 'Yesterday · receipt';
    return '${pantryShortDate(d)} · receipt';
  }

  Future<void> _scanReceipt() async {
    final added = await startPantryReceiptScan(context);
    if (!mounted || added == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$added ${added == 1 ? 'item' : 'items'} added to your pantry'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _scanBarcode() async {
    final item = await Navigator.of(context).push<PantryItem>(
      MaterialPageRoute(builder: (_) => const PantryBarcodeScanScreen()),
    );
    if (item != null && mounted) Navigator.pop(context, item);
  }

  Future<void> _photoAdd() async {
    final added = await startPantryPhotoAdd(context);
    if (!mounted || added == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$added ${added == 1 ? 'item' : 'items'} added to your pantry'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _addManually() async {
    final item = await Navigator.of(context).push<PantryItem>(
      MaterialPageRoute(builder: (_) => const _ManualAddPantryPage()),
    );
    if (item != null && mounted) Navigator.pop(context, item);
  }

  void _showImport(_Import imp) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            Text(imp.title, style: pantryH2),
            Text(
              '${_when(imp.date)} · ${imp.items.length} items added',
              style: const TextStyle(color: AppColors.textMedium),
            ),
            const SizedBox(height: 12),
            for (final i in imp.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PantryEmojiTile(item: i, size: 40),
                title: Text(
                  i.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${i.quantityLabel} · ${i.location.label}'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imports = _showAllImports ? _imports : _imports.take(3).toList();
    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PantryHeader(
            eyebrow: 'Smart pantry',
            title: 'Add to pantry',
            subtitle: 'Choose the quickest way to add ingredients.',
            children: [
              const SizedBox(height: 24),
              _BarcodeCard(onTap: _scanBarcode),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Or add another way', style: pantryH2),
                const SizedBox(height: 14),
                Container(
                  decoration: pantryCard(),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _AltRow(
                        color: PantryColors.greenBg,
                        icon: Icons.photo_camera_outlined,
                        iconColor: PantryColors.green,
                        title: 'Take a photo',
                        subtitle: 'Fresh food with no barcode',
                        onTap: _photoAdd,
                      ),
                      const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: PantryColors.border),
                      _AltRow(
                        color: PantryColors.amberBg,
                        icon: Icons.edit_outlined,
                        iconColor: PantryColors.amber,
                        title: 'Add manually',
                        subtitle: 'Type in name, amount and date',
                        onTap: _addManually,
                      ),
                      const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: PantryColors.border),
                      _AltRow(
                        color: AppColors.primaryLight,
                        icon: Icons.receipt_long_outlined,
                        iconColor: PantryColors.indigo,
                        title: 'Scan a receipt',
                        subtitle: 'Add a whole shop at once',
                        onTap: _scanReceipt,
                      ),
                    ],
                  ),
                ),
                if (_imports.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Recent imports', style: pantryH2),
                      ),
                      if (_imports.length > 3)
                        TextButton(
                          onPressed: () => setState(
                              () => _showAllImports = !_showAllImports),
                          child: Text(
                            _showAllImports ? 'Show less' : 'See all',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: PantryColors.indigo,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < imports.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: PantryColors.border),
                    InkWell(
                      onTap: () => _showImport(imports[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    imports[i].title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    _when(imports[i].date),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${imports[i].items.length} items added',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 28),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_outlined,
                        size: 18, color: PantryColors.indigo),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Smart organising does the rest. ',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            TextSpan(
                              text:
                                  'Quillo sorts every item by category, location and expected freshness. You can change any of it later.',
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BarcodeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF7B83FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Fastest',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Packaged food',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 190,
                  height: 92,
                  child: CustomPaint(painter: _CornerPainter()),
                ),
                const Icon(Icons.view_week_rounded,
                    size: 72, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Scan a barcode',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Point your camera at the barcode. We fill in the name, size and a best-before estimate.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text(
                'Start scanning',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four viewfinder corners around the barcode illustration.
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 18.0;
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0)
        ..moveTo(w - l, 0)
        ..lineTo(w, 0)
        ..lineTo(w, l)
        ..moveTo(w, h - l)
        ..lineTo(w, h)
        ..lineTo(w - l, h)
        ..moveTo(l, h)
        ..lineTo(0, h)
        ..lineTo(0, h - l),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AltRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AltRow({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMedium),
          ],
        ),
      ),
    );
  }
}

class _ManualAddPantryPage extends StatefulWidget {
  const _ManualAddPantryPage();

  @override
  State<_ManualAddPantryPage> createState() => _ManualAddPantryPageState();
}

class _ManualAddPantryPageState extends State<_ManualAddPantryPage> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _unit = 'pack';
  PantryLocation _location = PantryLocation.fridge;
  DateTime? _bestBefore;
  bool _saving = false;

  static const _units = ['g', 'kg', 'ml', 'l', 'pack', 'bunch', 'pcs'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _bestBefore ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _bestBefore = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (name.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and quantity')),
      );
      return;
    }
    setState(() => _saving = true);
    final item = await PantryService.addManual(
      name: name,
      quantity: qty,
      unit: _unit,
      location: _location,
      bestBefore: _bestBefore,
      estimated: _bestBefore == null,
    );
    if (!mounted) return;
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PantryColors.bg,
      appBar: AppBar(
        backgroundColor: PantryColors.bg,
        elevation: 0,
        title: const Text(
          'Add manually',
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
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Baby spinach',
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
          const Text(
            'Stored in',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PantryLocation.values.map((loc) {
              final selected = _location == loc;
              return ChoiceChip(
                label: Text(loc.label),
                selected: selected,
                onSelected: (_) => setState(() => _location = loc),
                selectedColor: AppColors.primaryLight,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textDark,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Best before',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _bestBefore == null
                  ? 'We’ll estimate from location'
                  : '${_bestBefore!.day}/${_bestBefore!.month}/${_bestBefore!.year}',
            ),
            trailing: TextButton(
              onPressed: _pickDate,
              child: const Text('Edit'),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Add to pantry',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
