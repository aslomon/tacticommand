#!/bin/bash
# Resolves the configured or persistent local code-signing identity.
set -euo pipefail

CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME="Creator Micro Control Local Development"

resolve_creator_micro_signing_identity() {
    local configured_identity="${CREATOR_MICRO_SIGNING_IDENTITY:-}"
    if [[ -n "$configured_identity" ]]; then
        printf '%s\n' "$configured_identity"
        return
    fi
    if security find-identity -v -p codesigning 2>/dev/null \
        | grep -F "\"$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME\"" >/dev/null; then
        printf '%s\n' "$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME"
        return
    fi
    printf '%s\n' '-'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    resolve_creator_micro_signing_identity
fi
