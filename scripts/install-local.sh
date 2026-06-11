#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Dictator-md"
APP_BUNDLE="$ROOT/build/$APP_NAME.app"
DEST="/Applications/$APP_NAME.app"
EXECUTABLE="$DEST/Contents/MacOS/DictatorMD"
SIGN_ID="Dictator-md Stable Local"
SIGN_CERT_SHA1="27fa31bc47861d4efe41f0f60e5f3a3fbdc6b1bc"
LOG="$HOME/Library/Application Support/Dictator-md/Logs/debug.log"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cd "$ROOT"

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing build app: $APP_BUNDLE" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_BUNDLE"
if codesign -dv "$APP_BUNDLE" 2>&1 | grep -q 'flags=0x2(adhoc)'; then
  echo "Refusing to install ad-hoc signed app; this breaks Accessibility grants." >&2
  exit 1
fi
if ! codesign -d -r- "$APP_BUNDLE" 2>&1 | grep -q "certificate leaf = H\"$SIGN_CERT_SHA1\""; then
  echo "Refusing to install app not signed by stable certificate '$SIGN_ID'." >&2
  codesign -dv "$APP_BUNDLE" 2>&1 | sed -n '1,80p' >&2
  exit 1
fi

pkill -f "$EXECUTABLE" 2>/dev/null || true

for bundle in \
  com.sampop.WhisperDictation \
  com.sam-pop.WhisperDictation \
  com.dictatormd.WhisperDictation \
  com.whisperdictation.WhisperDictation; do
  tccutil reset Accessibility "$bundle" 2>/dev/null || true
  tccutil reset Microphone "$bundle" 2>/dev/null || true
done

rm -rf /Applications/DictatorMD.app /Applications/WhisperDictation.app
rm -rf "$HOME/Applications/DictatorMD.app" "$HOME/Applications/WhisperDictation.app"
rm -rf "$DEST"

cp -R "$APP_BUNDLE" "$DEST"
xattr -cr "$DEST"
touch "$DEST"
touch "$DEST/Contents/Info.plist"
touch "$DEST/Contents/Resources/AppIcon.icns"

"$LSREGISTER" -u /Applications/DictatorMD.app 2>/dev/null || true
"$LSREGISTER" -u /Applications/WhisperDictation.app 2>/dev/null || true
"$LSREGISTER" -u "$ROOT/build/DictatorMD.app" 2>/dev/null || true
"$LSREGISTER" -u "$ROOT/build/WhisperDictation.app" 2>/dev/null || true
"$LSREGISTER" -u "$APP_BUNDLE" 2>/dev/null || true
"$LSREGISTER" -f "$DEST"

rm -rf "$ROOT/build/DictatorMD.app" "$ROOT/build/WhisperDictation.app" "$APP_BUNDLE"

open -na "$DEST"
sleep 6

if [[ -f "$LOG" ]]; then
  tail -40 "$LOG"
fi

echo "Installed $DEST"
