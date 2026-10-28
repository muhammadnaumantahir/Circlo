#!/usr/bin/env bash
set -euo pipefail

# Cloudflare Pages expects the same root output directory as FinMate and Stockly:
# build/web. The Flutter project itself lives in ./app.

FLUTTER_VERSION="3.47.2"
FLUTTER_DIR="/tmp/flutter"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
flutter config --enable-web

cd "$(dirname "$0")/app"

# Generate web platform files in Cloudflare's temporary build checkout.
flutter create . --platforms=web
flutter pub get
flutter build web --release

# Publish at repository-root build/web to match the other apps.
mkdir -p ../build
rm -rf ../build/web
cp -R build/web ../build/web

test -f ../build/web/index.html
echo "Cloudflare output ready: build/web"
