import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';
import '../auth/sign_in_screen.dart';
import '../paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotifications = true;
  bool _twoFactor = false;

  // ── Real user data ──────────────────────────────────────────────────────────
  final _client = Supabase.instance.client;
  String _userEmail = '';
  String _userName = '';
  bool _isPremium = false;
  List<_PrefChip> _dietChips = [];
  List<_PrefChip> _cuisineChips = [];
  int _householdSize = 2;
  String _cookingSkill = 'Intermediate';
  int _maxCookTime = 45;
  bool _googleConnected = false;
  bool _appleConnected = false;
  bool _isEmailLogin = true;

  static const _dietColors = [
    Color(0xFF4CAF50), Color(0xFF5C6BC0), Color(0xFFFF7043),
    Color(0xFF009688), Color(0xFFFFB300), Color(0xFFEC407A),
    Color(0xFF8D6E63),
  ];
  static const _cuisineColors = [
    Color(0xFF37474F), Color(0xFFFFB300), Color(0xFF1E88E5),
    Color(0xFF00897B), Color(0xFF5C6BC0), Color(0xFF8E24AA),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _client.auth.currentUser?.id;
    final email = _client.auth.currentUser?.email ?? '';
    if (uid == null) return;

    try {
      final userRow = await _client
          .from('users')
          .select('email, subscription_status, household_size, preferred_cuisine')
          .eq('id', uid)
          .maybeSingle();

      final prefsRow = await _client
          .from('user_preferences')
          .select('dietary_labels, cooking_skill, max_cook_time')
          .eq('user_id', uid)
          .maybeSingle();

      final dietary = List<String>.from(prefsRow?['dietary_labels'] ?? []);
      final cuisines = List<String>.from(userRow?['preferred_cuisine'] ?? []);
      final status = (userRow?['subscription_status'] as String?) ?? 'free';

      // Detect SSO providers
      final identities = _client.auth.currentUser?.identities ?? [];
      final providers = identities.map((i) => i.provider).toSet();

      if (!mounted) return;
      setState(() {
        _userEmail = (userRow?['email'] as String?) ?? email;
        _userName = _firstName(_userEmail);
        _isPremium = status == 'premium';
        _householdSize = (userRow?['household_size'] as int?) ?? 2;
        _cookingSkill = (prefsRow?['cooking_skill'] as String?) ?? 'Intermediate';
        _maxCookTime = (prefsRow?['max_cook_time'] as int?) ?? 45;
        _googleConnected = providers.contains('google');
        _appleConnected = providers.contains('apple');
        _isEmailLogin = providers.contains('email');
        _dietChips = dietary
            .asMap()
            .entries
            .map((e) => _PrefChip(e.value, _dietColors[e.key % _dietColors.length]))
            .toList();
        _cuisineChips = cuisines
            .asMap()
            .entries
            .map((e) => _PrefChip(e.value, _cuisineColors[e.key % _cuisineColors.length]))
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() { _userEmail = email; _userName = _firstName(email); });
    }
  }

  String _firstName(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return 'Chef';
    final stripped = local.replaceAll(RegExp(r'\d+$'), '');
    final name = stripped.isNotEmpty ? stripped : 'Chef';
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  Future<void> _signOut(BuildContext ctx) async {
    await AuthService.signOut();
    if (!ctx.mounted) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    String newPass = '';
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Change Password',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Form(
            key: formKey,
            child: TextFormField(
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'New password (min 8 chars)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? 'Min 8 characters' : null,
              onSaved: (v) => newPass = v ?? '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      formKey.currentState!.save();
                      setDlgState(() => loading = true);
                      final result = await AuthService.changePassword(newPass);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                              result.success
                                  ? 'Password updated!'
                                  : (result.error ?? 'Failed to update password'),
                            ),
                            backgroundColor:
                                result.success ? AppColors.green : Colors.red),
                      );
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preference editors ───────────────────────────────────────────────────────

  Future<void> _editHouseholdSize() async {
    int temp = _householdSize;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Household Size',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
              const SizedBox(height: 4),
              const Text('How many people do you usually cook for?',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CounterBtn(
                    icon: Icons.remove_rounded,
                    onTap: temp > 1 ? () => setS(() => temp--) : null,
                  ),
                  const SizedBox(width: 32),
                  Column(
                    children: [
                      Text('$temp', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'Nunito')),
                      Text(temp == 1 ? 'person' : 'people', style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                    ],
                  ),
                  const SizedBox(width: 32),
                  _CounterBtn(
                    icon: Icons.add_rounded,
                    onTap: temp < 10 ? () => setS(() => temp++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() => _householdSize = temp);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editCookingSkill() async {
    const skills = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Cooking Skill',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
            const SizedBox(height: 4),
            const Text('What best describes your experience in the kitchen?',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 20),
            ...skills.map((s) {
              final isSelected = s == _cookingSkill;
              final color = _skillColor(s);
              return GestureDetector(
                onTap: () {
                  setState(() => _cookingSkill = s);
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? color : const Color(0xFFE8E8E8),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      const SizedBox(width: 14),
                      Text(s,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? color : AppColors.textDark,
                          )),
                      const Spacer(),
                      if (isSelected) Icon(Icons.check_circle_rounded, size: 20, color: color),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _editMaxCookTime() async {
    const times = [15, 30, 45, 60, 90, 120];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Max Cook Time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
            const SizedBox(height: 4),
            const Text('Recipes will be limited to this duration',
                style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: times.map((t) {
                final isSelected = t == _maxCookTime;
                return GestureDetector(
                  onTap: () {
                    setState(() => _maxCookTime = t);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFE8E8E8),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$t min',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _savePreferences() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _client
          .from('users')
          .update({'household_size': _householdSize})
          .eq('id', uid);
      await _client.from('user_preferences').upsert(
        {
          'user_id': uid,
          'cooking_skill': _cookingSkill,
          'max_cook_time': _maxCookTime,
        },
        onConflict: 'user_id',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preferences saved!'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
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
    // Refresh subscription status after returning from paywall
    final prem = await SubscriptionService.isPremium();
    if (mounted) setState(() => _isPremium = prem);
  }

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
              child: Center(
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'Q',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name & email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName.isNotEmpty ? _userName : 'Chef',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _userEmail,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isPremium ? AppColors.accent : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isPremium ? '✨ All Pro' : 'Free Plan',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
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
          _SectionLabel('PREFERENCES'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dietary ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _SubLabel('DIETARY'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: _dietChips.isNotEmpty
                      ? _ChipWrap(chips: _dietChips)
                      : const Text('None set — complete onboarding to add',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                ),
                Divider(height: 1, color: AppColors.divider),
                // ── Cuisine ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _SubLabel('CUISINE'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: _cuisineChips.isNotEmpty
                      ? _ChipWrap(chips: _cuisineChips)
                      : const Text('None set — complete onboarding to add',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                ),
                Divider(height: 1, color: AppColors.divider),
                // ── Household Size ─────────────────────────────────────
                _PrefSettingRow(
                  emoji: '👥',
                  emojiColor: const Color(0xFF5C6BC0),
                  title: 'Household Size',
                  subtitle: 'How many people you cook for',
                  value: '$_householdSize ${_householdSize == 1 ? "person" : "people"}',
                  onTap: _editHouseholdSize,
                ),
                Divider(height: 1, indent: 54, color: AppColors.divider),
                // ── Cooking Skill ──────────────────────────────────────
                _PrefSettingRow(
                  emoji: '🍳',
                  emojiColor: const Color(0xFFFF9800),
                  title: 'Cooking Skill',
                  subtitle: 'Your experience in the kitchen',
                  value: _cookingSkill,
                  valueColor: _skillColor(_cookingSkill),
                  onTap: _editCookingSkill,
                ),
                Divider(height: 1, indent: 54, color: AppColors.divider),
                // ── Max Cook Time ──────────────────────────────────────
                _PrefSettingRow(
                  emoji: '⏱️',
                  emojiColor: const Color(0xFF009688),
                  title: 'Max Cook Time',
                  subtitle: 'Limit recipes to this duration',
                  value: '$_maxCookTime min',
                  onTap: _editMaxCookTime,
                ),
                // ── Save preferences link ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: GestureDetector(
                    onTap: _savePreferences,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Save preferences',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                      ],
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

  static Color _skillColor(String skill) {
    switch (skill.toLowerCase()) {
      case 'beginner': return const Color(0xFF4CAF50);
      case 'intermediate': return const Color(0xFFFF9800);
      case 'advanced': return const Color(0xFF6C63FF);
      case 'expert': return const Color(0xFFE53935);
      default: return AppColors.textMedium;
    }
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
                  child:                   GestureDetector(
                    onTap: _isPremium ? null : _openPaywall,
                    child: Text(
                      _isPremium ? 'Active ✓' : 'Go Pro',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
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
                  '/year',
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
                // _SettingArrowRow(
                //   icon: Icons.language_rounded,
                //   iconColor: const Color(0xFF2196F3),
                //   title: 'Language',
                //   subtitle: 'Set your preferred language',
                //   trailing: 'English',
                // ),
                // _SettingDivider(),
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
    // Truncate email for display
    final shortEmail = _userEmail.length > 22
        ? '${_userEmail.substring(0, 22)}...'
        : _userEmail;

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
                // Change Password — email/password users only
                if (_isEmailLogin) ...[
                  GestureDetector(
                    onTap: _showChangePasswordDialog,
                    behavior: HitTestBehavior.opaque,
                    child: _AccountRow(
                      iconWidget: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF9C27B0)),
                      iconBg: const Color(0xFFF3E5F5),
                      title: 'Change Password',
                      subtitle: 'Last changed 3 months ago',
                    ),
                  ),
                  _SettingDivider(),
                ],
                // Google
                _AccountRow(
                  iconWidget: Image.asset(
                    'assets/icons/google.png',
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) => const Text('G',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                  ),
                  iconBg: const Color(0xFFE8F0FE),
                  title: 'Google',
                  subtitle: _googleConnected ? shortEmail : 'Not connected',
                  badge: _googleConnected ? _ConnectedBadge() : _ConnectBadge(),
                ),
                _SettingDivider(),
                // Apple ID
                _AccountRow(
                  iconWidget: Image.asset(
                    'assets/icons/apple.png',
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) => const Icon(Icons.apple_rounded, size: 18, color: Colors.white),
                  ),
                  iconBg: const Color(0xFF212121),
                  title: 'Apple ID',
                  subtitle: _appleConnected ? shortEmail : 'Not connected',
                  badge: _appleConnected ? _ConnectedBadge() : _ConnectBadge(),
                ),
                // Two-Factor Authentication — email/password users only
                if (_isEmailLogin) ...[
                  _SettingDivider(),
                  _SettingToggleRow(
                    icon: Icons.fingerprint_rounded,
                    iconColor: const Color(0xFFE91E63),
                    title: 'Two-Factor Authentication',
                    subtitle: 'Extra layer of account security',
                    value: _twoFactor,
                    onChanged: (v) => setState(() => _twoFactor = v),
                  ),
                ],
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
        onTap: () => _signOut(context),
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

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CounterBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFFF0F0F0),
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE0E0E0)),
        ),
        child: Icon(icon, size: 22, color: enabled ? AppColors.primary : const Color(0xFFBDBDBD)),
      ),
    );
  }
}

class _PrefSettingRow extends StatelessWidget {
  final String emoji;
  final Color emojiColor;
  final String title;
  final String subtitle;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _PrefSettingRow({
    required this.emoji,
    required this.emojiColor,
    required this.title,
    required this.subtitle,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: emojiColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
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
            Text(value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textMedium,
                )),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textLight),
          ],
        ),
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

// ── Account row ───────────────────────────────────────────────────────────────

class _AccountRow extends StatelessWidget {
  final Widget iconWidget;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? badge;

  const _AccountRow({
    required this.iconWidget,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: iconWidget),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
          if (badge != null) ...[badge!, const SizedBox(width: 6)],
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textLight),
        ],
      ),
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Connected',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32)),
      ),
    );
  }
}

class _ConnectBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Text(
        'Connect',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMedium),
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
