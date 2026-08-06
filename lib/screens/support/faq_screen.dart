import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FaqScreen — in-app help / FAQ opened from Profile or home-screen quick action
// ─────────────────────────────────────────────────────────────────────────────

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _items = <({String q, String a})>[
    (
      q: 'How do I scan a receipt?',
      a: 'Tap the Scan button in the center of the tab bar, take a photo of your '
          'grocery receipt, and Quillo will read the ingredients for you. You can '
          'also enter ingredients manually.',
    ),
    (
      q: 'How many free scans do I get?',
      a: 'Free accounts get 2 scans per month. Quillo Pro removes this limit so '
          'you can scan as often as you like.',
    ),
    (
      q: 'Why don’t recipes match my diet?',
      a: 'Open Profile → Preferences and set your dietary labels, cuisines, cook '
          'time, and skill level. Home and Explore then filter recipes to match.',
    ),
    (
      q: 'How do I save a recipe?',
      a: 'Open any recipe and tap the bookmark icon. Saved recipes appear on the '
          'Saved tab, including offline when you’ve viewed them before.',
    ),
    (
      q: 'What is Quillo Pro?',
      a: 'Pro includes unlimited monthly scans, an ad-free experience, and the '
          'food waste impact dashboard. You can upgrade from Profile or when you '
          'hit the free scan limit.',
    ),
    (
      q: 'How do I change my household size or cuisines?',
      a: 'Go to Profile → Preferences. Changes apply the next time Home or '
          'Explore refreshes (pull to refresh or switch tabs).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Help & FAQs',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Have a question?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quick answers about scanning, preferences, and Quillo Pro.',
            style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.4),
          ),
          const SizedBox(height: 20),
          ..._items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    item.q,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  children: [
                    Text(
                      item.a,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
