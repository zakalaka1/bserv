class AuthState {
  const AuthState({required this.isAuthenticated, required this.isAdmin});

  const AuthState.signedOut() : isAuthenticated = false, isAdmin = false;

  final bool isAuthenticated;
  final bool isAdmin;
}

abstract interface class AuthGateway {
  AuthState get currentState;

  Stream<AuthState> get authStateChanges;

  Future<void> signInWithGoogle();

  Future<void> signInWithFacebook();

  Future<bool> signInAsAdmin({required String email, required String password});

  Future<void> signOut();
}
