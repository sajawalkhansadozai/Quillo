import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PaywallScreen
// ─────────────────────────────────────────────────────────────────────────────

enum _Plan { yearly, monthly }

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  _Plan _selected = _Plan.yearly;

  late AnimationController _heroCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroFade;

  static const _bg = Color(0xFF0C0C1A);
  static const _card = Color(0xFF15152A);
  static const _cardBorder = Color(0xFF252540);
  static const _amber = Color(0xFFFFB300);
  static const _amberLight = Color(0xFFFFC107);
  static const _textGrey = Color(0xFF8888AA);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _heroCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _heroScale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroCtrl.forward();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _heroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildTopBar(),
              _buildHero(),
              _buildHeadline(),
              const SizedBox(height: 24),
              _buildFeaturesGrid(),
              const SizedBox(height: 28),
              _buildPlanSection(),
              const SizedBox(height: 20),
              _buildSocialProof(),
              const SizedBox(height: 24),
              _buildCTA(),
              const SizedBox(height: 14),
              _buildRestore(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('✦', style: TextStyle(fontSize: 11, color: _amber)),
                SizedBox(width: 5),
                Text(
                  'QUILLO PRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _amber,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: AnimatedBuilder(
        animation: _heroCtrl,
        builder: (_, __) => FadeTransition(
          opacity: _heroFade,
          child: ScaleTransition(
            scale: _heroScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow behind emoji
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _amber.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const Text('🍜', style: TextStyle(fontSize: 80)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Headline ─────────────────────────────────────────────────────────────────

  Widget _buildHeadline() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PREMIUM MEMBER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: _amber,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                height: 1.15,
              ),
              children: [
                TextSpan(text: 'Unlock ', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'Premium\n', style: TextStyle(color: _amberLight)),
                TextSpan(text: 'Cooking', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Everything you need to master recipes,\nsave money and cook smarter every day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Features grid ────────────────────────────────────────────────────────────

  Widget _buildFeaturesGrid() {
    final features = [
      _Feature('♾️', 'Unlimited Recs', 'Get endless personalised recipes'),
      _Feature('📷', 'Unlimited Scan', 'Scan receipts as many times as you want'),
      _Feature('🤖', 'AI Recipes', 'Recipes generated by advanced AI'),
      _Feature('🥗', 'Nutrition AI', 'Full nutritional breakdown per meal'),
      _Feature('📋', 'Smart Lists', 'Auto-generate your grocery lists'),
      _Feature('⭐', 'Priority Support', '24/7 dedicated customer support'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.05,
        ),
        itemCount: features.length,
        itemBuilder: (_, i) => _FeatureCard(feature: features[i]),
      ),
    );
  }

  // ── Plan section ─────────────────────────────────────────────────────────────

  Widget _buildPlanSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHOOSE YOUR PLAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: _textGrey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _PlanTile(
            icon: '📅',
            title: 'Yearly',
            subtitle: 'Less than £0.84/week',
            price: '£43.99',
            badgeText: 'SAVE 54%',
            badgeColor: const Color(0xFFE53935),
            isSelected: _selected == _Plan.yearly,
            onTap: () => setState(() => _selected = _Plan.yearly),
          ),
          const SizedBox(height: 10),
          _PlanTile(
            icon: '🔄',
            title: 'Monthly',
            subtitle: 'Billed every month, cancel anytime',
            price: '£5.99',
            isSelected: _selected == _Plan.monthly,
            onTap: () => setState(() => _selected = _Plan.monthly),
          ),
        ],
      ),
    );
  }

  // ── Social proof ─────────────────────────────────────────────────────────────

  Widget _buildSocialProof() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar stack
              SizedBox(
                width: 70,
                height: 28,
                child: Stack(
                  children: [
                    for (int i = 0; i < 4; i++)
                      Positioned(
                        left: i * 16.0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 2),
                            color: [
                              const Color(0xFF6C63FF),
                              const Color(0xFFFF9800),
                              const Color(0xFF4CAF50),
                              const Color(0xFFE91E63),
                            ][i],
                          ),
                          child: Center(
                            child: Text(
                              ['A', 'B', 'C', 'D'][i],
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4),
                    children: const [
                      TextSpan(
                        text: '7 friends ',
                        style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                          text: 'are already enjoying Quillo Pro'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"Quillo Pro completely changed how I cook. The AI recipes are incredible!"',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
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

  // ── CTA button ───────────────────────────────────────────────────────────────

  Widget _buildCTA() {
    final isYearly = _selected == _Plan.yearly;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_amber, _amberLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _amber.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isYearly ? '▶  ' : '⚡  ',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                Text(
                  isYearly
                      ? 'Start Free Trial'
                      : 'Upgrade Now · £5.99/mo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Restore ──────────────────────────────────────────────────────────────────

  Widget _buildRestore() {
    return GestureDetector(
      onTap: () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('♻  ', style: TextStyle(fontSize: 12, color: _textGrey)),
          Text(
            'Restore Purchases',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature card
// ─────────────────────────────────────────────────────────────────────────────

class _Feature {
  final String emoji;
  final String title;
  final String subtitle;
  const _Feature(this.emoji, this.title, this.subtitle);
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  static const _card = Color(0xFF15152A);
  static const _cardBorder = Color(0xFF252540);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Text(feature.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF7777AA),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan tile
// ─────────────────────────────────────────────────────────────────────────────

class _PlanTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String price;
  final String? badgeText;
  final Color? badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    this.badgeText,
    this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  static const _amber = Color(0xFFFFB300);
  static const _card = Color(0xFF15152A);
  static const _cardBorder = Color(0xFF252540);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? _amber.withValues(alpha: 0.08)
              : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _amber.withValues(alpha: 0.7) : _cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFFCCCCDD),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF7777AA)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? _amber : const Color(0xFFCCCCDD),
                  ),
                ),
                Text(
                  title == 'Yearly' ? '/year' : '/mo',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF7777AA)),
                ),
              ],
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _amber : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _amber : const Color(0xFF444466),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
