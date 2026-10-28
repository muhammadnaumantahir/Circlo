# Google Sign-In setup for Circlo

Circlo now uses **Firebase Authentication** as the source of truth for Google sign-in. The app uses Firebase's popup provider on web and google_sign_in 7.x plus a Google ID token exchanged for a Firebase credential on Android/iOS.

The application code is committed, but the provider and OAuth client IDs must be enabled/configured in your Firebase project before sign-in can succeed on a deployed site or native device.

## 1. Enable Google in Firebase Authentication

1. Open Firebase Console and select project **circlo-1dbda** (or the project used by your deployment).
2. Go to **Authentication → Sign-in method** (or **Sign-in providers**) and enable **Google**.
3. Set the support email and save.
4. Under **Authentication → Settings → Authorized domains**, add the exact hostname you use for Cloudflare Pages and any custom domain. Do not include the protocol or a path. The Firebase *.firebaseapp.com auth domain is separate from your deployed Pages hostname.
5. Confirm that the Web app registration exists and Cloudflare Pages defines the Firebase web configuration variables documented in the README.

On web, Circlo calls FirebaseAuth.signInWithPopup(GoogleAuthProvider()). A domain missing from Firebase's authorized-domain list normally produces an unauthorized-domain error.

## 2. Android OAuth

1. In **Project settings → Your apps**, select the Android app with package name **com.circlo.app**.
2. Add the **SHA-1 and SHA-256** fingerprints for every signing key you use. Add the debug key for local tests and release/Play signing fingerprints before release.
3. With Google enabled, download the refreshed google-services.json from Firebase. The OAuth configuration should include a **Web client** (oauth_client entry where client_type is 3); the Google ID token needs this server audience.
4. Put it at app/android/app/google-services.json. This file is local/generated configuration and must not be committed. The repository .gitignore excludes it.
5. Rerun the helper from the repository root:

       python3 tools/apply_platform_config.py

When the JSON file exists, the helper adds Google Services Gradle plugin 4.5.0 to generated Android Gradle files. If you ran the helper before placing the JSON, run it again. Generate Android folders first using the README setup instructions.

## 3. iOS OAuth

1. In Firebase Project settings, select the iOS app with bundle ID **com.circlo.app** and enable Google authentication.
2. Download GoogleService-Info.plist and place it at app/ios/Runner/GoogleService-Info.plist. Keep it local; do not commit it.
3. Confirm the plist contains CLIENT_ID and REVERSED_CLIENT_ID.
4. Place the refreshed Android google-services.json alongside the generated Android project too, so the helper can read the Web OAuth client ID.
5. Run python3 tools/apply_platform_config.py from the repository root. It writes GIDClientID, GIDServerClientID (when a Web client ID is present), and the reversed client ID callback URL scheme into the generated Runner/Info.plist.

The native files are generated locally and are not committed in Circlo. The helper is idempotent, but a local iOS build is still required to verify the generated Xcode project and callback scheme.

## 4. Circlo profile and privacy behavior

- Google sign-in authenticates through Firebase; application data remains keyed by Firebase UID.
- Google-authenticated users are not forced through email/password verification.
- A **new** Google user still goes to profile setup, where Circlo requires a valid birth year meeting the existing minimum age. Google sign-in does not bypass the age gate.
- The profile's display name is prefilled from the Google account when available; the user can edit it.
- Sign-out clears the Firebase session and then attempts to clear the Google provider session.
- Account deletion asks Google-authenticated users to reauthenticate with Google before any user data is removed.

## 5. Verification checklist

Test in Firebase-backed environments (not only with the Auth emulator):

- [ ] Cloudflare web sign-in opens the Google popup and returns to Circlo.
- [ ] The production and preview domains are authorized as needed.
- [ ] Android debug sign-in returns a Firebase user and opens profile setup for a new user.
- [ ] iOS sign-in returns to the app through the reversed-client-ID URL scheme.
- [ ] Signing out and back in preserves the same Firebase UID/profile.
- [ ] A new Google account still must provide a valid birth year.
- [ ] Google-authenticated account deletion requires a fresh Google reauthentication.
- [ ] Wrong/missing OAuth config produces a useful error instead of a generic silent failure.

**Status:** Source and setup automation added to the feature branch. This environment cannot enable the provider in your Firebase Console or verify real Cloudflare/Android/iOS sign-in. Complete the console configuration above and run a web deployment plus native-device tests before considering Google sign-in release-ready.
