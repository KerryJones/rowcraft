import 'dart:developer' as dev;

import 'package:sentry_flutter/sentry_flutter.dart';

/// Structured logging for the app.
///
/// - [info]: local log only (visible in `flutter logs` / DevTools).
/// - [warn]: local log at warning level, with optional error object.
/// - [error]: local log + Sentry report. Use for failures that should never
///   happen or that silently lose user data. Sentry no-ops when not
///   initialized (local dev builds).
class AppLog {
  AppLog._();

  static void info(String area, String message) {
    dev.log(message, name: area);
  }

  static void warn(String area, String message, [Object? error]) {
    dev.log(message, name: area, level: 900, error: error);
  }

  static void error(
    String area,
    String message,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    dev.log(message, name: area, level: 1000, error: error, stackTrace: stackTrace);
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) async {
        await scope.setTag('area', area);
        await scope.setContexts('log', {'message': message});
      },
    );
  }
}
