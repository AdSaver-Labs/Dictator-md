#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "core/schemas/dictation-event.schema.json"
  "core/schemas/user-profile.schema.json"
  "core/language/language-profiles.json"
  "core/correction/correction-rules.json"
  "apps/ios/DictatorMDiOS/App/DictatorMDiOSApp.swift"
  "apps/ios/DictatorMDiOS/App/MobileHomeView.swift"
  "apps/ios/DictatorMDiOS/Shared/MobileSharedStore.swift"
  "apps/ios/DictatorMDKeyboard/KeyboardViewController.swift"
  "apps/android/settings.gradle.kts"
  "apps/android/app/build.gradle.kts"
  "apps/android/app/src/main/AndroidManifest.xml"
  "apps/android/app/src/main/java/app/dictatormd/mobile/DictatorKeyboardService.kt"
  "docs/mobile/MOBILE_EXECUTION_PLAN.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required mobile scaffold file: $file" >&2
    exit 1
  fi
done

python3 - <<'PY'
import json
from pathlib import Path

for path in [
    "core/schemas/dictation-event.schema.json",
    "core/schemas/user-profile.schema.json",
    "core/language/language-profiles.json",
    "core/correction/correction-rules.json",
    "schemas/history.schema.json",
    "schemas/settings.schema.json",
]:
    with Path(path).open("r", encoding="utf-8") as handle:
        json.load(handle)

print("Mobile scaffolds and shared JSON contracts verified.")
PY

