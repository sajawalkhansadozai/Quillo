import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../navigation/app_navigator.dart';
import '../screens/paywall_screen.dart';
import '../screens/Home/scan_screen.dart';
import '../screens/food_waste/food_waste_dashboard_screen.dart';
import '../services/auth_service.dart';

/// Handles quillo://scan, quillo://premium, quillo://waste deep links.
class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static DeepLinkTarget? _pending;

  static Future<void> initialise() async {
    if (kIsWeb) return;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _pending = _parse(initial);
      }
      _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
    } catch (e) {
      debugPrint('DeepLinkService init failed: $e');
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Call from [MainShell] once the home shell is mounted.
  static void consumePendingIfAny() {
    final target = _pending;
    if (target == null) return;
    _pending = null;
    _navigate(target);
  }

  static void _handleUri(Uri uri) {
    // Let supabase_flutter exchange PKCE / implicit tokens for a session.
    if (_isAuthCallback(uri)) return;

    final target = _parse(uri);
    if (target == null) return;
    if (appNavigator == null) {
      _pending = target;
      return;
    }
    _navigate(target);
  }

  static bool _isAuthCallback(Uri uri) {
    final q = uri.queryParameters;
    if (q.containsKey('code') || q.containsKey('access_token')) return true;
    final frag = uri.fragment;
    return frag.contains('access_token') || frag.contains('error_description');
  }

  static DeepLinkTarget? _parse(Uri uri) {
    if (uri.scheme != 'quillo') return null;
    final host = uri.host.toLowerCase();
    final path = uri.path.replaceFirst('/', '').toLowerCase();
    final segment = host.isNotEmpty ? host : path;
    switch (segment) {
      case 'scan':
        return DeepLinkTarget.scan;
      case 'premium':
      case 'pro':
        return DeepLinkTarget.premium;
      case 'waste':
      case 'foodwaste':
      case 'impact':
        return DeepLinkTarget.waste;
      case 'home':
      case 'confirmed':
      case 'auth':
        return DeepLinkTarget.home;
      default:
        return null;
    }
  }

  static void _navigate(DeepLinkTarget target) {
    if (!AuthService.isSignedIn) {
      _pending = target;
      return;
    }
    final nav = appNavigator;
    if (nav == null) {
      _pending = target;
      return;
    }

    switch (target) {
      case DeepLinkTarget.scan:
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ScanScreen(),
          ),
        );
      case DeepLinkTarget.premium:
        nav.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const PaywallScreen(),
          ),
        );
      case DeepLinkTarget.waste:
        nav.push(
          MaterialPageRoute(
            builder: (_) => const FoodWasteDashboardScreen(),
          ),
        );
      case DeepLinkTarget.home:
        nav.pushNamedAndRemoveUntil('/', (_) => false);
    }
  }
}

enum DeepLinkTarget { scan, premium, waste, home }
