#!/usr/bin/env node

/**
 * Setup script to configure GitHub token for auto-commit
 * Usage: node setup-github-token.js <your-github-token>
 */

const { spawn } = require('child_process');
const readline = require('readline');

// Execute git command
function execGit(args) {
  return new Promise((resolve, reject) => {
    const git = spawn('git', args);
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

// Validate GitHub token format
function isValidToken(token) {
  // GitHub tokens start with ghp_ (personal access token) or github_pat_ (fine-grained token)
  return token && (token.startsWith('ghp_') || token.startsWith('github_pat_'));
}

// Setup GitHub token authentication
async function setupToken(token) {
  try {
    console.log('Setting up GitHub token authentication...\n');

    // Validate token format
    if (!isValidToken(token)) {
      console.error('Error: Invalid token format.');
      console.error('GitHub tokens should start with "ghp_" or "github_pat_"');
      process.exit(1);
    }

    // Get current remote URL
    const currentRemote = await execGit(['config', '--get', 'remote.origin.url']);
    console.log(`Current remote: ${currentRemote.trim()}`);

    // Extract repository info from current remote
    let repoInfo;
    const httpsMatch = currentRemote.match(/https:\/\/github\.com\/(.+)\.git/);
    const sshMatch = currentRemote.match(/git@github\.com:(.+)\.git/);

    if (httpsMatch) {
      repoInfo = httpsMatch[1];
    } else if (sshMatch) {
      repoInfo = sshMatch[1];
    } else {
      console.error('Error: Could not parse GitHub repository URL');
      process.exit(1);
    }

    // Set new remote URL with token
    const newRemoteUrl = `https://${token}@github.com/${repoInfo}.git`;
    await execGit(['remote', 'set-url', 'origin', newRemoteUrl]);

    console.log('\nSuccess! GitHub token has been configured.');
    console.log('Repository:', repoInfo);
    console.log('\nYou can now run the auto-commit script:');
    console.log('  node auto-commit.js');
    console.log('\nOr run in background:');
    console.log('  nohup node auto-commit.js > /dev/null 2>&1 &');
    console.log('\nNote: Your token is stored in .git/config');
    console.log('Make sure .git/ is never committed to version control!');

  } catch (error) {
    console.error('Error setting up GitHub token:', error.message);
    process.exit(1);
  }
}

// Interactive mode to prompt for token
async function interactiveMode() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    rl.question('Enter your GitHub Personal Access Token: ', (token) => {
      rl.close();
      resolve(token.trim());
    });
  });
}

// Main function
async function main() {
  console.log('='.repeat(60));
  console.log('GitHub Token Setup for Auto-Commit');
  console.log('='.repeat(60));
  console.log();

  let token = process.argv[2];

  // If no token provided, use interactive mode
  if (!token) {
    console.log('No token provided as argument. Entering interactive mode...\n');
    token = await interactiveMode();
  }

  if (!token) {
    console.error('Error: No token provided');
    console.log('\nUsage:');
    console.log('  node setup-github-token.js <your-github-token>');
    console.log('\nOr run without arguments for interactive mode:');
    console.log('  node setup-github-token.js');
    process.exit(1);
  }

  await setupToken(token);
}

// Run main function
main().catch((error) => {
  console.error('Fatal error:', error.message);
  process.exit(1);
});
