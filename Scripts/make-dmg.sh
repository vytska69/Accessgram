#!/usr/bin/env bash
# make-dmg.sh – wraps Accessgram.app into a distributable DMG.
# Usage: ./Scripts/make-dmg.sh <dmg_base_name>
#   dmg_base_name  – filename without .dmg extension, e.g. "Accessgram-0.1-2026-05-03-14-30"
set -euo pipefail

BASE_NAME="${1:-Accessgram-dev}"
DMG_NAME="${BASE_NAME}.dmg"
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
