#!/bin/bash

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required." && exit 1
fi

# Parse arguments to find the token file and optional flags
TOKEN_FILE=""
FORCE_FLAG=""

for arg in "$@"; do
    if [ "$arg" = "--force" ]; then
        FORCE_FLAG="--force"
    elif [ -z "$TOKEN_FILE" ]; then
        TOKEN_FILE="$arg"
    fi
done

# Ensure configuration file argument is provided and exists
if [ -z "$TOKEN_FILE" ] || [ ! -f "$TOKEN_FILE" ]; then
    echo "Error: token.json file not specified or not found!"
    echo "Usage: $0 path/to/token.json [--force]"
    exit 1
fi

# Read configuration safely
TOKEN=$(jq -r '.GITHUB_TOKEN // "none"' "$TOKEN_FILE")
OWNER=$(jq -r '.GITHUB_OWNER' "$TOKEN_FILE")
REPO=$(jq -r '.GITHUB_REPO' "$TOKEN_FILE")
BRANCH=$(jq -r '.GITHUB_BRANCH // "main"' "$TOKEN_FILE")

# Validate that essential fields aren't missing, empty, or literal "null"
if [ -z "$OWNER" ] || [ "$OWNER" = "null" ] || [ -z "$REPO" ] || [ "$REPO" = "null" ]; then
    echo "Error: Invalid or missing GITHUB_OWNER or GITHUB_REPO in $TOKEN_FILE"
    exit 1
fi

# Build URL safely (handling missing, 'none', or JSON 'null' tokens)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "none" ] || [ "$TOKEN" = "null" ]; then
    URL="https://github.com/${OWNER}/${REPO}.git"
else
    URL="https://${TOKEN}@github.com/${OWNER}/${REPO}.git"
fi

FOLDER="$REPO"

# Verify that the repository folder exists and is a valid Git repository
if [ ! -d "$FOLDER/.git" ]; then
    echo "Error: Directory '$FOLDER' does not exist or is not a valid Git repository."
    echo "Please run pull.sh first."
    exit 1
fi

# If --force is passed, bypass remote checks and force-push immediately
if [ -n "$FORCE_FLAG" ]; then
    echo "WARNING: Forcing push to branch '$BRANCH'..."
    git -C "$FOLDER" push "$URL" "$BRANCH" --force || { echo "Error: Failed to force-push to remote."; exit 1; }
    echo "Force-push completed successfully!"
    exit 0
fi

# Silently sync remote tracking state so our unpushed check is 100% accurate
git -C "$FOLDER" fetch origin "$BRANCH" --quiet 2>/dev/null || true

# Check if there are any unpushed local commits (with fallback for first push)
if git -C "$FOLDER" rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
    UNPUSHED_COMMITS=$(git -C "$FOLDER" log "origin/$BRANCH..$BRANCH" --oneline 2>/dev/null || true)
else
    UNPUSHED_COMMITS=$(git -C "$FOLDER" log --oneline 2>/dev/null || true)
fi

# If no local commits are waiting, exit cleanly without making a network call
if [ -z "$UNPUSHED_COMMITS" ]; then
    echo "No new local commits to push. Everything is already up to date!"
    exit 0
fi

echo "Found unpushed commits. Pushing to branch '$BRANCH'..."
git -C "$FOLDER" push "$URL" "$BRANCH" || { echo "Error: Failed to push to remote."; exit 1; }

echo "Push completed successfully!"
