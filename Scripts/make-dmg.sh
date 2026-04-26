#!/usr/bin/env bash
# make-dmg.sh – wraps Accessgram.app into a distributable DMG.
# Usage: ./Scripts/make-dmg.sh <short_sha>
set -euo pipefail

SHORT_SHA="${1:-dev}"
DMG_NAME="Accessgram-${SHORT_SHA}.dmg"
STAGING="dmg_staging"

echo "▶ Creating $DMG_NAME"

rm -rf "$STAGING"
mkdir "$STAGING"
cp -r Accessgram.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "Accessgram" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

rm -rf "$STAGING"
echo "✅ $DMG_NAME ready ($(du -sh "$DMG_NAME" | cut -f1))"
