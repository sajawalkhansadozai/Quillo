import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/food_waste_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FoodWasteDashboardScreen — Premium retention dashboard (shareable stats)
// ─────────────────────────────────────────────────────────────────────────────

class FoodWasteDashboardScreen extends StatefulWidget {
  const FoodWasteDashboardScreen({super.key});

  @override
  State<FoodWasteDashboardScreen> createState() =>
      _FoodWasteDashboardScreenState();
}

class _FoodWasteDashboardScreenState extends State<FoodWasteDashboardScreen> {
  WasteStats _stats = const WasteStats();
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prem = await SubscriptionService.isPremium();
    final stats = await FoodWasteService.loadStats();
    if (!mounted) return;
    setState(() {
      _isPremium = prem;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _shareStats() async {
    final money = _stats.moneySavedGbp.toStringAsFixed(0);
    final text =
        "I've avoided £$money of food waste with Quillo 🌱 "
        '${_stats.itemsRescued} ingredients rescued · ${_stats.streak} day streak';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stats copied — paste to share!'),
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
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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
      backgroundColor: const Color(0xFFF4F5FA),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (!_isPremium)
                    SliverToBoxAdapter(child: _buildPremiumGate())
                  else ...[
                    SliverToBoxAdapter(child: _buildHeroCard()),
                    SliverToBoxAdapter(child: _buildStatsGrid()),
                    SliverToBoxAdapter(child: _buildStreakCard()),
                    SliverToBoxAdapter(child: _buildShareButton()),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textDark),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Food Waste Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumGate() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
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
              'See how much food waste you\'ve avoided and how much money you\'ve saved. Premium members get a full dashboard with streaks and shareable stats.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openPaywall,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Unlock with Premium',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final money = _stats.moneySavedGbp.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '£$money',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4CAF50),
                fontFamily: 'Nunito',
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'food waste avoided',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              emoji: '🥕',
              value: '${_stats.itemsRescued}',
              label: 'Ingredients rescued',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              emoji: '🔥',
              value: '${_stats.streak}',
              label: 'Day streak',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keep your streak alive',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stats.streak > 0
                        ? 'Scan a receipt today to extend your ${_stats.streak}-day streak.'
                        : 'Scan a receipt today to start your streak.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.4,
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

  Widget _buildShareButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: _shareStats,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Share my impact',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }
}
