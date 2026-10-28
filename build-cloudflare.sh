#!/usr/bin/env bash
set -euo pipefail

# Cloudflare Pages expects the same root output directory as FinMate and Stockly:
# build/web. The Flutter project itself lives in ./app.

FLUTTER_VERSION="3.47.2"
FLUTTER_DIR="/tmp/flutter"
FLUTTER_REPO="https://github.com/flutter/flutter.git"

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

# Firebase web configuration is supplied through Cloudflare Pages environment variables.
# These values are client configuration, not service-account secrets. Missing values
# leave the app on its setup screen so the web build can still be tested before setup.
flutter build web --release \
  --dart-define="FIREBASE_API_KEY=${FIREBASE_API_KEY:-}" \
  --dart-define="FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-}" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID:-}" \
  --dart-define="FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define="FIREBASE_APP_ID_WEB=${FIREBASE_APP_ID_WEB:-}"

# Publish at repository-root build/web to match the other apps.
mkdir -p ../build
rm -rf ../build/web
cp -R build/web ../build/web

test -f ../build/web/index.html
echo "Cloudflare output ready: build/web"
