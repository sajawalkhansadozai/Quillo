import 'package:flutter/material.dart';
import '../../models/pantry_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ingredient_visual_icon.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared look for the smart pantry screens
// ─────────────────────────────────────────────────────────────────────────────

class PantryColors {
  PantryColors._();

  static const indigo = Color(0xFF4A3AFF);
  static const bg = Color(0xFFF3F4F8);
  static const border = Color(0xFFE8E8F0);
  static const segmentBg = Color(0xFFE7E7F0);
  static const red = Color(0xFFD93025);
  static const redBg = Color(0xFFFDECEA);
  static const amber = Color(0xFFB7791F);
  static const amberBg = Color(0xFFFFF4DC);
  static const green = Color(0xFF2E7D4F);
  static const greenBg = Color(0xFFE6F4EC);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _longMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

/// "24 Oct"
String pantryShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "24 October"
String pantryLongDate(DateTime d) => '${d.day} ${_longMonths[d.month - 1]}';

/// "24 Oct" within ~2 months, otherwise "Feb 2027".
String pantryEstDate(DateTime d) {
  final days = d.difference(DateTime.now()).inDays;
  return days > 60 ? '${_months[d.month - 1]} ${d.year}' : pantryShortDate(d);
}

/// "2 days", "3 weeks", "4 months".
String pantrySpan(int days) {
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day';
  if (days < 28) return '$days days';
  if (days < 60) return '${(days / 7).round()} weeks';
  return '${(days / 30).round()} months';
}

/// Red for use-first (≤2 days, or expired), amber for use-soon (≤5), else null.
({Color fg, Color bg})? pantryUrgency(PantryItem item) {
  final d = item.daysUntilExpiry;
  if (d == null) return null;
  if (d <= 2) return (fg: PantryColors.red, bg: PantryColors.redBg);
  if (d <= 5) return (fg: PantryColors.amber, bg: PantryColors.amberBg);
  return null;
}

Color pantryTileColor(PantryLocation l) {
  switch (l) {
    case PantryLocation.fresh:
      return const Color(0xFFE8F5E9);
    case PantryLocation.fridge:
      return const Color(0xFFFFF3E0);
    case PantryLocation.pantry:
      return const Color(0xFFFFEBEE);
    case PantryLocation.freezer:
      return const Color(0xFFE3F2FD);
  }
}

IconData pantryLocationIcon(PantryLocation l) {
  switch (l) {
    case PantryLocation.fresh:
      return Icons.eco_outlined;
    case PantryLocation.fridge:
      return Icons.kitchen_outlined;
    case PantryLocation.pantry:
      return Icons.shopping_bag_outlined;
    case PantryLocation.freezer:
      return Icons.ac_unit_rounded;
  }
}

BoxDecoration pantryCard({double radius = 20}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: PantryColors.border),
    );

/// Section heading — matches Home/Explore section titles.
const pantryH2 = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w900,
  color: AppColors.textDark,
  fontFamily: 'Nunito',
);

const pantryCaps = TextStyle(
  fontSize: 11,
  letterSpacing: 1.0,
  fontWeight: FontWeight.w800,
  color: AppColors.textDark,
  fontFamily: 'Nunito',
);

class PantryEmojiTile extends StatelessWidget {
  final PantryItem item;
  final double size;
  const PantryEmojiTile({super.key, required this.item, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return IngredientVisualIcon(
      ingredientName: item.name,
      size: size,
      background: pantryTileColor(item.location),
      borderRadius: BorderRadius.circular(size * 0.27),
    );
  }
}

class PantryPill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;
  const PantryPill({
    super.key,
    required this.text,
    required this.fg,
    required this.bg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indigo header with rounded bottom corners used across the pantry screens.
class PantryHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final bool showBack;

  /// Kept for callers; typography now matches Explore/Home either way.
  final bool compact;

  const PantryHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const [],
    this.showBack = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 6, 20, compact ? 16 : 20),
      decoration: const BoxDecoration(
        color: PantryColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 4),
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.85),
                fontFamily: 'Nunito',
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            title,
            style: const TextStyle(
              // Matches Explore page title (26) / Home greeting.
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
              fontFamily: 'Nunito',
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.9),
                fontFamily: 'Nunito',
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Pill-shaped segmented control (All / Fresh / Fridge …).
class PantrySegmented<T> extends StatelessWidget {
  final List<({String label, T value})> options;
  final T selected;
  final ValueChanged<T> onSelect;

  const PantrySegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PantryColors.segmentBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(o.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: o.value == selected
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: o.value == selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      o.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: o.value == selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: o.value == selected
                            ? AppColors.textDark
                            : AppColors.textMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-width rounded primary button.
class PantryPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;

  const PantryPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
