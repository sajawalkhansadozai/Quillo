import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ingredient_item.dart';
import '../../models/pantry_item.dart';
import '../../services/analytics_service.dart';
import '../../services/pantry_service.dart';
import '../../services/scan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ingredient_visual_icon.dart';
import '../scan/receipt_preview_screen.dart';
import 'pantry_ui.dart';

/// Receipt → pantry: pick a photo, run the existing receipt OCR, then review.
/// Returns the number of items added, or null when cancelled.
Future<int?> startPantryReceiptScan(BuildContext context) =>
    _startPantryImageAdd(
      context,
      cameraTitle: 'Take a photo of the receipt',
      galleryTitle: 'Choose from gallery',
      sourceNote: 'Added from your receipt',
      purpose: ScanPurpose.pantryReceipt,
    );

/// Photo of ingredients — not a receipt, and it does not use a scan credit.
Future<int?> startPantryPhotoAdd(BuildContext context) =>
    _startPantryImageAdd(
      context,
      cameraTitle: 'Photograph your ingredients',
      galleryTitle: 'Choose a photo',
      sourceNote: 'Added from a photo',
      purpose: ScanPurpose.pantryFood,
    );

Future<int?> _startPantryImageAdd(
  BuildContext context, {
  required String cameraTitle,
  required String galleryTitle,
  required String sourceNote,
  required ScanPurpose purpose,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(cameraTitle),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(galleryTitle),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = source == ImageSource.camera
      ? await ScanService.pickFromCamera()
      : await ScanService.pickFromGallery();
  if (file == null || !context.mounted) return null;
  final prepared = await Navigator.of(context).push<XFile?>(
    MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(imageFile: file)),
  );
  if (prepared == null || !context.mounted) return null;
  return Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => PantryReceiptReviewScreen(
        imageFile: prepared,
        sourceNote: sourceNote,
        purpose: purpose,
      ),
    ),
  );
}

class _Draft {
  String name;
  double quantity;
  String unit;
  PantryLocation location;
  DateTime bestBefore;
  bool selected = true;

  _Draft({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.bestBefore,
  });

  String get amountLabel {
    final q = quantity == quantity.roundToDouble()
        ? quantity.round().toString()
        : quantity.toStringAsFixed(1);
    return unit.isEmpty ? q : '$q $unit';
  }

  factory _Draft.fromIngredient(IngredientItem i) {
    final location = PantryService.guessLocation(i.name);
    return _Draft(
      name: _titleCase(i.name),
      quantity: i.quantity ?? 1,
      unit: i.unit ?? '',
      location: location,
      bestBefore: PantryService.defaultBestBefore(location, i.name),
    );
  }

  static String _titleCase(String s) {
    final t = s.trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
}

/// Review your items — check receipt lines before adding them to the pantry.
class PantryReceiptReviewScreen extends StatefulWidget {
  final XFile imageFile;
  final String sourceNote;
  final ScanPurpose purpose;

  const PantryReceiptReviewScreen({
    super.key,
    required this.imageFile,
    this.sourceNote = 'Added from your receipt',
    this.purpose = ScanPurpose.pantryReceipt,
  });

  @override
  State<PantryReceiptReviewScreen> createState() =>
      _PantryReceiptReviewScreenState();
}

class _PantryReceiptReviewScreenState extends State<PantryReceiptReviewScreen> {
  static const _collapsedCount = 6;

