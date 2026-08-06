import 'package:flutter/material.dart';
import '../services/scan_limit_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScanUsageBanner — shows remaining monthly scans for free users
// ─────────────────────────────────────────────────────────────────────────────

class ScanUsageBanner extends StatefulWidget {
  const ScanUsageBanner({super.key});

  @override
  State<ScanUsageBanner> createState() => _ScanUsageBannerState();
}

class _ScanUsageBannerState extends State<ScanUsageBanner> {
  int _used = 0;
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    SubscriptionService.premiumNotifier.addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    SubscriptionService.premiumNotifier.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() => _load();

  Future<void> _load() async {
    final premium = await SubscriptionService.isPremium();
    final used = premium ? 0 : await ScanLimitService.monthlyCount();
    if (!mounted) return;
    setState(() {
      _isPremium = premium;
      _used = used;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _isPremium) return const SizedBox.shrink();

    final limit = ScanLimitService.freeMonthlyLimit;
    final remaining = (limit - _used).clamp(0, limit);
    final isLow = remaining <= 2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFFF3E0) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? const Color(0xFFFFB74D) : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.receipt_long_rounded,
            size: 18,
            color: isLow ? const Color(0xFFE65100) : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining == 0
                  ? 'No free scans left this month'
                  : '$remaining of $limit free scans left this month',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isLow ? const Color(0xFFE65100) : AppColors.textDark,
              ),
            ),
          ),
          if (remaining > 0)
            Text(
              '$_used used',
              style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
            ),
        ],
      ),
    );
  }
}
