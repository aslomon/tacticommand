#!/bin/bash
# Creates one persistent local code-signing identity for stable macOS permissions.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=Scripts/signing-identity.sh
source "$PROJECT_ROOT/Scripts/signing-identity.sh"

if security find-identity -v -p codesigning 2>/dev/null \
    | grep -F "\"$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME\"" >/dev/null; then
    echo "Local signing identity already exists."
    exit 0
fi

TEMPORARY_DIRECTORY="$(mktemp -d)"
IMPORT_PASSWORD="$(uuidgen | tr -d '-')"
CERTIFICATE="$TEMPORARY_DIRECTORY/certificate.pem"
PRIVATE_KEY="$TEMPORARY_DIRECTORY/private-key.pem"
IDENTITY_ARCHIVE="$TEMPORARY_DIRECTORY/identity.p12"
LOGIN_KEYCHAIN="$(security login-keychain | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')"

cleanup() {
    find "$TEMPORARY_DIRECTORY" -type f -delete 2>/dev/null || true
    rmdir "$TEMPORARY_DIRECTORY" 2>/dev/null || true
}
trap cleanup EXIT

[[ -f "$LOGIN_KEYCHAIN" ]] || {
    echo "The login keychain was not found: $LOGIN_KEYCHAIN" >&2
    exit 1
}

openssl req \
    -x509 \
    -newkey rsa:3072 \
    -sha256 \
    -days 3650 \
    -nodes \
    -subj "/CN=$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME/O=Local Development/" \
    -addext 'keyUsage=critical,digitalSignature' \
    -addext 'extendedKeyUsage=codeSigning' \
    -addext 'basicConstraints=critical,CA:TRUE' \
    -keyout "$PRIVATE_KEY" \
    -out "$CERTIFICATE" \
    2>/dev/null

openssl pkcs12 \
    -legacy \
    -export \
    -out "$IDENTITY_ARCHIVE" \
    -inkey "$PRIVATE_KEY" \
    -in "$CERTIFICATE" \
    -name "$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME" \
    -passout "pass:$IMPORT_PASSWORD"

security import "$IDENTITY_ARCHIVE" \
    -k "$LOGIN_KEYCHAIN" \
    -P "$IMPORT_PASSWORD" \
    -T /usr/bin/codesign \
    >/dev/null
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$LOGIN_KEYCHAIN" \
    "$CERTIFICATE"

security find-identity -v -p codesigning "$LOGIN_KEYCHAIN" \
    | grep -F "\"$CREATOR_MICRO_LOCAL_SIGNING_IDENTITY_NAME\""
echo "Persistent local signing identity created."
