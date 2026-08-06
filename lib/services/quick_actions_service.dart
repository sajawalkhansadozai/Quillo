import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:share_plus/share_plus.dart';
import '../navigation/app_navigator.dart';
import '../screens/support/faq_screen.dart';
import '../screens/support/feedback_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home-screen long-press shortcuts (iOS Quick Actions / Android App Shortcuts)
// ─────────────────────────────────────────────────────────────────────────────

class QuickActionsService {
  QuickActionsService._();

  static const _quickActions = QuickActions();
  static bool _initialized = false;
  static String? _pendingType;

  static const typeFaq = 'faq';
  static const typeBug = 'bug';
  static const typeIdea = 'idea';
  static const typeShare = 'share';

  /// Call once after [MaterialApp] is mounted (navigator key ready).
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _quickActions.initialize((type) {
        _handleShortcut(type);
      });

      await _quickActions.setShortcutItems(const [
        ShortcutItem(
          type: typeFaq,
          localizedTitle: 'Have a question?',
          localizedSubtitle: 'Visit our FAQs',
        ),
        ShortcutItem(
          type: typeBug,
          localizedTitle: 'Bugs or issues?',
          localizedSubtitle: 'Tell us what broke',
        ),
        ShortcutItem(
          type: typeIdea,
          localizedTitle: 'Share an idea',
          localizedSubtitle: 'Tell us how to improve',
        ),
        ShortcutItem(
          type: typeShare,
          localizedTitle: 'Share',
          localizedSubtitle: 'Invite friends to Quillo',
        ),
      ]);

      // Cold start: shortcut may arrive before navigator is ready.
      if (_pendingType != null) {
        final pending = _pendingType;
        _pendingType = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (pending != null) _handleShortcut(pending);
        });
      }
    } catch (e, st) {
      debugPrint('QuickActionsService.initialize failed: $e\n$st');
    }
  }

  static void _handleShortcut(String type) {
    final nav = appNavigator;
    if (nav == null) {
      _pendingType = type;
      // Retry shortly once the first route is up.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (appNavigator != null && _pendingType == type) {
          _pendingType = null;
          _dispatch(type);
        }
      });
      return;
    }
    _dispatch(type);
  }

  static void _dispatch(String type) {
    switch (type) {
      case typeFaq:
        openFaq();
        return;
      case typeBug:
        openBugReport();
        return;
      case typeIdea:
        openIdea();
        return;
      case typeShare:
        shareApp();
        return;
      default:
        debugPrint('Unknown quick action: $type');
    }
  }

  static void openFaq() {
    appNavigator?.push(
      MaterialPageRoute(builder: (_) => const FaqScreen()),
    );
  }

  static void openBugReport() {
    appNavigator?.push(
      MaterialPageRoute(
        builder: (_) => const FeedbackScreen(kind: FeedbackKind.bug),
      ),
    );
  }

  static void openIdea() {
    appNavigator?.push(
      MaterialPageRoute(
        builder: (_) => const FeedbackScreen(kind: FeedbackKind.idea),
      ),
    );
  }

  static Future<void> shareApp() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Check out Quillo — scan your groceries and get recipes that match '
              'what you already have.\nhttps://quillo.app',
          subject: 'Quillo — recipes from your fridge',
        ),
      );
    } catch (e) {
      debugPrint('Share failed: $e');
    }
  }
}
