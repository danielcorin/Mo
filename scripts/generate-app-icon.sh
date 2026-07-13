#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Artwork/AppIcon.svg"
DESTINATION="$ROOT/Mo/Assets.xcassets/AppIcon.appiconset"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/mo-icon.XXXXXX")"
TEMP_PNG="$TEMP_DIRECTORY/AppIcon.svg.png"

cleanup() {
    rm -rf "$TEMP_DIRECTORY"
}
trap cleanup EXIT

qlmanage -t -s 1024 -o "$TEMP_DIRECTORY" "$SOURCE" >/dev/null

render() {
    local pixels="$1"
    local filename="$2"
    sips --resampleHeightWidth "$pixels" "$pixels" "$TEMP_PNG" \
        --out "$DESTINATION/$filename" >/dev/null
}

render 16 AppIcon-16.png
render 32 AppIcon-16@2x.png
render 32 AppIcon-32.png
render 64 AppIcon-32@2x.png
render 128 AppIcon-128.png
render 256 AppIcon-128@2x.png
render 256 AppIcon-256.png
render 512 AppIcon-256@2x.png
render 512 AppIcon-512.png
render 1024 AppIcon-512@2x.png

echo "Generated app icon assets in $DESTINATION"
