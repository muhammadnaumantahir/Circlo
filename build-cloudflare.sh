#!/usr/bin/env bash
set -euo pipefail

# Cloudflare Pages expects the same root output directory as FinMate and Stockly:
# build/web. The Flutter project itself lives in ./app.

FLUTTER_VERSION="3.47.2"
FLUTTER_DIR="/tmp/flutter"
FLUTTER_REPO="https://github.com/flutter/flutter.git"

# Firebase Web app configuration. These are client-side Firebase config values,
# not service-account credentials. Cloudflare environment variables may override them.
FIREBASE_API_KEY="${FIREBASE_API_KEY:-AIzaSyDXV4L9DPgLB-LiTtXXIu38_d6Q47QQ3KU}"
FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-circlo-1dbda}"
FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-797576707965}"
FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-circlo-1dbda.firebaseapp.com}"
FIREBASE_APP_ID_WEB="${FIREBASE_APP_ID_WEB:-1:797576707965:web:b5cde9db1f2cf642f01614}"

# Cloudflare's network occasionally drops the large Flutter Git transfer.
# Force HTTP/1.1 and retry cleanly rather than failing on the first disconnect.
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  rm -rf "${FLUTTER_DIR}"
  cloned=false
  for attempt in 1 2 3; do
    echo "Downloading Flutter ${FLUTTER_VERSION} (attempt ${attempt}/3)..."
    rm -rf "${FLUTTER_DIR}"
    if git -c http.version=HTTP/1.1 clone --depth 1 --single-branch --branch "${FLUTTER_VERSION}" "${FLUTTER_REPO}" "${FLUTTER_DIR}"; then
      cloned=true
      break
    fi
    echo "Flutter download attempt ${attempt} failed."
    sleep 3
  done
  if [ "${cloned}" != true ]; then
    echo "ERROR: Could not download Flutter SDK after 3 attempts."
    exit 1
  fi
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --enable-web

cd "$(dirname "$0")/app"

# Generate web platform files in Cloudflare's temporary build checkout.
flutter create . --platforms=web
flutter pub get

# Pass Firebase values into Flutter at compile time. Analytics is not used by
# the current Flutter app, so measurementId is intentionally not required here.
flutter build web --release \
  --dart-define="FIREBASE_API_KEY=${FIREBASE_API_KEY}" \
  --dart-define="FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}" \
  --dart-define="FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}" \
  --dart-define="FIREBASE_APP_ID_WEB=${FIREBASE_APP_ID_WEB}"

# Publish at repository-root build/web to match the other apps.
mkdir -p ../build
rm -rf ../build/web
cp -R build/web ../build/web

test -f ../build/web/index.html
echo "Cloudflare output ready: build/web"
