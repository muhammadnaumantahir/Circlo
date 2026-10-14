import 'package:firebase_auth/firebase_auth.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  /// Emits on sign-in/out and whenever the user object is refreshed (e.g. email verified).
  Stream<User?> authStateChanges() => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signUp(String email, String password) =>
      _run(() => _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password));

  Future<void> signIn(String email, String password) => _run(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  Future<void> signOut() => _auth.signOut();

  Future<void> sendVerificationEmail() => _run(() async {
        final u = _auth.currentUser;
        if (u != null && !u.emailVerified) await u.sendEmailVerification();
      });

  /// Reloads the user and forces a fresh ID token so server rules see email_verified = true.
  Future<bool> refreshVerification() async {
    final u = _auth.currentUser;
    if (u == null) return false;
    await u.reload();
    await _auth.currentUser?.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Required before deleting the account (Firebase wants a recent sign-in).
  Future<void> reauthenticate(String password) => _run(() async {
        final u = _auth.currentUser;
        final email = u?.email;
        if (u == null || email == null) throw const AuthFailure('You are not signed in.');
        await u.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: email, password: password));
      });

  Future<void> deleteAuthUser() => _run(() async {
        await _auth.currentUser?.delete();
      });

  /// Always reports success for unknown addresses (no account enumeration).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw AuthFailure(_message(e.code));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  static String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in.';
      case 'weak-password':
        return 'Choose a stronger password (at least 8 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
