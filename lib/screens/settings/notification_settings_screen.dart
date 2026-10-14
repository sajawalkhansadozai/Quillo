import 'package:flutter/material.dart';
import '../../services/notification_prefs_service.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_theme.dart';

/// Balanced §06.1 — individual toggles for the 3 push types.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _master = true;
  bool _expiry = true;
  bool _streak = true;
  bool _milestone = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = await NotificationPrefsService.load();
    if (!mounted) return;
    setState(() {
      _master = map['master']!;
      _expiry = map['expiry']!;
      _streak = map['streak']!;
      _milestone = map['milestone']!;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _card([
                  _toggle(
                    title: 'Push notifications',
                    subtitle: 'Master switch for all Quillo pushes',
                    value: _master,
                    onChanged: (v) async {
                      setState(() => _master = v);
                      await NotificationPrefsService.setMaster(v);
                      await PushNotificationService.applyOptOut(!v);
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
                  'TYPES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textMedium.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                _card([
                  _toggle(
                    title: 'Ingredient expiry',
                    subtitle: 'Warn when something from your last scan may go off',
                    value: _expiry && _master,
                    onChanged: !_master
                        ? null
                        : (v) async {
                            setState(() => _expiry = v);
                            await NotificationPrefsService.setExpiry(v);
                          },
                  ),
                  const Divider(height: 1),
                  _toggle(
                    title: 'Streak at risk',
                    subtitle: 'Thursday reminder if your week streak needs a scan',
                    value: _streak && _master,
                    onChanged: !_master
                        ? null
                        : (v) async {
                            setState(() => _streak = v);
                            await NotificationPrefsService.setStreak(v);
                          },
                  ),
                  const Divider(height: 1),
                  _toggle(
                    title: 'Milestones',
                    subtitle: 'Celebrate when you hit £50, £100, £250, or £500 saved',
                    value: _milestone && _master,
                    onChanged: !_master
                        ? null
                        : (v) async {
                            setState(() => _milestone = v);
                            await NotificationPrefsService.setMilestone(v);
                          },
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
                  'We never send more than one push per day, and never between 10pm and 8am local time.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textMedium),
      ),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}
