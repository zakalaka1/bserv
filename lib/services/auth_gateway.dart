class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.isAdmin,
    this.userId,
  });

  const AuthState.signedOut()
    : isAuthenticated = false,
      isAdmin = false,
      userId = null;

  final bool isAuthenticated;
  final bool isAdmin;

  /// The signed-in user's id, or null while signed out. Per-user documents
  /// (such as the layout preferences) are keyed by it.
  final String? userId;
}

abstract interface class AuthGateway {
  AuthState get currentState;

  Stream<AuthState> get authStateChanges;

  Future<void> signInWithGoogle();

  Future<void> signInWithFacebook();

  Future<bool> signInAsAdmin({required String email, required String password});

  Future<void> signOut();
}
