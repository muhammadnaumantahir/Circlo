#!/usr/bin/env python3
"""Apply Circlo's native IDs, permissions and shared Android toolchain versions.

Run from the repo root AFTER `flutter create`. Idempotent and best-effort; generated
platform projects still require a local build and real-device verification.
"""
import json
import plistlib
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "app"
changed = []


def write_if_changed(path: Path, updated: str) -> None:
    source = path.read_text()
    if updated != source:
        path.write_text(updated)
        changed.append(str(path))


def pin_android_toolchain() -> None:
    """Align generated Android Gradle files with the shared sibling-app toolchain."""
    # These versions match the current FinMate/Stockly Android configuration.
    plugin_versions = {
        "com.android.application": "9.4.0",
        "org.jetbrains.kotlin.android": "2.4.10",
        "kotlin-android": "2.4.10",
        "com.google.gms.google-services": "4.5.0",
    }

    settings = next(
        (root / "android" / name for name in ("settings.gradle.kts", "settings.gradle")
         if (root / "android" / name).exists()),
        None,
    )
    if settings is not None:
        source = settings.read_text()
        updated = source
        for plugin_id, version in plugin_versions.items():
            escaped_id = re.escape(plugin_id)
            # Kotlin DSL: id("plugin.id") version "x" apply false
            kts = (
                rf'(?m)^(\s*id\(["\']{escaped_id}["\']\)\s+version\s+["\'])'
                rf'[^"\']+(["\']\s+apply false)'
            )
            updated = re.sub(kts, rf"\g<1>{version}\g<2>", updated)
            # Groovy DSL: id "plugin.id" version "x" apply false
            groovy = (
                rf'(?m)^(\s*id\s+["\']{escaped_id}["\']\s+version\s+["\'])'
                rf'[^"\']+(["\']\s+apply false)'
            )
            updated = re.sub(groovy, rf"\g<1>{version}\g<2>", updated)
        write_if_changed(settings, updated)
    else:
        print("Android Gradle settings not found (run flutter create first)", file=sys.stderr)

    wrapper = root / "android/gradle/wrapper/gradle-wrapper.properties"
    if wrapper.exists():
        source = wrapper.read_text()
        updated = re.sub(
            r"(?m)^distributionUrl=.*gradle-[^/]+-(?:all|bin)\.zip\s*$",
            r"distributionUrl=https\\://services.gradle.org/distributions/gradle-9.8.0-all.zip",
            source,
        )
        write_if_changed(wrapper, updated)

    # Generated templates normally already use Java/JVM 17. Pin it when present,
    # including older generated templates that still carry Java 8/11 targets.
    for name in ("build.gradle.kts", "build.gradle"):
        gradle = root / "android/app" / name
        if not gradle.exists():
            continue
        source = gradle.read_text()
        updated = re.sub(
            r"(?m)^(\s*sourceCompatibility\s*(?:=\s*|\s+))JavaVersion\.VERSION_[A-Z0-9_]+",
            r"\g<1>JavaVersion.VERSION_17",
            source,
        )
        updated = re.sub(
            r"(?m)^(\s*targetCompatibility\s*(?:=\s*|\s+))JavaVersion\.VERSION_[A-Z0-9_]+",
            r"\g<1>JavaVersion.VERSION_17",
            updated,
        )
        updated = re.sub(
            r"(?m)^(\s*jvmTarget\s*=\s*)org\.jetbrains\.kotlin\.gradle\.dsl\.JvmTarget\.JVM_[A-Z0-9_]+",
            r"\g<1>org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17",
            updated,
        )
        updated = re.sub(
            r'(?m)^(\s*jvmTarget\s*=\s*)["\'][^"\']+["\']',
            r'\g<1>"17"',
            updated,
        )
        write_if_changed(gradle, updated)


def _google_web_client_id() -> str | None:
    """Read the web OAuth client ID from a downloaded Google Services JSON."""
    config_path = root / "android/app/google-services.json"
    if not config_path.is_file():
        return None
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"Could not read {config_path}: {exc}", file=sys.stderr)
        return None

    def find_web_client(value):
        if isinstance(value, dict):
            if str(value.get("client_type", "")) == "3" and value.get("client_id"):
                return str(value["client_id"])
            for child in value.values():
                found = find_web_client(child)
                if found:
                    return found
        elif isinstance(value, list):
            for child in value:
                found = find_web_client(child)
                if found:
                    return found
        return None

    return find_web_client(config)


