#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# shellcheck source=tools/flutter_version.sh
source "$ROOT/tools/flutter_version.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/flutter-machine" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" && "$2" == "--machine" ]]; then
  printf '{\n  "frameworkVersion": "3.47.2",\n  "channel": "stable"\n}\n'
else
  printf 'Flutter 3.47.2 • channel stable\n'
fi
MOCK

cat > "$tmp/flutter-ansi" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "--version" && "$2" == "--machine" ]]; then
  echo 'Unknown option: --machine' >&2
  exit 2
fi
printf '\033[1mFlutter\033[0m 3.47.2 • channel stable\n'
MOCK

cat > "$tmp/flutter-fail" <<'MOCK'
#!/usr/bin/env bash
echo 'Dart SDK bootstrap failed (mock diagnostic)' >&2
exit 1
MOCK
chmod +x "$tmp"/flutter-*

[[ "$(flutter_version "$tmp/flutter-machine")" == "3.47.2" ]]
[[ "$(flutter_version "$tmp/flutter-ansi")" == "3.47.2" ]]

if flutter_version "$tmp/flutter-fail" >"$tmp/out" 2>"$tmp/err"; then
  echo "Expected the mocked Flutter command to fail." >&2
  exit 1
fi
grep -q 'Dart SDK bootstrap failed (mock diagnostic)' "$tmp/err"
grep -q 'Flutter could not run its version command' "$tmp/err"

echo "Flutter version detection tests passed (machine JSON, ANSI banner fallback, failure diagnostics)."
