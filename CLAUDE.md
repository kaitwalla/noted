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