def _ensure_gradle_plugin(path: Path, declaration: str, plugin_id: str) -> bool:
    """Insert a missing plugin declaration in the first flat Gradle plugins block."""
    source = path.read_text(encoding="utf-8")
    if plugin_id in source:
        return False

    match = re.search(r"(?m)^\\s*plugins\\s*\\{", source)
    if match is None:
        updated = source.rstrip() + f"\\n\\nplugins {{\\n    {declaration}\\n}}\\n"
    else:
        opening = source.find("{", match.start())
        depth = 0
        closing = None
        for index in range(opening, len(source)):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    closing = index
                    break
        if closing is None:
            print(f"Could not locate end of plugins block in {path}", file=sys.stderr)
            return False
        updated = source[:closing] + f"    {declaration}\\n" + source[closing:]

    if updated != source:
        path.write_text(updated, encoding="utf-8")
        changed.append(str(path))
        return True
    return False


def configure_android_google_signin() -> None:
    """Apply Google Services only when the user's ignored client JSON is present."""
    google_json = root / "android/app/google-services.json"
    if not google_json.is_file():
        print(
            "Google Sign-In Android setup skipped: add app/android/app/google-services.json "
            "from Firebase Console, then rerun this helper.",
            file=sys.stderr,
        )
        return

    settings = next(
        (root / "android" / name for name in ("settings.gradle.kts", "settings.gradle")
         if (root / "android" / name).exists()),
        None,
    )
    if settings is not None:
        if settings.suffix == ".kts":
            declaration = 'id("com.google.gms.google-services") version "4.5.0" apply false'
        else:
            declaration = 'id "com.google.gms.google-services" version "4.5.0" apply false'
        _ensure_gradle_plugin(settings, declaration, "com.google.gms.google-services")
    else:
        print("Android Gradle settings not found; cannot configure Google Sign-In.", file=sys.stderr)

    app_gradle = next(
        (root / "android/app" / name for name in ("build.gradle.kts", "build.gradle")
         if (root / "android/app" / name).exists()),
        None,
    )
    if app_gradle is not None:
        declaration = (
            'id("com.google.gms.google-services")'
            if app_gradle.suffix == ".kts"
            else "id 'com.google.gms.google-services'"
        )
        _ensure_gradle_plugin(app_gradle, declaration, "com.google.gms.google-services")
    else:
        print("Android app Gradle file not found; cannot apply Google Services.", file=sys.stderr)

    if _google_web_client_id() is None:
        print(
            "Warning: google-services.json has no Web OAuth client (client_type 3). "
            "Enable Google Authentication in Firebase and download the refreshed file, "
            "or native Google Sign-In may not return a Firebase ID token.",
            file=sys.stderr,
        )


def configure_ios_google_signin() -> None:
    """Apply OAuth IDs and callback URL scheme from local Firebase configuration."""
    info_plist = root / "ios/Runner/Info.plist"
    firebase_plist = root / "ios/Runner/GoogleService-Info.plist"
    if not info_plist.is_file():
        return
    if not firebase_plist.is_file():
        print(
            "Google Sign-In iOS setup skipped: add app/ios/Runner/GoogleService-Info.plist "
            "from Firebase Console, then rerun this helper.",
            file=sys.stderr,
        )
        return

    try:
        with firebase_plist.open("rb") as stream:
            firebase_options = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as exc:
        print(f"Could not read {firebase_plist}: {exc}", file=sys.stderr)
        return

    ios_client_id = firebase_options.get("CLIENT_ID")
    reversed_client_id = firebase_options.get("REVERSED_CLIENT_ID")
    web_client_id = _google_web_client_id()
    if not ios_client_id or not reversed_client_id:
        print(
            "Google Sign-In iOS setup skipped: the Firebase plist does not contain OAuth client IDs. "
            "Enable Google Authentication and download the refreshed plist.",
            file=sys.stderr,
        )
        return

    try:
        with info_plist.open("rb") as stream:
            config = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as exc:
        print(f"Could not read {info_plist}: {exc}", file=sys.stderr)
        return

    config["GIDClientID"] = ios_client_id
    if web_client_id:
        config["GIDServerClientID"] = web_client_id

    url_types = config.get("CFBundleURLTypes", [])
    if not isinstance(url_types, list):
        url_types = []
    already_registered = any(
        reversed_client_id in entry.get("CFBundleURLSchemes", [])
        for entry in url_types
        if isinstance(entry, dict) and isinstance(entry.get("CFBundleURLSchemes", []), list)
    )
    if not already_registered:
        url_types.append({
            "CFBundleTypeRole": "Editor",
            "CFBundleURLSchemes": [reversed_client_id],
        })
    config["CFBundleURLTypes"] = url_types

    with info_plist.open("wb") as stream:
        plistlib.dump(config, stream, fmt=plistlib.FMT_XML, sort_keys=False)
    changed.append(str(info_plist))


