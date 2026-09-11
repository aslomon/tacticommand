#!/bin/bash
# Verifies signing order and identity selection without touching the Keychain.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_DIRECTORY="$(mktemp -d)"
SIGN_LOG="$TEMP_DIRECTORY/codesign.log"
APP="$TEMP_DIRECTORY/TactiCommand.app"
FRAMEWORK="$APP/Contents/Frameworks/CreatorMicroCore.framework"
TEST_EXIT_CODE=1

cleanup() {
    trap - EXIT
    rm -rf "$TEMP_DIRECTORY"
    exit "$TEST_EXIT_CODE"
}

trap cleanup EXIT

mkdir -p "$FRAMEWORK"

# shellcheck source=Scripts/sign-app.sh
source "$PROJECT_ROOT/Scripts/sign-app.sh"
# shellcheck source=Scripts/signing-identity.sh
source "$PROJECT_ROOT/Scripts/signing-identity.sh"

codesign() {
    local argument
    for argument in "$@"; do
        printf '<%s>' "$argument" >> "$SIGN_LOG"
    done
    printf '\n' >> "$SIGN_LOG"
}

assert_signing_plan() {
    local identity="$1"
    : > "$SIGN_LOG"

    sign_creator_micro_app "$APP" "$identity"

    [[ "$(sed -n '1p' "$SIGN_LOG")" == "<--force><--sign><$identity><$FRAMEWORK>" ]]
    [[ "$(sed -n '2p' "$SIGN_LOG")" == "<--force><--sign><$identity><$APP>" ]]
    [[ "$(sed -n '3p' "$SIGN_LOG")" == "<--verify><--deep><--strict><--verbose=2><$APP>" ]]
    [[ "$(wc -l < "$SIGN_LOG" | tr -d ' ')" == "3" ]]
}

assert_signing_plan "-"
assert_signing_plan "Apple Development: Local Developer (TEAMID1234)"

security() {
    printf '%s\n' "${TEST_IDENTITIES:-}"
}

CREATOR_MICRO_SIGNING_IDENTITY="Developer ID Application: Example (TEAMID1234)"
[[ "$(resolve_creator_micro_signing_identity)" == "$CREATOR_MICRO_SIGNING_IDENTITY" ]]
unset CREATOR_MICRO_SIGNING_IDENTITY

TEST_IDENTITIES="1) ABC \"$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME\""
[[ "$(resolve_creator_micro_signing_identity)" == "$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME" ]]
TEST_IDENTITIES="0 valid identities found"
[[ "$(resolve_creator_micro_signing_identity)" == "-" ]]

grep -Fq 'CREATOR_MICRO_SIGNING_IDENTITY' "$PROJECT_ROOT/Scripts/signing-identity.sh"
grep -Fq 'setup-local-signing.sh' "$PROJECT_ROOT/README.md"
grep -Fq 'Developer ID signing' "$PROJECT_ROOT/README.md"
grep -Fq 'com.creatormicro.control' "$PROJECT_ROOT/docs/INSTALLATION.md"
grep -Fq 'stable self-signed development identity' "$PROJECT_ROOT/README.md"

TEST_EXIT_CODE=0
echo "Signing contract tests passed"
