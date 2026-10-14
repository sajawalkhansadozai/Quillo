import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the OS Settings page for this app (BlindSpots 2.7).
Future<bool> openSystemAppSettings() async {
  try {
    final opened = await openAppSettings();
    if (opened) return true;
  } catch (e) {
    debugPrint('openAppSettings failed: $e');
  }

  // Fallbacks when the plugin cannot open Settings.
  try {
    if (Platform.isIOS) {
      return launchUrl(Uri.parse('app-settings:'));
    }
    if (Platform.isAndroid) {
      return launchUrl(
        Uri.parse('package:com.android.settings'),
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (e) {
    debugPrint('settings URL fallback failed: $e');
  }
  return false;
}

Future<PermissionStatus> requestCameraPermission() => Permission.camera.request();
