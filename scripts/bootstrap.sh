#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Install Flutter and add it to PATH first.'; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
flutter create --platforms=android --org com.smartvisionband --project-name wrapper_seed "$tmp/seed"
mkdir -p android/gradle/wrapper
cp "$tmp/seed/android/gradlew" android/gradlew
cp "$tmp/seed/android/gradlew.bat" android/gradlew.bat
cp "$tmp/seed/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/
cp "$tmp/seed/android/local.properties" android/local.properties
chmod +x android/gradlew
flutter pub get
printf '\nBootstrap complete. Run flutter analyze and flutter test.\n'
