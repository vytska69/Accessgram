#!/usr/bin/env bash
# bundle.sh – assembles Accessgram.app from a compiled binary and TDLib.
# Usage: ./Scripts/bundle.sh <binary_path> <build_number>
set -euo pipefail

BINARY="${1:-.build/release/Accessgram}"
BUILD_NUMBER="${2:-0}"
APP="Accessgram.app"
MACOS="$APP/Contents/MacOS"
FRAMEWORKS="$APP/Contents/Frameworks"
RESOURCES="$APP/Contents/Resources"
BREW_PREFIX="$(brew --prefix)"

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

# ── Pure-bash symlink resolver (no python3 / GNU coreutils required) ─────────
resolve_path() {
    local path="$1"
    local count=0
    while [ -L "$path" ] && [ "$count" -lt 20 ]; do
        local target
        target=$(readlink "$path")
        if [[ "$target" == /* ]]; then
            path="$target"
        else
            path="$(dirname "$path")/$target"
        fi
        count=$((count + 1))
    done
    echo "$path"
}

# ── Recursive dylib embedder ─────────────────────────────────────────────────
embed_dylib() {
    local src="$1"
    local name
    name=$(basename "$src")
    local dest="$FRAMEWORKS/$name"

    [ -f "$dest" ] && return 0   # already embedded

    local real
    real=$(resolve_path "$src")
    if [ ! -f "$real" ]; then
        echo "  ⚠️  Cannot find $src → skipping" >&2
        return 0
    fi

    echo "  Embedding: $name (from $real)"
    cp "$real" "$dest"
    chmod 755 "$dest"
    install_name_tool -id "@executable_path/../Frameworks/$name" "$dest"

    # Recurse into Homebrew dependencies and relink them.
    while IFS= read -r dep; do
        [[ "$dep" == "$BREW_PREFIX"/* ]] || continue
        local dn
        dn=$(basename "$dep")
        embed_dylib "$dep"
        install_name_tool \
            -change "$dep" "@executable_path/../Frameworks/$dn" \
            "$dest" 2>/dev/null || true
    done < <(otool -L "$dest" 2>/dev/null | awk 'NR>1 {print $1}')
}

# ── Locate libtdjson.dylib ───────────────────────────────────────────────────
# Try the three standard Homebrew locations in order of preference.
TDLIB_SRC=""
for candidate in \
    "$BREW_PREFIX/lib/libtdjson.dylib" \
    "$BREW_PREFIX/opt/tdlib/lib/libtdjson.dylib" \
    "$(brew --cellar tdlib 2>/dev/null || true)"; do
    if [ -f "$candidate" ] || [ -L "$candidate" ]; then
        TDLIB_SRC="$candidate"
        break
    fi
    # If the candidate is the Cellar directory, search inside it.
    if [ -d "$candidate" ]; then
        found=$(find "$candidate" -name "libtdjson.dylib" -maxdepth 4 2>/dev/null \
                | sort -V | tail -1)
        if [ -n "$found" ]; then
            TDLIB_SRC="$found"
            break
        fi
    fi
done

if [ -z "$TDLIB_SRC" ]; then
    echo "❌ Cannot find libtdjson.dylib under $BREW_PREFIX" >&2
    echo "   Make sure 'brew install tdlib && brew link --overwrite tdlib' ran." >&2
    exit 1
fi

echo "  Embedding TDLib: $TDLIB_SRC"
embed_dylib "$TDLIB_SRC"

# Verify the main dylib was actually embedded.
if [ ! -f "$FRAMEWORKS/libtdjson.dylib" ]; then
    echo "❌ libtdjson.dylib was not copied to Frameworks – aborting." >&2
    exit 1
fi

# ── Fix the main binary's reference to libtdjson ─────────────────────────────
ORIGINAL=$(otool -L "$MACOS/Accessgram" | awk '/tdjson/ {print $1}' | head -1)
if [ -n "$ORIGINAL" ]; then
    echo "  Relinking binary: $ORIGINAL → @executable_path/../Frameworks/libtdjson.dylib"
    install_name_tool \
        -change "$ORIGINAL" \
        "@executable_path/../Frameworks/libtdjson.dylib" \
        "$MACOS/Accessgram"
fi

# ── Second pass: fix any remaining Homebrew paths in all embedded dylibs ─────
for dylib in "$FRAMEWORKS"/*.dylib; do
    while IFS= read -r dep; do
        [[ "$dep" == "$BREW_PREFIX"/* ]] || continue
        install_name_tool \
            -change "$dep" \
            "@executable_path/../Frameworks/$(basename "$dep")" \
            "$dylib" 2>/dev/null || true
    done < <(otool -L "$dylib" 2>/dev/null | awk 'NR>1 {print $1}')
done

# ── List what we embedded ─────────────────────────────────────────────────────
echo "  Embedded libraries:"
for f in "$FRAMEWORKS"/*.dylib; do echo "    $(basename "$f")"; done

# ── Ad-hoc codesign ──────────────────────────────────────────────────────────
echo "  Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "✅ $APP ready"
