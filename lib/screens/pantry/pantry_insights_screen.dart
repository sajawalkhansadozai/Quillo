import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../../services/food_waste_service.dart';
import '../../services/pantry_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ingredient_visual_icon.dart';
import 'expiry_centre_screen.dart';
import 'pantry_ui.dart';

enum _Period { week, month, year }

/// Pantry insights — what was used, what's left, and what to restock.
class PantryInsightsScreen extends StatefulWidget {
  const PantryInsightsScreen({super.key});

  @override
  State<PantryInsightsScreen> createState() => _PantryInsightsScreenState();
}

class _PantryInsightsScreenState extends State<PantryInsightsScreen> {
  static const _groupColors = {
    PantryLocation.fresh: Color(0xFF2B2482),
    PantryLocation.fridge: Color(0xFF5B4FF0),
    PantryLocation.pantry: Color(0xFF9C95F5),
    PantryLocation.freezer: Color(0xFFD4D0FA),
  };

  List<PantryItem> _items = [];
  List<PantryUseEntry> _used = [];
  Set<String> _dismissed = {};
  final Set<String> _added = {};
  bool _loading = true;
  _Period _period = _Period.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await PantryService.getAll();
    final used = await PantryService.usedLog();
    final dismissed = await PantryService.dismissedRestock();
    if (!mounted) return;
    setState(() {
      _items = items;
      _used = used;
      _dismissed = dismissed;
      _loading = false;
    });
  }

  DateTime get _periodStart {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        final today = DateTime(now.year, now.month, now.day);
        return today.subtract(Duration(days: today.weekday - 1));
      case _Period.month:
        return DateTime(now.year, now.month);
      case _Period.year:
        return DateTime(now.year);
    }
  }

  String get _periodLabel => switch (_period) {
        _Period.week => 'this week',
        _Period.month => 'this month',
        _Period.year => 'this year',
      };

  /// Restock ideas: things you used recently that aren't in the pantry now.
  List<({PantryUseEntry entry, int times})> get _restock {
    final since = DateTime.now().subtract(const Duration(days: 60));
    final have = _items.map((i) => i.name.toLowerCase()).toSet();
    final byName = <String, List<PantryUseEntry>>{};
    for (final u in _used.where((u) => u.usedAt.isAfter(since))) {
      final key = u.name.toLowerCase();
      if (have.contains(key) || _dismissed.contains(key)) continue;
      byName.putIfAbsent(key, () => []).add(u);
    }
    final list = byName.values
        .map((l) => (entry: l.last, times: l.length))
        .toList()
      ..sort((a, b) {
        final t = b.times.compareTo(a.times);
        return t != 0 ? t : b.entry.usedAt.compareTo(a.entry.usedAt);
      });
    return list.take(3).toList();
  }

  String _restockReason(({PantryUseEntry entry, int times}) r) {
    if (r.times >= 3) return 'A regular, used ${r.times} times lately';
    if (r.times == 2) return 'Used twice in the last two months';
    return 'Used up on ${pantryShortDate(r.entry.usedAt)}';
  }

  Future<void> _addRestock(PantryUseEntry e) async {
    await PantryService.addToShoppingList([(name: e.name, amount: '')]);
    if (!mounted) return;
    setState(() => _added.add(e.name.toLowerCase()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${e.name} added to Pantry restock'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _dismiss(PantryUseEntry e) async {
    await PantryService.dismissRestock(e.name);
    if (mounted) setState(() => _dismissed.add(e.name.toLowerCase()));
  }

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('How is this worked out?'),
        content: Text(
          'Each item you mark as used on or before its best-before date counts '
          'as rescued. We value a rescued item at about '
          '£${FoodWasteService.avgItemValueGbp.toStringAsFixed(2)}, '
          'a typical UK grocery item. It’s an estimate, not your receipt total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: PantryColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final start = _periodStart;
    final used = _used.where((u) => !u.usedAt.isBefore(start)).toList();
    final rescued = used.where((u) => u.rescued).length;
    final saved = FoodWasteService.estimateMoneySaved(rescued);
    final notUsed = _items.length;
    final usedPct = used.isEmpty && notUsed == 0
        ? 0
        : (used.length * 100 / (used.length + notUsed)).round();
    final useThisWeek =
        _items.where((i) => (i.daysUntilExpiry ?? 999) <= 7).length;
    final counts = PantryService.countsByLocation(_items);
    final restock = _restock;

    return Scaffold(
      backgroundColor: PantryColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PantryHeader(
            eyebrow: 'Pantry insights · $_periodLabel',
            title: '£${saved.toStringAsFixed(2)}',
            subtitle: 'saved by using food before it expired',
            children: [
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _explain,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.white.withValues(alpha: 0.75)),
                    const SizedBox(width: 8),
                    Text(
                      'Estimated. How is this worked out?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _HeaderStat(value: '$rescued', label: 'items rescued'),
                    _divider(),
                    _HeaderStat(value: '${used.length}', label: 'items used'),
                    _divider(),
                    _HeaderStat(value: '$usedPct%', label: 'pantry used'),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PantrySegmented<_Period>(
                  options: const [
                    (label: 'Week', value: _Period.week),
                    (label: 'Month', value: _Period.month),
                    (label: 'Year', value: _Period.year),
                  ],
                  selected: _period,
                  onSelect: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 28),
                const Text('How much did you use?', style: pantryH2),
                const SizedBox(height: 4),
                Text(
                  used.isEmpty
                      ? 'Counts items you mark as used — they start at zero and stay on this phone.'
                      : 'Of everything in your pantry $_periodLabel.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: 14),
                _UsageCard(
                  usedPct: usedPct,
                  useThisWeek: useThisWeek,
                  onUseThisWeek: () => Navigator.of(context)
                      .push(MaterialPageRoute(
                        builder: (_) => const ExpiryCentreScreen(),
                      ))
                      .then((_) => _load()),
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text('What’s in your pantry?', style: pantryH2),
                  const SizedBox(height: 4),
                  Text(
                    _biggestGroupLine(counts),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GroupsCard(counts: counts, colors: _groupColors),
                ],
                if (restock.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text('Running low soon', style: pantryH2),
                  const SizedBox(height: 4),
                  const Text(
                    'Smart restock suggestions, based on what you use.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: pantryCard(),
                    child: Column(
                      children: [
                        for (var i = 0; i < restock.length; i++) ...[
                          if (i > 0)
                            const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: PantryColors.border),
                          _RestockRow(
                            entry: restock[i].entry,
                            reason: _restockReason(restock[i]),
                            added: _added
                                .contains(restock[i].entry.name.toLowerCase()),
                            onAdd: () => _addRestock(restock[i].entry),
                            onDismiss: () => _dismiss(restock[i].entry),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Small choices. Less waste. More great meals.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => VerticalDivider(
        width: 24,
        color: Colors.white.withValues(alpha: 0.25),
      );

  String _biggestGroupLine(Map<PantryLocation, int> counts) {
    final total = _items.length;
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return '${top.key.sectionTitle} is your biggest group: '
        '${top.value} of $total items.';
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final int usedPct;
  final int useThisWeek;
  final VoidCallback onUseThisWeek;

  const _UsageCard({
    required this.usedPct,
    required this.useThisWeek,
    required this.onUseThisWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: pantryCard(),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                if (usedPct > 0)
                  Expanded(
                    flex: usedPct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4FF0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (usedPct > 0 && usedPct < 100) const SizedBox(width: 4),
                if (usedPct < 100)
                  Expanded(
                    flex: 100 - usedPct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PctLabel(pct: usedPct, label: 'used'),
              const Spacer(),
              _PctLabel(pct: 100 - usedPct, label: 'not used yet'),
            ],
          ),
          if (useThisWeek > 0) ...[
            const Divider(height: 28, color: PantryColors.border),
            InkWell(
              onTap: onUseThisWeek,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$useThisWeek ${useThisWeek == 1 ? 'item' : 'items'} to use this week',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: PantryColors.indigo,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: PantryColors.indigo),
                  ],
                ),
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PctLabel extends StatelessWidget {
  final int pct;
  final String label;
  const _PctLabel({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '$pct%',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
        TextSpan(
          text: '  $label',
          style: const TextStyle(fontSize: 15, color: AppColors.textMedium),
        ),
      ]),
    );
  }
}

class _GroupsCard extends StatelessWidget {
  final Map<PantryLocation, int> counts;
  final Map<PantryLocation, Color> colors;

  const _GroupsCard({required this.counts, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: pantryCard(),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                for (final l in PantryLocation.values)
                  if ((counts[l] ?? 0) > 0)
                    Expanded(
                      flex: counts[l]!,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: colors[l],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < PantryLocation.values.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: PantryColors.border),
            Builder(builder: (_) {
              final l = PantryLocation.values[i];
              final n = counts[l] ?? 0;
              final pct = total == 0 ? 0 : (n * 100 / total).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colors[l],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.sectionTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '$pct%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _RestockRow extends StatelessWidget {
  final PantryUseEntry entry;
  final String reason;
  final bool added;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _RestockRow({
    required this.entry,
    required this.reason,
    required this.added,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
      child: Row(
        children: [
          IngredientVisualIcon(ingredientName: entry.name, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: added ? null : onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: PantryColors.indigo,
              disabledBackgroundColor: PantryColors.greenBg,
              disabledForegroundColor: PantryColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: Icon(added ? Icons.check_rounded : Icons.add_rounded,
                size: 18),
            label: Text(
              added ? 'Added' : 'Add',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}
