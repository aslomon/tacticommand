#!/bin/bash
# Builds TactiCommand.app with App Intents metadata and local signing.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=Scripts/signing-identity.sh
source "$PROJECT_ROOT/Scripts/signing-identity.sh"

BUILD_DIRECTORY="$PROJECT_ROOT/build"
APP="$BUILD_DIRECTORY/TactiCommand.app"
GENERATED_PROJECT="$BUILD_DIRECTORY/GeneratedProject"
DERIVED_DATA="$BUILD_DIRECTORY/DerivedData"
XCODE_APP="$DERIVED_DATA/Build/Products/Release/CreatorMicroControl.app"
STAGING_DIRECTORY=""
BACKUP_APP=""
SIGNING_IDENTITY="$(resolve_creator_micro_signing_identity)"

cleanup() {
    if [[ -n "$BACKUP_APP" && -d "$BACKUP_APP" && ! -e "$APP" ]]; then
        mv "$BACKUP_APP" "$APP" || true
    fi
    if [[ -n "$STAGING_DIRECTORY" && -d "$STAGING_DIRECTORY" ]]; then
        rm -rf "$STAGING_DIRECTORY"
    fi
}

trap cleanup EXIT

command -v xcodegen >/dev/null || {
    echo "xcodegen is required: brew install xcodegen" >&2
    exit 1
}

echo "==> Generating icon"
"$PROJECT_ROOT/Scripts/generate-icons.sh"

echo "==> Generating Xcode project"
mkdir -p "$BUILD_DIRECTORY" "$GENERATED_PROJECT"
xcodegen generate \
    --spec "$PROJECT_ROOT/project.yml" \
    --project "$GENERATED_PROJECT" \
    --project-root "$PROJECT_ROOT" \
    --quiet

echo "==> Building release app"
xcodebuild \
    -quiet \
    -project "$GENERATED_PROJECT/CreatorMicroControl.xcodeproj" \
    -scheme CreatorMicroControl \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    INFOPLIST_FILE="$PROJECT_ROOT/Resources/Info.plist" \
    clean build
[ -d "$XCODE_APP" ] || { echo "App not found: $XCODE_APP" >&2; exit 1; }

echo "==> Assembling app bundle"
STAGING_DIRECTORY="$(mktemp -d "$BUILD_DIRECTORY/.creator-micro-control.XXXXXX")"
STAGED_APP="$STAGING_DIRECTORY/TactiCommand.app"
BACKUP_APP="$STAGING_DIRECTORY/Previous TactiCommand.app"
ditto "$XCODE_APP" "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/Resources/ThirdPartyNotices"
ditto "$PROJECT_ROOT/ThirdPartyNotices/FreeMicro.md" \
    "$STAGED_APP/Contents/Resources/ThirdPartyNotices/FreeMicro.md"

echo "==> Signing app bundle"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "    Using ad-hoc fallback identity"
else
    echo "    Using configured signing identity: $SIGNING_IDENTITY"
fi
"$PROJECT_ROOT/Scripts/sign-app.sh" "$STAGED_APP" "$SIGNING_IDENTITY"

echo "==> Replacing previous app bundle"
if [[ -e "$APP" ]]; then
    [[ -d "$APP" && ! -L "$APP" ]] || {
        echo "Refusing to replace non-directory target: $APP" >&2
        exit 1
    }
    mv "$APP" "$BACKUP_APP"
fi
mv "$STAGED_APP" "$APP"
if [[ -d "$BACKUP_APP" ]]; then
    rm -rf "$BACKUP_APP"
fi
echo "==> Built $APP"