# ---- Stable native application identifiers ----
# Firebase apps were registered with package/bundle ID com.circlo.app.
for gradle_name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "android/app" / gradle_name
    if gradle.exists():
        source = gradle.read_text()
        updated = re.sub(
            r'(?m)^(\s*namespace\s*=\s*)["\'][^"\']+["\']',
            r'\1"com.circlo.app"',
            source,
        )
        updated = re.sub(
            r'(?m)^(\s*applicationId\s*=\s*)["\'][^"\']+["\']',
            r'\1"com.circlo.app"',
            updated,
        )
        updated = re.sub(
            r'(?m)^(\s*namespace\s+)["\'][^"\']+["\']',
            r'\1"com.circlo.app"',
            updated,
        )
        updated = re.sub(
            r'(?m)^(\s*applicationId\s+)["\'][^"\']+["\']',
            r'\1"com.circlo.app"',
            updated,
        )
        write_if_changed(gradle, updated)
        break

# Keep the Kotlin/Java activity package and folder aligned with applicationId.
for language in ("kotlin", "java"):
    source_root = root / "android/app/src/main" / language
    if not source_root.exists():
        continue
    for activity in list(source_root.rglob("MainActivity.kt")) + list(source_root.rglob("MainActivity.java")):
        source = activity.read_text()
        updated = re.sub(
            r"(?m)^package\s+[A-Za-z_][\w.]*\s*$",
            "package com.circlo.app",
            source,
        )
        target = source_root / "com" / "circlo" / "app" / activity.name
        if updated != source or activity != target:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(updated)
            if activity != target:
                activity.unlink()
            changed.append(str(target))

# Set the iOS app bundle ID to the Firebase registration ID.
pbxproj = root / "ios/Runner.xcodeproj/project.pbxproj"
if pbxproj.exists():
    source = pbxproj.read_text()
    updated = re.sub(
        r"(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)[^;]*\.RunnerTests;",
        r"\1com.circlo.app.RunnerTests;",
        source,
    )
    updated = re.sub(
        r"(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)(?!com\.circlo\.app\.RunnerTests;)[^;]+;",
        r"\1com.circlo.app;",
        updated,
    )
    write_if_changed(pbxproj, updated)

# ---- Android ----
pin_android_toolchain()
configure_android_google_signin()

manifest = root / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    s = manifest.read_text()
    perms = [
        "android.permission.INTERNET",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_LOCATION",
        "android.permission.POST_NOTIFICATIONS",
    ]
    add = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in s)
    if add:
        s = s.replace("<application", add + "    <application", 1)
        manifest.write_text(s)
        changed.append(str(manifest))
else:
    print("Android manifest not found (run flutter create first)", file=sys.stderr)

for name in ("build.gradle.kts", "build.gradle"):
    g = root / "android/app" / name
    if g.exists():
        s = g.read_text()
        n = re.sub(r"minSdk(Version)?\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)
        n = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", n)
        if n != s:
            g.write_text(n)
            changed.append(str(g))

# ---- iOS ----
plist = root / "ios/Runner/Info.plist"
if plist.exists():
    s = plist.read_text()
    entries = ""
    if "NSLocationWhenInUseUsageDescription" not in s:
        entries += ("\t<key>NSLocationWhenInUseUsageDescription</key>\n"
                    "\t<string>Circlo uses your location to show you on the map to the circles you choose.</string>\n")
    if "NSLocationAlwaysAndWhenInUseUsageDescription" not in s:
        entries += ("\t<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>\n"
                    "\t<string>Circlo keeps sharing your location with the circles you choose while the app is in the background. You can pause or stop at any time.</string>\n")
    if "UIBackgroundModes" not in s:
        entries += "\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>location</string>\n\t</array>\n"
    if entries:
        idx = s.rfind("</dict>")
        s = s[:idx] + entries + s[idx:]
        plist.write_text(s)
        changed.append(str(plist))
else:
    print("iOS Info.plist not found (run flutter create first)", file=sys.stderr)

configure_ios_google_signin()

print("Updated:" if changed else "Nothing to change.", *changed, sep="\n  ")
