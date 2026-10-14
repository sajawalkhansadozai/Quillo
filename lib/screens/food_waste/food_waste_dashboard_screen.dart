import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/food_waste_service.dart';
import '../../services/in_app_notification_service.dart';
import '../../services/subscription_service.dart';
import '../paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FoodWasteDashboardScreen — clean impact layout
// ─────────────────────────────────────────────────────────────────────────────

class FoodWasteDashboardScreen extends StatefulWidget {
  const FoodWasteDashboardScreen({super.key});

  @override
  State<FoodWasteDashboardScreen> createState() =>
      _FoodWasteDashboardScreenState();
}

class _FoodWasteDashboardScreenState extends State<FoodWasteDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _ink = Color(0xFF1B4332);
  static const _mid = Color(0xFF2D6A4F);
  static const _mint = Color(0xFFD8F3DC);
  static const _mintSoft = Color(0xFFF1F8F3);
  static const _barSoft = Color(0xFF95D5B2);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE8EEE9);
  static const _bg = Color(0xFFFAFCFB);

  WasteStats _stats = const WasteStats();
  bool _isPremium = false;
  bool _loading = true;
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
      '£50 saved': 50,
      '£100 saved': 100,
      '£250 saved': 250,
      '£500 saved': 500,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _ink))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      _isPremium
                          ? [
                              _buildImpactCard(),
                              const SizedBox(height: 14),
                              _buildStatRow(),
                              const SizedBox(height: 22),
                              _buildWeeklyChart(),
                              const SizedBox(height: 14),
                              _buildUkComparison(),
                              const SizedBox(height: 22),
                              _buildMilestones(),
                              const SizedBox(height: 22),
                              _buildFooterCta(),
                            ]
                          : [_buildPremiumGate()],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 6, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _ink, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Food waste saved',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    fontFamily: 'Nunito',
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Small changes. A bigger tomorrow.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          if (_isPremium)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 14, color: Color(0xFFC9A227)),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _ink,
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
            child: const Icon(Icons.eco_rounded, color: _mint, size: 28),
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

  Widget _buildImpactCard() {
    final money = _stats.moneySavedGbp.toStringAsFixed(0);
    final kg = _stats.kgAvoided.toStringAsFixed(0);
    final pct = _stats.ukComparisonPercent.round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: _mintSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _mint.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your impact so far',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _mid,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ImpactMetric(
                  value: '£$money',
                  label: 'money saved\nsince joining',
                  icon: Icons.savings_outlined,
                ),
              ),
              Container(width: 1, height: 56, color: _line),
              const SizedBox(width: 16),
              Expanded(
                child: _ImpactMetric(
                  value: '$kg kg',
                  label: 'food waste\navoided',
                  icon: Icons.recycling_rounded,
                ),
              ),
            ],
          ),
          if (pct > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_rounded,
                      color: _mint, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$pct% better than the UK average this month',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.25,
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

  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFE85D04),
            value: '${_stats.weekStreak}',
            title: 'week streak',
            subtitle: 'Keep it going!',
            subtitleColor: _mid,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.emoji_events_outlined,
            iconColor: const Color(0xFFC9A227),
            value: '${_stats.bestWeekStreak}',
            title: 'best streak',
            subtitle: 'Your record',
            subtitleColor: const Color(0xFFB08968),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF7B68EE),
            value: '${_stats.totalScans}',
            title: 'total scans',
            subtitle: 'Since joining',
            subtitleColor: const Color(0xFF7B68EE),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final weeks = _stats.weeklySavings;
    final maxVal = weeks.isEmpty
        ? 15.0
        : weeks.map((w) => w.amountGbp).reduce((a, b) => a > b ? a : b);
    final chartMax = (maxVal <= 0 ? 15.0 : maxVal * 1.2).clamp(5.0, 999.0);
    final latest = weeks.isEmpty ? 0.0 : weeks.last.amountGbp;
    final showProgressNote =
        weeks.length >= 2 && latest > 0 && latest >= maxVal * 0.85;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly savings — last 8 weeks',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _ink,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < weeks.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 3,
                        right: i == weeks.length - 1 ? 0 : 3,
                      ),
                      child: _ChartBar(
                        amount: weeks[i].amountGbp,
                        maxAmount: chartMax,
                        isLatest: i == weeks.length - 1,
                        showLabel: i == weeks.length - 1 && latest > 0,
                        barSoft: _barSoft,
                        ink: _ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < weeks.length; i++)
                Expanded(
                  child: Text(
                    _shortDate(weeks[i].weekStart),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: _muted),
                  ),
                ),
            ],
          ),
          if (showProgressNote) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Color(0xFFE85D04)),
                SizedBox(width: 6),
                Text(
                  'Great progress this week',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE85D04),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Widget _buildUkComparison() {
    final monthly = _stats.monthlyWasteAvoidedGbp.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mintSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _mint.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.home_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'vs UK average household',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: _mid,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'The average UK household wastes £${FoodWasteService.ukAverageWeeklyWasteGbp.toStringAsFixed(2)} per week. You avoided ',
                      ),
                      TextSpan(
                        text: '£$monthly',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      const TextSpan(text: ' of waste this month.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Milestones',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _ink,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _stats.milestones.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 28),
                      color: _stats.milestones[i - 1].unlocked
                          ? _ink
                          : _line,
                    ),
                  ),
                _MilestoneNode(
                  label: _stats.milestones[i].label,
                  unlocked: _stats.milestones[i].unlocked,
                  pulse: _pulseThreshold != null &&
                      _stats.milestones[i].label
                          .contains('£$_pulseThreshold'),
                  pulseAnimation: _pulseCtrl,
                  ink: _ink,
                  mint: _mint,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterCta() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: _mintSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _mint.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Small choices make a big difference.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _shareStats,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _ImpactMetric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _ImpactMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2D6A4F)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1B4332),
            fontFamily: 'Nunito',
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String title;
  final String subtitle;
  final Color subtitleColor;

  const _MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B4332),
              fontFamily: 'Nunito',
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: subtitleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  final double amount;
  final double maxAmount;
  final bool isLatest;
  final bool showLabel;
  final Color barSoft;
  final Color ink;

  const _ChartBar({
    required this.amount,
    required this.maxAmount,
    required this.isLatest,
    required this.showLabel,
    required this.barSoft,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.0, 1.0);
    final height = 10.0 + fraction * 100;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '£${amount.toStringAsFixed(amount >= 10 ? 0 : 1)}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: isLatest ? ink : barSoft,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  final String label;
  final bool unlocked;
  final bool pulse;
  final Animation<double>? pulseAnimation;
  final Color ink;
  final Color mint;

  const _MilestoneNode({
    required this.label,
    required this.unlocked,
    required this.pulse,
    required this.pulseAnimation,
    required this.ink,
    required this.mint,
  });

  @override
  Widget build(BuildContext context) {
    Widget node = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: unlocked ? ink : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: Border.all(
          color: unlocked ? ink : const Color(0xFFD1D5DB),
          width: 1.5,
        ),
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: ink.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(
        unlocked ? Icons.check_rounded : Icons.lock_outline_rounded,
        color: unlocked ? Colors.white : const Color(0xFF9CA3AF),
        size: 16,
      ),
    );

    if (pulse && pulseAnimation != null) {
      node = ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.08).animate(pulseAnimation!),
        child: node,
      );
    }

    return SizedBox(
      width: 58,
      child: Column(
        children: [
          node,
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: unlocked ? ink : const Color(0xFF9CA3AF),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
