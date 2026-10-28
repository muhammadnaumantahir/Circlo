#!/usr/bin/env bash
# Shared Flutter version detection for Cloudflare builds and focused shell tests.
# Prints the parsed semantic version on stdout and useful diagnostics on failure.
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
