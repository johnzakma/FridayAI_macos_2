#!/usr/bin/env node

/**
 * Auto-commit and push script for GitHub
 * Watches for file changes and automatically commits and pushes to GitHub
 */

const { spawn } = require('child_process');
const chokidar = require('chokidar');
const fs = require('fs');
const path = require('path');

// Configuration
const DEBOUNCE_DELAY = 5000; // Wait 5 seconds after last change before committing
const PROJECT_ROOT = path.join(__dirname, '..'); // Parent directory (project root)
const WATCH_PATH = PROJECT_ROOT; // Watch project root directory
const IGNORE_PATTERNS = [
  '.git/**',
  'node_modules/**',
  '.auto-commit-system/**',
  '.github-token',
  '*.token',
  '.env',
  '.DS_Store',
  'auto-commit.log'
];

// State management
let changeTimeout = null;
let changedFiles = new Set();
let isCommitting = false;

// Logging
const logFile = path.join(__dirname, 'auto-commit.log');
function log(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  console.log(logMessage.trim());
  fs.appendFileSync(logFile, logMessage);
}

// Execute git command
function execGit(args) {
  return new Promise((resolve, reject) => {
    const git = spawn('git', args, { cwd: PROJECT_ROOT });
    let stdout = '';
    let stderr = '';

    git.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    git.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    git.on('close', (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(stderr || stdout));
      }
    });
  });
}

// Check if GitHub token is configured
async function checkGitHubAuth() {
  try {
    // Check if remote URL uses token authentication
    const remoteUrl = await execGit(['config', '--get', 'remote.origin.url']);
    if (remoteUrl.includes('github.com')) {
      log('GitHub remote configured');
      return true;
    }
  } catch (error) {
    log('Error checking GitHub authentication: ' + error.message);
  }
  return false;
}

// Get current branch
async function getCurrentBranch() {
  try {
    const branch = await execGit(['rev-parse', '--abbrev-ref', 'HEAD']);
    return branch.trim();
  } catch (error) {
    log('Error getting current branch: ' + error.message);
    return 'main'; // Default to main
  }
}

// Check if there are changes to commit
async function hasChanges() {
  try {
    const status = await execGit(['status', '--porcelain']);
    return status.trim().length > 0;
  } catch (error) {
    log('Error checking git status: ' + error.message);
    return false;
  }
}

// Commit and push changes
async function commitAndPush() {
  if (isCommitting) {
    log('Already committing, skipping...');
    return;
  }

  isCommitting = true;

  try {
    // Check if there are changes
    if (!(await hasChanges())) {
      log('No changes to commit');
      isCommitting = false;
      return;
    }

    const filesList = Array.from(changedFiles).slice(0, 5).join(', ');
    const filesCount = changedFiles.size;
    const moreFiles = filesCount > 5 ? ` and ${filesCount - 5} more` : '';

    log(`Committing changes: ${filesList}${moreFiles}`);

    // Add all changes
    await execGit(['add', '.']);
    log('Added changes to staging area');

    // Generate commit message
    const timestamp = new Date().toLocaleString();
    const commitMessage = `Auto-commit: ${filesCount} file(s) changed at ${timestamp}`;

    // Commit changes
    await execGit(['commit', '-m', commitMessage]);
    log(`Committed: ${commitMessage}`);

    // Get current branch
    const branch = await getCurrentBranch();
    log(`Pushing to branch: ${branch}`);

    // Push to remote
    await execGit(['push', 'origin', branch]);
    log('Successfully pushed to GitHub');

    // Clear changed files list
    changedFiles.clear();

  } catch (error) {
    log('Error during commit/push: ' + error.message);

    // If push failed due to auth, provide helpful message
    if (error.message.includes('Authentication') || error.message.includes('403')) {
      log('Authentication failed. Please configure your GitHub token.');
      log('Run: node setup-github-token.js <your-token>');
    } else if (error.message.includes('nothing to commit')) {
      log('No changes to commit (this is normal)');
    } else if (error.message.includes('rejected')) {
      log('Push rejected. You may need to pull changes first.');
      log('Run: git pull origin ' + await getCurrentBranch());
    }
  } finally {
    isCommitting = false;
  }
}

// Handle file change
function onFileChange(filepath) {
  // Skip if already committing
  if (isCommitting) return;

  // Add to changed files set
  changedFiles.add(filepath);
  log(`File changed: ${filepath}`);

  // Clear existing timeout
  if (changeTimeout) {
    clearTimeout(changeTimeout);
  }

  // Set new timeout
  changeTimeout = setTimeout(() => {
    log(`Debounce delay elapsed, committing ${changedFiles.size} file(s)...`);
    commitAndPush();
  }, DEBOUNCE_DELAY);
}

// Start watching for changes
async function startWatcher() {
  log('='.repeat(60));
  log('Auto-commit script started');
  log('='.repeat(60));

  // Check GitHub authentication
  await checkGitHubAuth();

  // Get current branch
  const branch = await getCurrentBranch();
  log(`Watching branch: ${branch}`);

  log(`Watching directory: ${WATCH_PATH}`);
  log(`Debounce delay: ${DEBOUNCE_DELAY}ms`);
  log(`Ignored patterns: ${IGNORE_PATTERNS.join(', ')}`);
  log('Waiting for file changes...');
  log('Press Ctrl+C to stop');

  // Initialize watcher
  const watcher = chokidar.watch(WATCH_PATH, {
    ignored: IGNORE_PATTERNS,
    persistent: true,
    ignoreInitial: true,
    awaitWriteFinish: {
      stabilityThreshold: 1000,
      pollInterval: 100
    }
  });

  // Watch for changes
  watcher
    .on('add', onFileChange)
    .on('change', onFileChange)
    .on('unlink', onFileChange)
    .on('error', (error) => log(`Watcher error: ${error}`));
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  log('Shutting down auto-commit script...');
  if (changeTimeout) {
    clearTimeout(changeTimeout);
  }
  process.exit(0);
});

process.on('SIGTERM', () => {
  log('Shutting down auto-commit script...');
  if (changeTimeout) {
    clearTimeout(changeTimeout);
  }
  process.exit(0);
});

// Start the watcher
startWatcher().catch((error) => {
  log('Fatal error: ' + error.message);
  process.exit(1);
});
