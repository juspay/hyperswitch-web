#!/usr/bin/env bash

set -e

echo ""
echo "🚀 Starting submodule update script..."
echo "--------------------------------------"

# Step 1: Initialize and fetch submodules recursively
echo "🔍 Initializing submodules..."
git submodule update --init --recursive

echo ""
echo "🔄 Updating submodules to latest commits..."

# Step 2: Loop through each submodule and update
git submodule foreach --recursive '
  echo ""
  echo "👉 Processing submodule: $name"

  # Check if inside a valid Git working tree
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "⚠️  Skipping: not a Git working tree in $name"
    exit 0
  fi

  # Try to find the appropriate remote branch
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
