import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration supplied at build time with --dart-define (see .env.example).
/// No real project values are committed to the repository.
class CircloFirebase {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _appIdWeb = String.fromEnvironment('FIREBASE_APP_ID_WEB');
  static const _appIdAndroid = String.fromEnvironment('FIREBASE_APP_ID_ANDROID');
  static const _appIdIos = String.fromEnvironment('FIREBASE_APP_ID_IOS');

  /// Use the local Firebase Emulator Suite (Auth 9099, Firestore 8080).
  static const bool useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
  static const String emulatorHost =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

  static String get _appId {
    if (kIsWeb) return _appIdWeb;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _appIdAndroid;
      case TargetPlatform.iOS:
        return _appIdIos;
      default:
        return '';
    }
  }

  static bool get isConfigured =>
      _apiKey.isNotEmpty && _projectId.isNotEmpty && _appId.isNotEmpty;

  static FirebaseOptions get currentOptions => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
      );
}
