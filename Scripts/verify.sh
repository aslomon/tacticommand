#!/bin/bash
# Runs the complete local verification pipeline.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_ROOT/build/TactiCommand.app"
PLIST="$APP/Contents/Info.plist"

cd "$PROJECT_ROOT"

echo "==> Swift format"
xcrun swift-format lint \
    --strict \
    --recursive \
    --configuration "$PROJECT_ROOT/.swift-format" \
    Sources Tests

echo "==> Strict build"
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors

echo "==> Unit tests"
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors

echo "==> Build signing contract"
"$PROJECT_ROOT/Scripts/test-build-signing.sh"

echo "==> App bundle"
"$PROJECT_ROOT/Scripts/build-app.sh"

echo "==> Bundle metadata"
plutil -lint "$PROJECT_ROOT/Resources/Info.plist" "$PLIST"
/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$PLIST" | grep -qx "false"
/usr/libexec/PlistBuddy -c "Print :LSMultipleInstancesProhibited" "$PLIST" \
    | grep -qx "true"
/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$PLIST" | grep -qx "CreatorMicroControl"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST" \
    | grep -qx "com.creatormicro.control"
expected_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
expected_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" \
    | grep -qx "$expected_version"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" \
    | grep -qx "$expected_build"

echo "==> Bundle architecture and notices"
lipo "$APP/Contents/MacOS/CreatorMicroControl" -verify_arch arm64 x86_64
[ -f "$APP/Contents/Resources/ThirdPartyNotices/FreeMicro.md" ]

echo "==> App Intents metadata"
METADATA="$APP/Contents/Resources/Metadata.appintents"
[ -d "$METADATA" ] || { echo "Missing App Intents metadata: $METADATA" >&2; exit 1; }
[ -n "$(find "$METADATA" -type f -print -quit)" ] || {
    echo "App Intents metadata is empty: $METADATA" >&2
    exit 1
}

echo "==> Code signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Verification passed"
