#!/usr/bin/env bash
# bundle.sh – assembles Accessgram.app from a compiled binary and TDLib.
# Usage: ./Scripts/bundle.sh <binary_path> <build_number>
set -euo pipefail

BINARY="${1:-.build/release/Accessgram}"
BUILD_NUMBER="${2:-0}"
TDLIB_DIR="$(brew --prefix)/lib"
APP="Accessgram.app"
MACOS="$APP/Contents/MacOS"
FRAMEWORKS="$APP/Contents/Frameworks"
RESOURCES="$APP/Contents/Resources"

echo "▶ Assembling $APP (build $BUILD_NUMBER)"
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

# ── Recursive dylib embedder ─────────────────────────────────────────────────
# Copies a Homebrew dylib + all its Homebrew transitive deps into Frameworks/,
# then rewrites every /opt/homebrew/… reference to @executable_path/../Frameworks/…
embed_dylib() {
    local src="$1"
    local name
    name=$(basename "$src")
    local dest="$FRAMEWORKS/$name"

    # Already embedded – nothing to do.
    [ -f "$dest" ] && return 0

    # Resolve symlink to get the real file on disk.
    local real_src
    real_src=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$src" 2>/dev/null || echo "$src")
    if [ ! -f "$real_src" ]; then
        echo "  ⚠️  Cannot find: $src – skipping"
        return 0
    fi

    echo "  Embedding: $name"
    cp "$real_src" "$dest"
    chmod 755 "$dest"

    # Reset the dylib's own id to its embedded location.
    install_name_tool -id "@executable_path/../Frameworks/$name" "$dest"

    # Walk all dependencies reported by otool; embed and relink Homebrew ones.
    while IFS= read -r dep; do
        [[ "$dep" == /opt/homebrew/* ]] || continue
        local dep_name
        dep_name=$(basename "$dep")

        # Recurse first so the dep is present before we rewrite our reference.
        embed_dylib "$dep"

        install_name_tool \
            -change "$dep" \
            "@executable_path/../Frameworks/$dep_name" \
            "$dest" 2>/dev/null || true
    done < <(otool -L "$dest" 2>/dev/null | awk 'NR>1 {print $1}')
}

# ── Embed TDLib and its transitive Homebrew dependencies ─────────────────────
TDLIB_SRC=$(find "$TDLIB_DIR" -name "libtdjson.*.dylib" 2>/dev/null | sort -V | tail -1)
[ -z "$TDLIB_SRC" ] && TDLIB_SRC="$TDLIB_DIR/libtdjson.dylib"
echo "  Embedding TDLib: $TDLIB_SRC"
embed_dylib "$TDLIB_SRC"

# ── Fix the main binary's reference to libtdjson ─────────────────────────────
ORIGINAL=$(otool -L "$MACOS/Accessgram" | awk '/tdjson/ {print $1}' | head -1)
if [ -n "$ORIGINAL" ]; then
    echo "  Fixing rpath: $ORIGINAL → @executable_path/../Frameworks/libtdjson.dylib"
    install_name_tool \
        -change "$ORIGINAL" \
        "@executable_path/../Frameworks/libtdjson.dylib" \
        "$MACOS/Accessgram"
fi

# ── Second pass: relink any remaining /opt/homebrew paths in all embedded dylibs
# (handles cross-dependencies between libssl ↔ libcrypto etc.)
for dylib in "$FRAMEWORKS"/*.dylib; do
    while IFS= read -r dep; do
        [[ "$dep" == /opt/homebrew/* ]] || continue
        dep_name=$(basename "$dep")
        install_name_tool \
            -change "$dep" \
            "@executable_path/../Frameworks/$dep_name" \
            "$dylib" 2>/dev/null || true
    done < <(otool -L "$dylib" 2>/dev/null | awk 'NR>1 {print $1}')
done

# ── Ad-hoc codesign ──────────────────────────────────────────────────────────
echo "  Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "✅ $APP ready"
