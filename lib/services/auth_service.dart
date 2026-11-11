import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/workspace.dart';

class Identity {
  const Identity(this.uid, this.email);
  final String uid, email;
}

abstract class AuthService {
  Stream<Identity?> get changes;
  Identity? get current;
  Future<void> signIn();
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this.auth);
  final FirebaseAuth auth;
  bool _googleInitialized = false;
  Identity? _identity(User? user) =>
      user == null ? null : Identity(user.uid, user.email ?? '');
  @override
  Identity? get current => _identity(auth.currentUser);
  @override
  Stream<Identity?> get changes => auth.authStateChanges().map(_identity);
  Future<void> initializeGoogle() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
  }

  @override
  Future<void> signIn() async {
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
        return;
      }
      await initializeGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AppFailure(
          'Bạn đã hủy đăng nhập. Có thể thử lại khi sẵn sàng.',
        );
      }
      throw const AppFailure(
        'Không thể đăng nhập Google. Kiểm tra mạng và cấu hình tài khoản.',
      );
    } on FirebaseAuthException catch (e) {
      if ([
        'popup-closed-by-user',
        'cancelled-popup-request',
      ].contains(e.code)) {
        throw const AppFailure('Bạn đã hủy đăng nhập.');
      }
      throw const AppFailure(
        'Đăng nhập chưa thành công. Kiểm tra mạng rồi thử lại.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb && _googleInitialized) await GoogleSignIn.instance.signOut();
    await auth.signOut();
  }
}
