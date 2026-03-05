# Noted Project Instructions

## Commands

### /deploy

Deploy the web app by committing, pushing, and updating the deploy branch.

**Steps:**
1. Stage and commit all changes (prompt for commit message if not provided)
2. Push to origin main
3. Run `git subtree split --prefix web --branch deploy` to extract the web directory
4. Run `git subtree split --prefix web --branch frontend` to update the frontend branch
5. Force push both branches: `git push origin deploy frontend --force`

**Usage:**
- `/deploy` - Run the full deploy workflow
- `/deploy "commit message"` - Deploy with a specific commit message

**Example workflow:**
```bash
git add -A
git commit -m "message"
git push origin main
git subtree split --prefix web --branch deploy
git subtree split --prefix web --branch frontend
git push origin deploy frontend --force
```

### /release-macos

Create and sign a macOS app release for auto-update distribution via Sparkle.

**Prerequisites:**
- EdDSA signing keys generated (one-time setup)
- Built release app bundle

**One-Time Setup (if keys don't exist):**
```bash
# Generate EdDSA keys for signing
./macos/scripts/setup-sparkle.sh generate

# Add the public key to Info.plist as SUPublicEDKey
# Back up private key from macos/.sparkle-keys/ securely
```

**Release Steps:**
1. Build the app in Xcode with Release configuration
2. Archive and export the app bundle
3. Create and sign the update package:

```bash
# Create update package
./macos/scripts/setup-sparkle.sh package /path/to/NotedMenu.app NotedMenu-v1.1.zip

# Sign the update (outputs EdDSA signature)
./macos/scripts/setup-sparkle.sh sign NotedMenu-v1.1.zip
```

4. Upload the signed .zip to your release hosting (GitHub Releases, S3, etc.)
5. Update server environment variables:

```bash
APP_VERSION_MACOS=1.1
APP_BUILD_MACOS=3
APP_DOWNLOAD_URL_MACOS=https://github.com/user/noted/releases/download/v1.1/NotedMenu-v1.1.zip
APP_ED_SIGNATURE_MACOS=<signature-from-sign-command>
APP_RELEASE_NOTES_MACOS="Bug fixes and performance improvements."
APP_FILE_LENGTH_MACOS=12345678  # Optional: file size in bytes
```

6. Restart the server to pick up new environment variables

**Usage:**
- `/release-macos` - Show release instructions
- `/release-macos setup` - Run one-time key generation
- `/release-macos package <version>` - Guide through creating a release

**Appcast URL:** `https://api.noted.app/appcast/macos.xml`

**Updating Release Info (no server restart needed):**
```bash
curl -X POST https://api.noted.app/api/admin/releases \
  -H "X-Update-Token: $UPDATE_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "platform": "macos",
    "version": "1.0",
    "build": 2,
    "download_url": "https://github.com/kaitwalla/noted/releases/download/macos-v1.0/NotedMenu-v1.0.zip",
    "ed_signature": "<signature-from-sign-command>",
    "file_length": 4504903,
    "release_notes": "What'\''s new in this version."
  }'
```

**Check current release:**
```bash
curl -H "X-Update-Token: $UPDATE_SECRET" \
  "https://api.noted.app/api/admin/releases?platform=macos"
```

**Files:**
- `macos/scripts/setup-sparkle.sh` - Helper script for key generation and signing
- `macos/.sparkle-keys/` - Private keys (gitignored, keep secure!)
- `macos/NotedMenu/Info.plist` - Contains SUFeedURL and SUPublicEDKey

**Current Signing Key:**
- Public: `pTRrVDMZFzbSYRpWFzjYcwd2+0cVJIEARc9oeYTfBEw=`
- Private: Stored in macOS Keychain and backed up at `macos/.sparkle-keys/eddsa_private_key`

**Troubleshooting:**
- "Signature invalid" → Ensure the public key in Info.plist matches the private key used for signing
- "Update not found" → Check version/build are higher than current app version
- Test appcast: `curl https://api.noted.app/appcast/macos.xml`
- Debug in app: Hold Option key while clicking "Check for Updates" for verbose logging
