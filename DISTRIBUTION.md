# Distribution Guide

## Notarized Direct Download (recommended)

This is the simplest path: sign with hardened runtime, notarize with Apple,
distribute as a `.dmg`.  No App Store review needed.

### Requirements

- Apple Developer account (Individual or Organization)
- Xcode with your Developer ID Application certificate installed
- `Accessgram.entitlements` already included in this repo

### Steps

1. **Open in Xcode**

   ```bash
   open Package.swift
   ```

2. **Set the signing identity**

   In the *Accessgram* target → Signing & Capabilities:
   - Team: your Apple Developer team
   - Signing Certificate: **Developer ID Application**
   - Enable **Hardened Runtime**
   - Set the entitlements file to `Accessgram.entitlements`

3. **Archive**

   Product → Archive, then Distribute → Developer ID → Upload (notarize).

4. **Export the notarized app** and wrap in a DMG:

   ```bash
   create-dmg \
     --volname "Accessgram" \
     --background "dmg-background.png" \
     --window-size 600 400 \
     --icon-size 128 \
     --app-drop-link 450 200 \
     Accessgram.dmg \
     path/to/Accessgram.app
   ```

---

## Mac App Store (full sandbox)

Full sandbox requires TDLib to be **embedded** in the app bundle rather than
loaded from Homebrew.

### Extra steps

1. **Embed TDLib**

   Download the pre-built `libtdc.dylib` + headers from the TDLib releases
   page or build from source, then add it as a binary target in `Package.swift`:

   ```swift
   .binaryTarget(
       name: "CTDLib",
       path: "Frameworks/libtdc.dylib"
   )
   ```

   Sign the dylib with your Developer ID:
   ```bash
   codesign --force --sign "Developer ID Application: ..." \
     --options runtime Frameworks/libtdc.dylib
   ```

2. **Enable sandbox in `Accessgram.entitlements`**

   Change:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <false/>
   ```
   to:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   ```

3. **Remove the Homebrew library path** from build settings (it is no longer needed once TDLib is embedded).

4. Submit via Xcode → Distribute App → App Store Connect.

---

## Entitlements reference

| Key | Value | Purpose |
|---|---|---|
| `cs.disable-library-validation` | `true` | Allow Homebrew-installed TDLib (notarized only) |
| `app-sandbox` | `false` / `true` | Enable for App Store; disable for notarized DMG |
| `network.client` | `true` | TDLib outbound connections to Telegram servers |
| `files.user-selected.read-only` | `true` | File attachment picker |
| `ubiquity-kvstore-identifier` | team + bundle ID | iCloud KV store for AppPreferences |
| `aps-environment` | `development` / `production` | APNs push notifications |

---

## CI / automated builds

The `.github/workflows/ci.yml` in this repo builds an unsigned DMG on every
push to the main branch.  For notarized releases, add the following secrets:

| Secret | Description |
|---|---|
| `APPLE_CERTIFICATE` | Base64-encoded Developer ID `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_TEAM_ID` | 10-character team identifier |
| `APPLE_APP_PASSWORD` | App-specific password for `notarytool` |
