import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_gateway.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  AuthState get currentState {
    final user = _auth.currentUser;
    return AuthState(
      isAuthenticated: user != null,
      isAdmin: false,
      userId: user?.uid,
    );
  }

  @override
  Stream<AuthState> get authStateChanges => _auth.idTokenChanges().asyncMap(
    (user) => _authStateFor(user, refreshToken: false),
  );

  @override
  Future<void> signInWithGoogle() => _signInWithProvider(GoogleAuthProvider());

  @override
  Future<void> signInWithFacebook() =>
      _signInWithProvider(FacebookAuthProvider());

  @override
  Future<bool> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final state = await _authStateFor(credential.user, refreshToken: true);
    if (!state.isAdmin) {
      await _auth.signOut();
      return false;
    }
    return true;
  }

  Future<AuthState> _authStateFor(
    User? user, {
    required bool refreshToken,
  }) async {
    if (user == null) {
      return const AuthState.signedOut();
    }

    final token = await user.getIdTokenResult(refreshToken);
    return AuthState(
      isAuthenticated: true,
      isAdmin: token.claims?['admin'] == true,
      userId: user.uid,
    );
  }

  Future<void> _signInWithProvider(AuthProvider provider) async {
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
      return;
    }

    await _auth.signInWithProvider(provider);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
