import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/food_waste_service.dart';
import '../../services/in_app_notification_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../Home/scan_screen.dart';
import '../paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FoodWasteDashboardScreen — redesigned to match impact mockup
// ─────────────────────────────────────────────────────────────────────────────

class FoodWasteDashboardScreen extends StatefulWidget {
  const FoodWasteDashboardScreen({super.key});

  @override
  State<FoodWasteDashboardScreen> createState() =>
      _FoodWasteDashboardScreenState();
}

class _FoodWasteDashboardScreenState extends State<FoodWasteDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFF3F4F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B6B8A);
  static const _blue = Color(0xFF3D5AFE);
  static const _green = Color(0xFF2E7D32);
  static const _goldLine = Color(0xFFC9A66B);
  static const _brown = Color(0xFF8D6E63);
  static const _cardBorder = Color(0xFFE6E8F0);

  WasteStats _stats = const WasteStats();
  bool _isPremium = false;
  bool _loading = true;
  bool _weeks8 = true;
  int? _pulseThreshold;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  int? _highestUnlockedThreshold(WasteStats stats) {
    const map = {
      '£100 reached': 100,
      '£500 reached': 500,
      '£1,000 reached': 1000,
    };
    int? highest;
    for (final m in stats.milestones) {
      if (!m.unlocked) continue;
      final t = map[m.label];
      if (t != null && (highest == null || t > highest)) highest = t;
    }
    return highest;
  }

  Future<void> _load() async {
    final prem = await SubscriptionService.isPremium();
    final stats = await FoodWasteService.loadStats();
    final seen = await InAppNotificationService.lastMilestoneSeen();
    final highest = _highestUnlockedThreshold(stats);
    int? pulse;
    if (highest != null && highest > seen) {
      pulse = highest;
      await InAppNotificationService.markMilestoneSeen(highest);
    }
    if (!mounted) return;
    setState(() {
      _isPremium = prem;
      _stats = stats;
      _pulseThreshold = pulse;
      _loading = false;
    });
  }

  Future<void> _shareStats() async {
    final money = _stats.moneySavedGbp.toStringAsFixed(0);
    final kg = _stats.kgAvoided.toStringAsFixed(0);
    final text =
        "I've saved £$money and avoided ${kg}kg of food waste with Quillo. "
        '${_stats.weekStreak} week streak · ${_stats.totalScans} scans';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stats copied — paste to share'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const PaywallScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        fullscreenDialog: true,
      ),
    );
    await _load();
  }

  void _startScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  List<WeeklySaving> get _visibleWeeks {
    final all = _stats.weeklySavings;
    if (all.isEmpty) return all;
    final n = _weeks8 ? 8 : 4;
    if (all.length <= n) return all;
    return all.sublist(all.length - n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            _isPremium
                                ? [
                                    _buildHero(),
                                    const SizedBox(height: 14),
                                    _buildNextMilestone(),
                                    const SizedBox(height: 14),
                                    _buildWeeklySavings(),
                                    const SizedBox(height: 14),
                                    _buildUkAverage(),
                                    const SizedBox(height: 14),
                                    _buildBottomStats(),
                                    const SizedBox(height: 20),
                                    const Center(
                                      child: Text(
                                        'Small changes. A bigger tomorrow.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Center(
                                      child: TextButton(
                                        onPressed: _shareStats,
                                        child: const Text('Share my impact'),
                                      ),
                                    ),
                                  ]
                                : [_buildPremiumGate()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _ink, size: 18),
          ),
          const Expanded(
            child: Text(
              'Food waste saved',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _blue.withValues(alpha: 0.55)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: _blue),
                SizedBox(width: 4),
                Text(
                  'PREMIUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: _blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumGate() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 18),
          const Text(
            'Track your impact',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Money saved, weekly charts, milestones, and how you compare to the UK average.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _openPaywall,
            child: Container(
              width: double.infinity,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Unlock with Premium',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final money = _stats.moneySavedGbp;
    final kg = _stats.kgAvoided;
    final pct = _stats.ukComparisonPercent.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SINCE YOU JOINED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '£${money.toStringAsFixed(money >= 100 ? 0 : 0)}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: _ink,
            fontFamily: 'Nunito',
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _blue,
              height: 1.35,
            ),
            children: [
              const TextSpan(text: 'saved, and '),
              TextSpan(
                text: '${kg.toStringAsFixed(0)} kg',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: ' of food waste avoided.'),
            ],
          ),
        ),
        if (pct > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$pct% better than the UK average this month.',
            style: const TextStyle(
              fontSize: 13,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNextMilestone() {
    final money = _stats.moneySavedGbp;
    final target = FoodWasteService.nextMoneyTarget(money);
    final progress = (money / target).clamp(0.0, 1.0);
    final toGo = (target - money).clamp(0.0, target);
    final milestones = _stats.milestones;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next milestone',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Money saved since joining.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.eco_rounded, color: _green, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _RingPainter(
                        progress: progress,
                        color: _blue,
                        trackColor: const Color(0xFFE6E8F0),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            fontFamily: 'Nunito',
                          ),
                        ),
                        Text(
                          'OF £${target >= 1000 ? target.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},') : target.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '£${toGo.toStringAsFixed(0)} to go',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final m in milestones.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              m.unlocked
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: m.unlocked ? _green : const Color(0xFFC5C7D4),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: m.unlocked ? _ink : _muted,
                                  decoration: _pulseThreshold != null &&
                                          m.label.contains('£$_pulseThreshold')
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySavings() {
    final weeks = _visibleWeeks;
    final periodTotal =
        weeks.fold<double>(0, (s, w) => s + w.amountGbp);
    final thisWeek = weeks.isEmpty ? 0.0 : weeks.last.amountGbp;
    final loggedWeeks = weeks.where((w) => w.amountGbp > 0).length;
    final best = weeks.isEmpty
        ? null
        : weeks.reduce((a, b) => a.amountGbp >= b.amountGbp ? a : b);
    final hasAny = periodTotal > 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly savings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontFamily: 'Nunito',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Each week, and your running total.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              _WeekToggle(
                weeks8: _weeks8,
                onChanged: (v) => setState(() => _weeks8 = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 14, color: _ink, height: 1.3),
                    children: [
                      TextSpan(
                        text: '£${periodTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      TextSpan(
                        text:
                            ' saved in the last ${_weeks8 ? 8 : 4} weeks',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '£${thisWeek.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  const Text(
                    'this week',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
            ],
          ),
          if (best != null && best.amountGbp > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Best week ${_fmtDate(best.weekStart)}, £${best.amountGbp.toStringAsFixed(2)}'
              ' · $loggedWeeks of ${weeks.length} weeks logged',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _blue,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: weeks.isEmpty
                ? const Center(
                    child: Text('No weekly data yet',
                        style: TextStyle(color: _muted)))
                : _WeeklyChart(weeks: weeks),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(color: _blue, label: 'Saved that week'),
              const SizedBox(width: 14),
              _LegendDot(color: _goldLine, label: 'Running total'),
            ],
          ),
          if (!hasAny) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nothing logged yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _startScan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Start a scan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
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

  Widget _buildUkAverage() {
    final weekly = FoodWasteService.ukAverageWeeklyWasteGbp;
    final weeksCovered = weekly <= 0
        ? 0
        : (_stats.moneySavedGbp / weekly).round().clamp(0, 999);
    final filled = weeksCovered.clamp(0, 52);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Against the UK average',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'An average household wastes £${weekly.toStringAsFixed(2)} of food a week',
            style: const TextStyle(fontSize: 13, color: _muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 15,
                color: _ink,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
              children: [
                const TextSpan(text: '≈ '),
                TextSpan(
                  text: '$weeksCovered',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                  ),
                ),
                TextSpan(
                  text:
                      ' weeks of a typical household\'s food waste, covered by your £${_stats.moneySavedGbp.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const cols = 13;
              const rows = 4;
              const gap = 4.0;
              final cell =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: List.generate(cols * rows, (i) {
                  final isFilled = i < filled;
                  return Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: isFilled ? _blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: isFilled
                            ? _blue
                            : const Color(0xFFC8CBD8),
                        width: 1.2,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'One square = one week (£${weekly.toStringAsFixed(2)}). 52 squares = one year.',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStats() {
    final streakNote = _stats.weekStreak > 0
        ? 'Keep scanning to grow it'
        : (_stats.bestWeekStreak > 0
            ? 'Best ${_stats.bestWeekStreak} · scan this week to restart'
            : 'Scan this week to start');

    return Row(
      children: [
        Expanded(
          child: _Card(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly streak',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_stats.weekStreak} wks',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streakNote,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _stats.weekStreak > 0 ? _green : _brown,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Card(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scans',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_stats.totalScans}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'since joining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _FoodWasteDashboardScreenState._cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WeekToggle extends StatelessWidget {
  final bool weeks8;
  final ValueChanged<bool> onChanged;

  const _WeekToggle({required this.weeks8, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('4W', !weeks8, () => onChanged(false)),
          _chip('8W', weeks8, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _FoodWasteDashboardScreenState._blue
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _FoodWasteDashboardScreenState._muted,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: _FoodWasteDashboardScreenState._muted),
        ),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<WeeklySaving> weeks;

  const _WeeklyChart({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final maxBar = weeks
        .map((w) => w.amountGbp)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = (maxBar <= 0 ? 20.0 : maxBar * 1.25).clamp(5.0, 9999.0);

    var running = 0.0;
    final cumulatives = <double>[];
    for (final w in weeks) {
      running += w.amountGbp;
      cumulatives.add(running);
    }
    final maxLine = cumulatives.isEmpty
        ? 1.0
        : cumulatives.reduce((a, b) => a > b ? a : b).clamp(1.0, 99999.0);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight - 18;
              final n = weeks.length;
              final slot = w / n;

              return Stack(
                children: [
                  // Bars
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    height: h,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: FractionallySizedBox(
                                heightFactor: maxBar <= 0
                                    ? 0.04
                                    : (weeks[i].amountGbp / chartMax)
                                        .clamp(0.04, 1.0),
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _FoodWasteDashboardScreenState._blue,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Running total line
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    height: h,
                    child: CustomPaint(
                      painter: _RunningLinePainter(
                        values: cumulatives,
                        maxValue: maxLine,
                        color: _FoodWasteDashboardScreenState._goldLine,
                      ),
                    ),
                  ),
                  // X labels
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(
                            child: Text(
                              _label(weeks[i].weekStart, i == 0 || i == n - 1 || i % 2 == 0),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                fontSize: 9,
                                color: _FoodWasteDashboardScreenState._muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ignore unused slot warning
                  if (slot < 0) const SizedBox.shrink(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _label(DateTime d, bool show) {
    if (!show) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _RunningLinePainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color color;

  _RunningLinePainter({
    required this.values,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final x = (i + 0.5) / n * size.width;
      final y = size.height -
          (values[i] / maxValue).clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    final dot = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      if (values[i] <= 0 && i != n - 1) continue;
      final x = (i + 0.5) / n * size.width;
      final y = size.height -
          (values[i] / maxValue).clamp(0.0, 1.0) * size.height;
      canvas.drawCircle(Offset(x, y), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RunningLinePainter old) =>
      old.values != values || old.maxValue != maxValue;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const start = -math.pi / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 2,
      false,
      track,
    );

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