  List<_Draft> _drafts = [];
  String? _store;
  String? _error;
  bool _scanning = true;
  bool _saving = false;
  bool _showAll = false;
  _Draft? _editing;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await ScanService.runScan(
        widget.imageFile,
        purpose: widget.purpose,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw const ScanException(
            'Scan is taking too long — please check your connection and try again.'),
      );
      if (widget.purpose == ScanPurpose.pantryReceipt) {
        await AnalyticsService.capture(AnalyticsService.scannedReceipt);
      }
      final store = result.meta?['store'] ?? result.meta?['merchant'];
      if (!mounted) return;
      setState(() {
        _store = store is String && store.trim().isNotEmpty ? store.trim() : null;
        _drafts = result.ingredients.map(_Draft.fromIngredient).toList();
        _scanning = false;
      });
    } on RateLimitException catch (e) {
      _fail(e.message);
    } on ScanException catch (e) {
      _fail('${e.message}\n\nThis scan did not use one of your credits.');
    } catch (_) {
      _fail(widget.purpose == ScanPurpose.pantryFood
          ? 'Could not read that photo. Please try again.'
          : 'Could not read your receipt. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _scanning = false;
    });
  }

  int get _selectedCount => _drafts.where((d) => d.selected).length;

  void _rescan() => Navigator.pop(context);

  void _viewReceipt() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InteractiveViewer(
          child: Image.file(File(widget.imageFile.path), fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _editDetails(_Draft d) async {
    final nameCtrl = TextEditingController(text: d.name);
    var location = d.location;
    var date = d.bestBefore;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item details', style: pantryH2),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Stored in', style: pantryCaps),
              const SizedBox(height: 8),
              PantrySegmented<PantryLocation>(
                options: [
                  for (final l in PantryLocation.values)
                    (label: l.label, value: l),
                ],
                selected: location,
                onSelect: (l) => setSheet(() {
                  location = l;
                  date = PantryService.defaultBestBefore(l, nameCtrl.text);
                }),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Best before'),
                subtitle: Text('est. ${pantryEstDate(date)}'),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 12),
              PantryPrimaryButton(
                label: 'Save',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true || !mounted) return;
    setState(() {
      if (name.isNotEmpty) d.name = name;
      d.location = location;
      d.bestBefore = date;
    });
  }

  Future<void> _addAll() async {
    final picked = _drafts.where((d) => d.selected).toList();
    if (picked.isEmpty) return;
    setState(() => _saving = true);
    final note = _store == null
        ? widget.sourceNote
        : widget.sourceNote.contains('receipt')
            ? 'Added from your $_store receipt'
            : widget.sourceNote;
    for (final d in picked) {
      await PantryService.addOrMerge(
        name: d.name,
        quantity: d.quantity,
        unit: d.unit,
        location: d.location,
        bestBefore: d.bestBefore,
        estimated: true,
        sourceNote: note,
      );
    }
    if (!mounted) return;
    Navigator.pop(context, picked.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                PantryHeader(
                  eyebrow: 'Receipt scan',
                  title: 'Review your items',
                  subtitle:
                      'Check the details before adding them to your pantry.',
                  trailing: TextButton(
                    onPressed: _rescan,
                    child: const Text(
                      'Rescan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  children: [
                    const SizedBox(height: 18),
                    Divider(color: Colors.white.withValues(alpha: 0.25)),
                    const SizedBox(height: 12),
                    _ReceiptRow(
                      store: _store ?? 'Your receipt',
                      count: _scanning ? null : _drafts.length,
                      onView: _viewReceipt,
                    ),
                  ],
                ),
                if (_scanning)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Reading your receipt…',
                          style: TextStyle(color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMedium),
                        ),
                        const SizedBox(height: 16),
                        PantryPrimaryButton(label: 'Try again', onPressed: _scan),
                      ],
                    ),
                  )
                else if (_drafts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'We couldn’t find any food on this receipt. Try a clearer photo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMedium),
                    ),
                  )
                else
                  _buildList(),
              ],
            ),
          ),
          if (!_scanning && _error == null && _drafts.isNotEmpty)
            _BottomBar(
              count: _selectedCount,
              saving: _saving,
              onAdd: _addAll,
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final visible = _showAll ? _drafts : _drafts.take(_collapsedCount).toList();
    final hiddenCount = _drafts.length - visible.length;
    final allSelected = _selectedCount == _drafts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _Check(
                  value: allSelected,
                  onTap: () => setState(() {
                    for (final d in _drafts) {
                      d.selected = !allSelected;
                    }
                  }),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select all',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_selectedCount of ${_drafts.length} selected',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final loc in PantryLocation.values)
            ..._group(loc, visible.where((d) => d.location == loc).toList()),
          if (hiddenCount > 0)
            InkWell(
              onTap: () => setState(() => _showAll = true),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC9C6EA)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Show $hiddenCount more ${hiddenCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PantryColors.indigo,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more_rounded,
                        color: PantryColors.indigo),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.textMedium),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Best-before dates are estimated from today’s purchase. Use the date on the pack when there is one.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _group(PantryLocation loc, List<_Draft> drafts) {
    if (drafts.isEmpty) return const [];
    final total = _drafts.where((d) => d.location == loc).length;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Text(loc.label.toUpperCase(), style: pantryCaps.copyWith(
              color: AppColors.textMedium,
            )),
            const Spacer(),
            Text(
              '$total ${total == 1 ? 'item' : 'items'}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: pantryCard(),
        child: Column(
          children: [
            for (var i = 0; i < drafts.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: PantryColors.border),
              _DraftRow(
                draft: drafts[i],
                editing: identical(_editing, drafts[i]),
                onToggle: () =>
                    setState(() => drafts[i].selected = !drafts[i].selected),
                onAmountTap: () => setState(() => _editing =
                    identical(_editing, drafts[i]) ? null : drafts[i]),
                onStep: (dir) => setState(() {
                  final d = drafts[i];
                  final step = PantryService.quantityStep(d.unit);
                  d.quantity = (d.quantity + dir * step).clamp(step, 9999.0);
                }),
                onDetails: () => _editDetails(drafts[i]),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }
}

class _ReceiptRow extends StatelessWidget {
  final String store;
  final int? count;
  final VoidCallback onView;

  const _ReceiptRow({
    required this.store,
    required this.count,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                count == null
                    ? 'Today · reading…'
                    : 'Today · $count ${count == 1 ? 'item' : 'items'} found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onView,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: const Text(
            'View receipt',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final bool value;
  final VoidCallback onTap;
  const _Check({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value ? AppColors.primary : const Color(0xFFC9C6EA),
            width: 1.5,
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  final _Draft draft;
  final bool editing;
  final VoidCallback onToggle;
  final VoidCallback onAmountTap;
  final ValueChanged<int> onStep;
  final VoidCallback onDetails;

  const _DraftRow({
    required this.draft,
    required this.editing,
    required this.onToggle,
    required this.onAmountTap,
    required this.onStep,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              _Check(value: draft.selected, onTap: onToggle),
              const SizedBox(width: 16),
              IngredientVisualIcon(ingredientName: draft.name, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'est. ${pantryEstDate(draft.bestBefore)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onAmountTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: editing ? AppColors.primaryLight : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: editing
                          ? AppColors.primary
                          : PantryColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        draft.amountLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: editing
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        editing
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: editing ? AppColors.primary : AppColors.textDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (editing) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 42),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PantryColors.bg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: PantryColors.border),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => onStep(-1),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Text(
                          draft.amountLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onStep(1),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onDetails,
                    child: const Text(
                      'All details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PantryColors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int count;
  final bool saving;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.count,
    required this.saving,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PantryColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PantryPrimaryButton(
            label: count == 0
                ? 'Select items to add'
                : 'Add $count ${count == 1 ? 'item' : 'items'} to pantry',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: count == 0 || saving ? null : onAdd,
          ),
          const SizedBox(height: 8),
          const Text(
            'You can change quantities and dates later.',
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}
