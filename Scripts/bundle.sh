#!/usr/bin/env bash
# bundle.sh – assembles Accessgram.app from a compiled binary and TDLib.
# Usage: ./Scripts/bundle.sh <binary_path> <build_number>
set -euo pipefail

BINARY="${1:-.build/release/Accessgram}"
BUILD_NUMBER="${2:-0}"
TDLIB_DIR="$(brew --prefix)/lib"
APP="Accessgram.app"

echo "▶ Assembling $APP (build $BUILD_NUMBER)"

# ── Directory structure ──────────────────────────────────────────────────────
MACOS="$APP/Contents/MacOS"
FRAMEWORKS="$APP/Contents/Frameworks"
RESOURCES="$APP/Contents/Resources"
rm -rf "$APP"
mkdir -p "$MACOS" "$FRAMEWORKS" "$RESOURCES"

# ── Binary ───────────────────────────────────────────────────────────────────
cp "$BINARY" "$MACOS/Accessgram"
chmod +x "$MACOS/Accessgram"

# ── Info.plist ───────────────────────────────────────────────────────────────
cp "Sources/Accessgram/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion $BUILD_NUMBER" \
    "$APP/Contents/Info.plist"

# ── Embed TDLib ──────────────────────────────────────────────────────────────
TDLIB_SRC=$(find "$TDLIB_DIR" -name "libtdjson.*.dylib" | sort -V | tail -1)
if [ -z "$TDLIB_SRC" ]; then
    TDLIB_SRC="$TDLIB_DIR/libtdjson.dylib"
fi
echo "  Embedding TDLib: $TDLIB_SRC"
cp "$TDLIB_SRC" "$FRAMEWORKS/libtdjson.dylib"
chmod 755 "$FRAMEWORKS/libtdjson.dylib"

# Fix rpath so the binary resolves the dylib from its embedded location
ORIGINAL=$(otool -L "$MACOS/Accessgram" | awk '/tdjson/{print $1}' | head -1)
if [ -n "$ORIGINAL" ]; then
    echo "  Fixing rpath: $ORIGINAL → @executable_path/../Frameworks/libtdjson.dylib"
    install_name_tool \
        -change "$ORIGINAL" "@executable_path/../Frameworks/libtdjson.dylib" \
        "$MACOS/Accessgram"
fi

# Also fix the dylib's own id so codesign is happy
install_name_tool -id "@executable_path/../Frameworks/libtdjson.dylib" \
    "$FRAMEWORKS/libtdjson.dylib" 2>/dev/null || true

# ── Ad-hoc codesign ──────────────────────────────────────────────────────────
echo "  Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "✅ $APP ready"
