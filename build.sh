#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Tessel"
BUNDLE_ID="com.chrispeterkins.Tessel"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null

# TCC (Accessibility permission) identifies the app by its code signature.
# Ad-hoc signatures change on every rebuild and silently invalidate the grant,
# so prefer a real identity when one exists.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/"/ {print $2; exit}') || true
fi

if [[ -n "$IDENTITY" ]]; then
  echo "Signing with identity: $IDENTITY"
  codesign --force --options runtime --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
else
  echo "WARNING: No codesigning identity found — falling back to ad-hoc signing."
  echo "         Every rebuild will invalidate the Accessibility permission grant"
  echo "         (remove and re-add the app in System Settings each time)."
  echo "         Fix: in Keychain Access, run Certificate Assistant > 'Create a"
  echo "         Certificate…' with type 'Code Signing' (e.g. named 'Tessel Dev'),"
  echo "         then: export CODESIGN_IDENTITY='Tessel Dev'"
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
fi

codesign --verify "$APP"
echo "Built $APP"
echo "Launch with: open \"$APP\"   (never run the bare binary — TCC attributes the grant wrong)"
