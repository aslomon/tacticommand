#!/bin/bash
# Generates the macOS app icon from the master vector source.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VECTOR_SOURCE="$PROJECT_ROOT/Resources/AppIcon.svg"
SOURCE="$PROJECT_ROOT/Resources/AppIcon.png"
ICONSET="$PROJECT_ROOT/.build/generated-icons/CreatorMicroControl.iconset"
OUTPUT="$PROJECT_ROOT/Resources/CreatorMicroControl.icns"

[ -f "$VECTOR_SOURCE" ] || { echo "Icon source not found: $VECTOR_SOURCE" >&2; exit 1; }

sips -s format png -z 1024 1024 "$VECTOR_SOURCE" --out "$SOURCE" >/dev/null

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

generate_png() {
  local points="$1"
  local scale="$2"
  local pixels=$((points * scale))
  local suffix=""
  if [ "$scale" -eq 2 ]; then
    suffix="@2x"
  fi

  sips -s format png -z "$pixels" "$pixels" "$SOURCE" \
    --out "$ICONSET/icon_${points}x${points}${suffix}.png" >/dev/null
}

for points in 16 32 128 256 512; do
  generate_png "$points" 1
  generate_png "$points" 2
done

iconutil -c icns -o "$OUTPUT" "$ICONSET"
echo "Generated $OUTPUT"
