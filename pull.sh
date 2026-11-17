#!/bin/bash

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required." && exit 1
fi

# Ensure configuration file argument is provided and exists
TOKEN_FILE="$1"
if [ -z "$TOKEN_FILE" ] || [ ! -f "$TOKEN_FILE" ]; then
    echo "Error: token.json file not specified or not found!"
    echo "Usage: $0 path/to/token.json"
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

# Smart Clone, Update, or Collision Handling with Hash Check Optimization
if [ -d "$FOLDER/.git" ]; then
    echo "Checking for updates in '$FOLDER'..."
    git -C "$FOLDER" fetch origin "$BRANCH" || { echo "Error: Failed to fetch from origin."; exit 1; }

    LOCAL_COMMIT=$(git -C "$FOLDER" rev-parse "$BRANCH" 2>/dev/null || echo "")
    REMOTE_COMMIT=$(git -C "$FOLDER" rev-parse "origin/$BRANCH" 2>/dev/null || echo "")

    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ] && [ -n "$LOCAL_COMMIT" ]; then
        echo "Already up to date! No changes to apply."
    else
        echo "Updates found. Applying changes..."
        git -C "$FOLDER" reset --hard origin/"$BRANCH" || { echo "Error: Failed to reset branch."; exit 1; }
        echo "Repository updated successfully."
    fi
elif [ -d "$FOLDER" ]; then
    echo "Error: Directory '$FOLDER' already exists but is not a valid Git repository."
    echo "Please remove, rename, or back it up before running the script."
    exit 1
else
    echo "Cloning fresh repository into '$FOLDER'..."
    git clone -b "$BRANCH" "$URL" "$FOLDER" || { echo "Error: Failed to clone repository."; exit 1; }
fi
