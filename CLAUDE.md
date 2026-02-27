# Noted Project Instructions

## Commands

### /deploy

Deploy the web app by committing, pushing, and updating the deploy branch.

**Steps:**
1. Stage and commit all changes (prompt for commit message if not provided)
2. Push to origin main
3. Run `git subtree split --prefix web --branch deploy` to extract the web directory
4. Force push the deploy branch: `git push origin deploy --force`

**Usage:**
- `/deploy` - Run the full deploy workflow
- `/deploy "commit message"` - Deploy with a specific commit message

**Example workflow:**
```bash
git add -A
git commit -m "message"
git push origin main
git subtree split --prefix web --branch deploy
git push origin deploy --force
```
