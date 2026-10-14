import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/observability_config.dart';

/// BlindSpots 9.1 / 2.8 — Sentry must never block or crash app launch.
class CrashReportingService {
  CrashReportingService._();

  static bool _ready = false;

  static bool get isReady => _ready;

  static Future<void> initialise() async {
    if (!ObservabilityConfig.sentryEnabled) return;
    try {
      await SentryFlutter.init((options) {
        options.dsn = ObservabilityConfig.sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'debug';
        options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
        options.sendDefaultPii = false;
      });
      _ready = true;
    } catch (e, st) {
      debugPrint('Sentry init failed (app continues): $e\n$st');
    }
  }

  static Future<void> capture(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, Object>? extras,
  }) async {
    if (!_ready) return;
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) scope.setTag('context', context);
          extras?.forEach((key, value) => scope.setContexts(key, value));
        },
      );
    } catch (_) {}
  }
}
