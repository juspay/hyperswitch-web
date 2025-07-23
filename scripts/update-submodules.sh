#!/usr/bin/env bash

set -e

echo ""
echo "🚀 Starting submodule update script..."
echo "--------------------------------------"

# Initialize and fetch recursively
echo "🔍 Initializing submodules..."
git submodule update --init --recursive

echo ""
echo "🔄 Updating submodules to latest commits..."

# For each submodule, do:
git submodule foreach --recursive '
  echo ""
  echo "👉 Processing submodule: $name"
  
  # Check if we are inside a git repo
  if [ ! -d ".git" ]; then
    echo "⚠️  Skipping: .git not found in $name"
    exit 0
  fi

  # Try to checkout main or master
  if git rev-parse --verify origin/main > /dev/null 2>&1; then
    BRANCH="main"
  elif git rev-parse --verify origin/master > /dev/null 2>&1; then
    BRANCH="master"
  else
    echo "⚠️  No main or master branch found in $name, skipping pull"
    exit 0
  fi

  echo "📌 Checking out $BRANCH..."
  git checkout $BRANCH

  echo "📥 Pulling latest for $BRANCH..."
  git pull origin $BRANCH

  echo "✅ Done with $name"
'

echo ""
echo "✅ All submodules updated."
echo "👉 Remember to commit the updated submodule pointers if needed:"
echo "   git add ."
echo "   git commit -m \"Update submodules to latest commits\""
echo ""

exit 0
