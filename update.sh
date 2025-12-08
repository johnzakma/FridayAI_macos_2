#!/bin/bash

# Update script for FridayAI macOS project
echo "🔄 Pulling latest changes from bind-staging..."

# Discard any local changes (always use remote version)
git reset --hard HEAD
git clean -fd -e update.sh

# Pull the latest changes
git pull origin bind-staging

# Check if pull was successful
if [ $? -eq 0 ]; then
    echo "✅ Successfully updated to latest version!"
else
    echo "❌ Failed to pull changes. Please check your connection or resolve conflicts."
    exit 1
fi
