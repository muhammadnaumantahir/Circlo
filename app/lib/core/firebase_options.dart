import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public Firebase client configuration for Circlo.
/// These values identify the Firebase project/apps; never place service-account
/// credentials or FCM server keys in this file.
class CircloFirebase {
  // Web app configuration. Cloudflare can override these using --dart-define.
  static const _apiKeyWeb = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDXV4L9DPgLB-LiTtXXIu38_d6Q47QQ3KU',
  );
  static const _appIdWeb = String.fromEnvironment(
    'FIREBASE_APP_ID_WEB',
    defaultValue: '1:797576707965:web:b5cde9db1f2cf642f01614',
  );

  // Native app configuration from Firebase Console's Android/iOS app registrations.
  // Cloud build or local builds can override these at compile time.
  static const _apiKeyAndroid = String.fromEnvironment(
    'FIREBASE_API_KEY_ANDROID',
    defaultValue: 'AIzaSyDeb8QAPTjUFFIg8iC0wcfPnF88BhE0AWo',
  );
  static const _appIdAndroid = String.fromEnvironment(
    'FIREBASE_APP_ID_ANDROID',
    defaultValue: '1:797576707965:android:91b519b7fed24a2cf01614',
  );
  static const _apiKeyIos = String.fromEnvironment(
    'FIREBASE_API_KEY_IOS',
    defaultValue: 'AIzaSyCqrD4cl_qBvrTXqgX7MJwpa79Km_6aVVs',
  );
  static const _appIdIos = String.fromEnvironment(
    'FIREBASE_APP_ID_IOS',
    defaultValue: '1:797576707965:ios:31aadbebe4efc19ef01614',
  );

  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'circlo-1dbda',
  );
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '797576707965',
  );
  static const _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'circlo-1dbda.firebaseapp.com',
  );

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

  static String get _apiKey {
    if (kIsWeb) return _apiKeyWeb;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _apiKeyAndroid;
      case TargetPlatform.iOS:
        return _apiKeyIos;
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
        authDomain: kIsWeb && _authDomain.isNotEmpty ? _authDomain : null,
        iosBundleId: defaultTargetPlatform == TargetPlatform.iOS ? 'com.circlo.app' : null,
      );
}
