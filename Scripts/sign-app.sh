#!/bin/bash
# Signs TactiCommand from the innermost code outward.
set -euo pipefail

sign_creator_micro_app() {
    local app_path="$1"
    local signing_identity="${2:--}"
    local core_framework="$app_path/Contents/Frameworks/CreatorMicroCore.framework"

    [[ -d "$app_path" && ! -L "$app_path" ]] || {
        echo "App bundle is not a directory: $app_path" >&2
        return 1
    }
    [[ -d "$core_framework" && ! -L "$core_framework" ]] || {
        echo "Nested framework is missing: $core_framework" >&2
        return 1
    }
    [[ -n "$signing_identity" ]] || signing_identity="-"

    codesign --force --sign "$signing_identity" "$core_framework"
    codesign --force --sign "$signing_identity" "$app_path"
    codesign --verify --deep --strict --verbose=2 "$app_path"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        echo "Usage: $0 <app-path> [signing-identity]" >&2
        exit 64
    fi
    sign_creator_micro_app "$1" "${2:--}"
fi
