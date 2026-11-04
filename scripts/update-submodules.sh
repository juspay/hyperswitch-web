#!/usr/bin/env bash

set -e

echo ""
echo "🔍 Checking out pinned submodule revisions..."
git submodule update --init --recursive
