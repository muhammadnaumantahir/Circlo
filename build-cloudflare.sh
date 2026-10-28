#!/usr/bin/env bash
set -euo pipefail

# Use the repo's single Flutter SDK pin, shared by local development and CI.
FLUTTER_DIR="/tmp/flutter"
FLUTTER_REPO="https://github.com/flutter/flutter.git"

# Resolve project root regardless of the caller's working directory.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "${SCRIPT_DIR}" && pwd)"
FLUTTER_VERSION="$(sed -nE 's/.*"flutter"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "${ROOT}/app/.fvmrc" | head -n 1)"

if [[ -z "${FLUTTER_VERSION}" ]]; then
  echo "ERROR: Could not read the Flutter SDK pin from ${ROOT}/app/.fvmrc."
  exit 1
fi

flutter_version() {
  local flutter_bin="$1"
  local machine_output="" text_output="" version=""

  # Prefer Flutter's machine-readable version output. Some environments add
  # terminal formatting or extra lines to the human-readable banner.
  if machine_output="$("$flutter_bin" --version --machine 2>&1)"; then
    version="$(printf '%s\n' "$machine_output" |
      sed -nE 's/.*"frameworkVersion"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' |
      head -n 1)"
    if [[ -n "$version" ]]; then
      printf '%s\n' "$version"
      return 0
    fi
  fi

  # Keep compatibility with Flutter builds that do not support --machine.
  if text_output="$("$flutter_bin" --version 2>&1)"; then
    version="$(printf '%s\n' "$text_output" |
      sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g' |
      sed -nE 's/.*Flutter[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+([+-][[:alnum:].+-]+)?).*/\1/p' |
      head -n 1)"
    if [[ -n "$version" ]]; then
      printf '%s\n' "$version"
      return 0
    fi

    printf 'ERROR: Could not parse the Flutter version from %s --version output.\n' "$flutter_bin" >&2
    printf 'Machine output:\n%s\nText output:\n%s\n' "$machine_output" "$text_output" >&2
    return 2
  fi

  printf 'ERROR: Flutter could not run its version command: %s\n' "$flutter_bin" >&2
  if [[ -n "$machine_output" ]]; then
    printf 'Output from --version --machine:\n%s\n' "$machine_output" >&2
  fi
  printf 'Output from --version:\n%s\n' "$text_output" >&2
  return 1
}

# Reuse a PATH installation only when it exactly matches the repository pin.
if command -v flutter >/dev/null 2>&1 && [ "$(flutter_version "$(command -v flutter)")" = "${FLUTTER_VERSION}" ]; then
  echo "Using Flutter ${FLUTTER_VERSION} from PATH."
else
  # Never silently reuse a stale or partially downloaded SDK checkout.
  if [ -x "${FLUTTER_DIR}/bin/flutter" ] && [ "$(flutter_version "${FLUTTER_DIR}/bin/flutter")" != "${FLUTTER_VERSION}" ]; then
    echo "Existing Flutter at ${FLUTTER_DIR} is not ${FLUTTER_VERSION}; replacing it."
    rm -rf "${FLUTTER_DIR}"
  elif [ -e "${FLUTTER_DIR}" ] && [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
    echo "Removing incomplete Flutter checkout at ${FLUTTER_DIR}."
    rm -rf "${FLUTTER_DIR}"
  fi

  if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
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
fi

if ! ACTUAL_FLUTTER_VERSION="$(flutter_version "$(command -v flutter)")"; then
  echo "ERROR: Unable to identify the active Flutter SDK. See the diagnostic output above." >&2
  exit 1
fi
if [ "${ACTUAL_FLUTTER_VERSION}" != "${FLUTTER_VERSION}" ]; then
  echo "ERROR: Expected Flutter ${FLUTTER_VERSION}, found ${ACTUAL_FLUTTER_VERSION}." >&2
  echo "Active Flutter executable: $(command -v flutter)" >&2
  exit 1
fi

echo "Building Circlo with Flutter ${FLUTTER_VERSION}."
flutter config --enable-web

cd "${ROOT}/app"

# Generate web platform files in Cloudflare's temporary build checkout.
flutter create . --platforms=web
flutter pub get

# These Firebase web values are client-side configuration. Cloudflare environment
# variables can override the defaults without changing tracked source files.
FIREBASE_API_KEY="${FIREBASE_API_KEY:-AIzaSyDXV4L9DPgLB-LiTtXXIu38_d6Q47QQ3KU}"
FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-circlo-1dbda}"
FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-797576707965}"
FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-circlo-1dbda.firebaseapp.com}"
FIREBASE_APP_ID_WEB="${FIREBASE_APP_ID_WEB:-1:797576707965:web:b5cde9db1f2cf642f01614}"

flutter build web --release \
  --dart-define="FIREBASE_API_KEY=${FIREBASE_API_KEY}" \
  --dart-define="FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}" \
  --dart-define="FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}" \
  --dart-define="FIREBASE_APP_ID_WEB=${FIREBASE_APP_ID_WEB}"

# Publish at repository-root build/web for Cloudflare Pages.
mkdir -p "${ROOT}/build"
rm -rf "${ROOT}/build/web"
cp -R "${ROOT}/app/build/web" "${ROOT}/build/web"

test -f "${ROOT}/build/web/index.html"
echo "Cloudflare output ready: ${ROOT}/build/web"
