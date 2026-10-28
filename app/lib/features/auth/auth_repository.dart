import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._auth, {GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _googleSignInInitialized = false;

  /// Emits on sign-in/out and whenever the user object is refreshed (e.g. email verified).
  Stream<User?> authStateChanges() => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signUp(String email, String password) =>
      _run(() => _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password));

  Future<void> signIn(String email, String password) => _run(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  /// Signs in with a Google account and exchanges the identity token for a Firebase session.
  /// Returns false when the user closes/cancels the provider flow.
  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
        return true;
      }

      await _ensureGoogleSignInInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthFailure(
          'Google Sign-In is not supported by this platform configuration.',
        );
      }

      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'Google Sign-In did not return an ID token. Check the Firebase OAuth configuration for this app.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      if (result.user == null) {
        throw const AuthFailure('Firebase did not return an authenticated user.');
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) return false;
      throw AuthFailure(_message(e.code));
    } on AuthFailure {
      rethrow;
    } catch (e) {
      if (_isCancellation(e.toString())) return false;
      final detail = e.toString().toLowerCase();
      if (detail.contains('id token') ||
          detail.contains('serverclientid') ||
          detail.contains('client id') ||
          detail.contains('oauth')) {
        throw const AuthFailure(
          'Google Sign-In needs OAuth setup. Enable Google in Firebase Authentication and refresh the Android/iOS client configuration.',
        );
      }
      throw const AuthFailure(
        'Could not sign in with Google. Check your connection and Firebase Google provider setup.',
      );
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  bool get currentUserUsesGoogle =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb && _googleSignInInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // The Firebase session is already closed; provider cleanup is best effort.
      }
    }
  }

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

  /// Re-authenticate an existing Google account before destructive actions.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('You are not signed in.');
    try {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        return;
      }
      await _ensureGoogleSignInInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const AuthFailure(
          'Google re-authentication is not supported by this platform configuration.',
        );
      }
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('Google Sign-In did not return an ID token.');
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on FirebaseAuthException catch (e) {
      if (_isCancellation(e.code)) {
        throw const AuthFailure('Google re-authentication was cancelled.');
      }
      throw AuthFailure(_message(e.code));
    } on AuthFailure {
      rethrow;
    } catch (e) {
      if (_isCancellation(e.toString())) {
        throw const AuthFailure('Google re-authentication was cancelled.');
      }
      throw const AuthFailure(
        'Could not verify your Google account. Check the app OAuth configuration and try again.',
      );
    }
  }

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

  static bool _isCancellation(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('cancel') ||
        normalized == 'popup-closed-by-user' ||
        normalized == 'cancelled-popup-request';
  }

  static String _message(String code) {
    switch (code) {
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Authentication.';
      case 'unauthorized-domain':
        return 'This website is not authorized for Google Sign-In. Add its domain in Firebase Authentication settings.';
      case 'popup-blocked':
        return 'Your browser blocked the Google sign-in window. Allow pop-ups and try again.';
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
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email. Sign in using its existing method first.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
