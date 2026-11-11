import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract class TelemetryService {
  Future<void> identify(String? uid);
  Future<void> event(String name, [Map<String, Object> parameters = const {}]);
  Future<void> error(Object error, StackTrace stack, String operation);
  void testCrash();
}

class FirebaseTelemetryService implements TelemetryService {
  FirebaseTelemetryService(this.analytics, this.crashlytics);
  final FirebaseAnalytics analytics;
  final FirebaseCrashlytics? crashlytics;
  @override
  Future<void> identify(String? uid) async {
    await analytics.setUserId(id: uid);
    await crashlytics?.setUserIdentifier(uid ?? '');
    await crashlytics?.setCustomKey('app_area', 'fap_attendance');
  }

  @override
  Future<void> event(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async {
    try {
      await analytics.logEvent(
        name: name,
        parameters: parameters.isEmpty ? null : parameters,
      );
    } catch (_) {
      /* Analytics must not invalidate a persisted user action. */
    }
  }

  @override
  Future<void> error(Object error, StackTrace stack, String operation) async {
    try {
      await crashlytics?.setCustomKey('operation', operation);
      // Import failures can contain roster values. Only send the operation/type.
      await crashlytics?.recordError(
        StateError('$operation: ${error.runtimeType}'),
        stack,
        reason: operation,
        fatal: false,
      );
    } catch (_) {
      debugPrint('Unable to report handled error.');
    }
  }

  @override
  void testCrash() => crashlytics?.crash();
}
