# Auto-Commit System for GitHub

Standalone script that automatically watches for file changes in your project and commits/pushes them to GitHub.

## Features

- ✅ Watches entire project directory for file changes
- ✅ Automatically commits and pushes to GitHub
- ✅ Debounces changes (waits 5 seconds after last change)
- ✅ Detailed logging
- ✅ Completely isolated from your project code
- ✅ Ignores sensitive files (.env, tokens, etc.)

## GitHub Token Permissions Required

You need to create a **Personal Access Token** from GitHub with the following permissions:

### For Public Repositories:
- `public_repo` - Access public repositories

### For Private Repositories:
- `repo` - Full control of private repositories (includes all sub-scopes)

### How to Create a GitHub Token:

1. Go to GitHub Settings: https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Give it a descriptive name (e.g., "Auto-Commit Script")
4. Select the appropriate scopes:
   - For private repos: Check `repo` (this includes all repo permissions)
   - For public repos: Check `public_repo` only
5. Click **"Generate token"**
6. **IMPORTANT:** Copy the token immediately (you won't see it again!)

## Installation

1. Install dependencies:
   ```bash
   cd .auto-commit-system
   npm install
   ```

2. Configure your GitHub token:
   ```bash
   node setup-github-token.js YOUR_GITHUB_TOKEN
   ```

   Or run in interactive mode:
   ```bash
   node setup-github-token.js
   ```

## Usage

### Start the auto-commit watcher:

```bash
cd .auto-commit-system
node auto-commit.js
```

The script will:
- Watch your entire project directory for changes
- Wait 5 seconds after the last change
- Automatically commit with a descriptive message
- Push to your current branch on GitHub

### Run in background:

```bash
cd .auto-commit-system
nohup node auto-commit.js > /dev/null 2>&1 &
```

To stop the background process:
```bash
# Find the process ID
ps aux | grep auto-commit

# Kill the process
kill <process-id>
```

### Check logs:

```bash
tail -f .auto-commit-system/auto-commit.log
```

## Configuration

Edit `auto-commit.js` to customize:

- `DEBOUNCE_DELAY` - Time to wait after last change (default: 5000ms)
- `IGNORE_PATTERNS` - Additional files/folders to ignore

## What Gets Committed

The script will commit all changes in your project directory **EXCEPT**:
- `.git/` directory
- `node_modules/`
- `.auto-commit-system/` (this folder itself)
- Token files (`.github-token`, `*.token`)
- Environment files (`.env`, `.env.*`)
- `.DS_Store` and system files
- Log files
- Anything else in `.gitignore`

## Security Notes

⚠️ **IMPORTANT:**
- Your GitHub token is stored in `.git/config`
- The `.git/` folder is automatically excluded from commits
- Never manually commit the `.git/` folder
- The `.gitignore` is configured to exclude token files
- Keep your token secure and never share it

## Troubleshooting

### "Authentication failed"
- Make sure you ran `setup-github-token.js` with a valid token
- Verify your token has the correct permissions
- Check that the token hasn't expired

### "Push rejected"
- Your local branch may be behind the remote
- Run: `git pull origin <branch-name>` first
- Then restart the auto-commit script

### "Nothing to commit"
- This is normal and means no changes were detected
- The script automatically handles this

### Changes aren't being detected
- Check that the files aren't in the ignore list
- View logs: `tail -f auto-commit.log`
- Verify the script is still running: `ps aux | grep auto-commit`

## File Structure

```
.auto-commit-system/
├── README.md              # This file
├── package.json           # Dependencies
├── auto-commit.js         # Main watcher script
├── setup-github-token.js  # Token configuration script
└── auto-commit.log        # Activity log (created on first run)
```

## Stopping Auto-Commit

Press `Ctrl+C` if running in foreground, or:

```bash
# Find the process
ps aux | grep auto-commit

# Kill it
kill <pid>
```

## Support

If you encounter issues:
1. Check `auto-commit.log` for error messages
2. Verify your GitHub token is valid and has correct permissions
3. Ensure you have internet connectivity
4. Check that your git remote is properly configured: `git remote -v`
