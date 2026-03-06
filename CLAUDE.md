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

### /release

**See `~/.claude/skills/release/SKILL.md` for full instructions.**

Create a full release: commit, push, tag, build/sign/notarize macOS app, upload, update appcast.

**Usage:**
- `/release` - Interactive release
- `/release 1.2` - Release version 1.2
- `/release 1.2 "Release notes"` - With custom notes

**Key Details:**
- API: https://note.kait.dev/api
- Appcast: https://note.kait.dev/appcast/macos.xml
- Team ID: PNKZN48WK4
- EdDSA key: `macos/.sparkle-keys/eddsa_private_key`
- Notarytool profile: `notarytool`

**Manual Release Info Update:**
```bash
curl -X POST https://note.kait.dev/api/admin/releases \
  -H "X-Update-Token: LinkPenginControlsAll" \
  -H "Content-Type: application/json" \
  -d '{"platform":"macos","version":"1.1","build":1,...}'
```
