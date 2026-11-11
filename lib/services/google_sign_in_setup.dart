import 'package:google_sign_in/google_sign_in.dart';

/// The SDK singleton must be initialized exactly once across Auth and Drive.
class GoogleSignInSetup {
  static Future<void>? _initialization;

  static bool get started => _initialization != null;

  static Future<void> ensureInitialized() =>
      _initialization ??= GoogleSignIn.instance.initialize();
}
