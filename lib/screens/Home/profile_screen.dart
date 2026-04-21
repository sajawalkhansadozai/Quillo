import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotifications = true;
  bool _twoFactor = false;

  final List<_PrefChip> _dietChips = [
    _PrefChip('Vegan', const Color(0xFF4CAF50)),
    _PrefChip('Vegetarian', const Color(0xFF2196F3)),
    _PrefChip('Meat', const Color(0xFFE91E63)),
    _PrefChip('Pescatarian', const Color(0xFF009688)),
    _PrefChip('Gluten Free', const Color(0xFFFF9800)),
    _PrefChip('Dairy Free', const Color(0xFF9C27B0)),
    _PrefChip('Nut Free', const Color(0xFF795548)),
  ];

  final List<_PrefChip> _skillChips = [
    _PrefChip('Beginner', const Color(0xFFFF9800)),
    _PrefChip('Home Cook', const Color(0xFF6C63FF)),
    _PrefChip('Intermediate', const Color(0xFF9C27B0)),
    _PrefChip('Family', const Color(0xFF4CAF50)),
    _PrefChip('Meal Prep', const Color(0xFF2196F3)),
    _PrefChip('Advanced', const Color(0xFFE91E63)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildProfileCard()),
            SliverToBoxAdapter(child: _buildPreferences()),
            SliverToBoxAdapter(child: _buildProCard()),
            SliverToBoxAdapter(child: _buildSettingsSection()),
            SliverToBoxAdapter(child: _buildAccountSection()),
            SliverToBoxAdapter(child: _buildMoreSection()),
            SliverToBoxAdapter(child: _buildDangerZone()),
            SliverToBoxAdapter(child: _buildSignOut()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          _CircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () {}),
          const Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ── Profile card ───────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF9C8FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD54F), Color(0xFFFF8A65)],
                ),
              ),
              child: const Center(
                child: Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            // Name & email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'John',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'john@quillo.com',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✦ Pro Member',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Edit button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preferences ─────────────────────────────────────────────────────────────

  Widget _buildPreferences() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Preferences'),
          const SizedBox(height: 10),
          _SubLabel('Cuisine'),
          const SizedBox(height: 8),
          _ChipWrap(chips: _dietChips),
          const SizedBox(height: 12),
          _SubLabel('Skill Level'),
          const SizedBox(height: 8),
          _ChipWrap(chips: _skillChips),
          const SizedBox(height: 14),
          _PrefRow(
            icon: '🥗',
            title: 'More Nutritious',
            subtitle: 'Prioritise healthier recipe suggestions',
            trailing: const Text('Update >', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          _Divider(),
          _PrefRow(
            icon: '🍳',
            title: 'Cooking Fill',
            subtitle: 'Manage your pantry ingredients',
            trailing: const Text('Manage >', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          _Divider(),
          _PrefRow(
            icon: '⏱️',
            title: 'Max Cook Time',
            subtitle: 'Set your maximum cooking time',
            trailing: const Text('36m >', style: TextStyle(fontSize: 12, color: AppColors.textMedium, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'View preferences →',
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quillo Pro card ─────────────────────────────────────────────────────────

  Widget _buildProCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'QUILLO Pro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito'),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Go Pro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProFeature('Unlimited recipe access'),
            _ProFeature('Scan receipts & generate recipes by meal'),
            _ProFeature('Nutritional info per recipe'),
            _ProFeature('Priority AI suggestions'),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  '£7.99',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  '/month',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Manage Plan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Settings section ────────────────────────────────────────────────────────

  Widget _buildSettingsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Settings'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                _SettingToggleRow(
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFF6C63FF),
                  title: 'Push Notifications',
                  subtitle: 'Recipe alerts & reminders',
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                _SettingDivider(),
                _SettingArrowRow(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Language',
                  subtitle: 'Set your preferred language',
                  trailing: 'English',
                ),
                _SettingDivider(),
                _SettingArrowRow(
                  icon: Icons.straighten_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Measurement Units',
                  subtitle: 'Cups, grams, ml...',
                  trailing: 'Metric',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Account section ─────────────────────────────────────────────────────────

  Widget _buildAccountSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Account'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                _SettingArrowRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF9C27B0),
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  trailing: '',
                ),
                _SettingDivider(),
                _SettingArrowRow(
                  icon: Icons.people_outline_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: 'People',
                  subtitle: 'Manage followers & following',
                  trailing: 'Remove',
                  trailingColor: const Color(0xFFE53935),
                ),
                _SettingDivider(),
                _SettingArrowRow(
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Sign In',
                  subtitle: 'Manage connected accounts',
                  trailing: 'Continue',
                ),
                _SettingDivider(),
                _SettingToggleRow(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Two-Factor Authentication',
                  subtitle: 'Extra security for your account',
                  value: _twoFactor,
                  onChanged: (v) => setState(() => _twoFactor = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── More section ─────────────────────────────────────────────────────────────

  Widget _buildMoreSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('More'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                _SettingArrowRow(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF2196F3),
                  title: 'Help Center',
                  subtitle: 'FAQs and support articles',
                  trailing: '',
                ),
                _SettingDivider(),
                _SettingArrowRow(
                  icon: Icons.feedback_outlined,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Send Feedback',
                  subtitle: 'Help us improve Quillo',
                  trailing: '',
                ),
                _SettingDivider(),
                _SettingArrowRow(
                  icon: Icons.article_outlined,
                  iconColor: const Color(0xFFFF9800),
                  title: 'Content Register',
                  subtitle: 'View terms and privacy policy',
                  trailing: '',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Danger zone ─────────────────────────────────────────────────────────────

  Widget _buildDangerZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Column(
          children: [
            _DangerRow(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Pause Account',
              subtitle: 'Temporarily disable your account',
            ),
            Divider(height: 1, color: const Color(0xFFFFCDD2).withValues(alpha: 0.6), indent: 54),
            _DangerRow(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Account',
              subtitle: 'Permanently remove your data',
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign out ─────────────────────────────────────────────────────────────────

  Widget _buildSignOut() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GestureDetector(
        onTap: () {},
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 18),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PrefChip {
  final String label;
  final Color color;
  const _PrefChip(this.label, this.color);
}

class _ChipWrap extends StatelessWidget {
  final List<_PrefChip> chips;
  const _ChipWrap({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                c.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.color,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  const _PrefRow({required this.icon, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textLight,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMedium),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.divider);
  }
}

class _SettingDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 54, color: AppColors.divider);
  }
}

class _SettingToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingArrowRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;

  const _SettingArrowRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.trailingColor = AppColors.textMedium,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _IconBox(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              Text(trailing, style: TextStyle(fontSize: 12, color: trailingColor, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _ProFeature extends StatelessWidget {
  final String text;
  const _ProFeature(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _DangerRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFFE53935)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFEF9A9A)),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }
}
