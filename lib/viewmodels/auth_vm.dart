import 'dart:async';

import '../services/auth_service.dart';
import '../services/telemetry_service.dart';
import 'base_vm.dart';

class AuthVm extends BaseVm {
  AuthVm(this.auth, TelemetryService telemetry) : super(telemetry) {
    identity = auth.current;
    _subscription = auth.changes.listen((value) {
      identity = value;
      unawaited(telemetry.identify(value?.uid).catchError((_) {}));
      changed();
    });
  }
  final AuthService auth;
  Identity? identity;
  late final StreamSubscription<Identity?> _subscription;
  Future<bool> signIn() => perform('sign_in', () async {
    await auth.signIn();
    await telemetry.event('login', {'method': 'google'});
  });
  Future<bool> signOut(Future<void> Function() clearData) =>
      perform('sign_out', () async {
        await clearData();
        await telemetry.event('logout');
        await auth.signOut();
        await telemetry.identify(null);
      });
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
