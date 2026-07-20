#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

required_files=(
  core/schemas/dictation-event.schema.json
  core/schemas/user-profile.schema.json
  core/language/language-profiles.json
  core/correction/correction-rules.json
  apps/ios/DictatorMDiOS/Info.plist
  apps/ios/DictatorMDKeyboard/Info.plist
  apps/android/app/src/main/AndroidManifest.xml
  apps/android/app/src/main/java/app/dictatormd/mobile/DictatorKeyboardService.kt
  apps/windows/src/AudioCapture.cpp
  apps/windows/src/DictationPipeline.cpp
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || { echo "Missing platform contract: $file" >&2; exit 1; }
done

plutil -lint \
  apps/ios/DictatorMDiOS/Info.plist \
  apps/ios/DictatorMDKeyboard/Info.plist \
  apps/ios/DictatorMDiOS/DictatorMDiOS.entitlements \
  apps/ios/DictatorMDKeyboard/DictatorMDKeyboard.entitlements >/dev/null

grep -q 'NSMicrophoneUsageDescription' apps/ios/DictatorMDiOS/Info.plist
grep -q 'NSSpeechRecognitionUsageDescription' apps/ios/DictatorMDiOS/Info.plist
grep -q 'group.com.dictatormd.shared' apps/ios/DictatorMDiOS/DictatorMDiOS.entitlements
grep -q 'group.com.dictatormd.shared' apps/ios/DictatorMDKeyboard/DictatorMDKeyboard.entitlements
grep -q 'android.permission.RECORD_AUDIO' apps/android/app/src/main/AndroidManifest.xml
grep -q 'android.permission.BIND_INPUT_METHOD' apps/android/app/src/main/AndroidManifest.xml
grep -q 'InputMethodService' apps/android/app/src/main/java/app/dictatormd/mobile/DictatorKeyboardService.kt
grep -q '"en"' core/language/language-profiles.json
grep -q '"bg"' core/language/language-profiles.json

echo "Platform contracts verified."
