#!/bin/bash

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required." && exit 1
fi

# Ensure configuration file argument is provided and exists
TOKEN_FILE="${1:-credentials.json}"
if [ ! -f "$TOKEN_FILE" ]; then
    echo "Error: token file '$TOKEN_FILE' not found!"
    echo "Usage: $0 [path/to/credentials.json]"
    exit 1
fi

# Read configuration safely
TOKEN=$(jq -r '.GITHUB_TOKEN // "none"' "$TOKEN_FILE")
OWNER=$(jq -r '.GITHUB_OWNER' "$TOKEN_FILE")
REPO=$(jq -r '.GITHUB_REPO' "$TOKEN_FILE")
BRANCH=$(jq -r '.GITHUB_BRANCH // "main"' "$TOKEN_FILE")

# Validate required fields
if [ -z "$OWNER" ] || [ "$OWNER" = "null" ] || [ -z "$REPO" ] || [ "$REPO" = "null" ]; then
    echo "Error: Invalid or missing GITHUB_OWNER or GITHUB_REPO in $TOKEN_FILE"
    exit 1
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "none" ] || [ "$TOKEN" = "null" ]; then
    echo "Error: GITHUB_TOKEN is required in $TOKEN_FILE to create a remote repository via API."
    exit 1
fi

FOLDER="$REPO"

# Check if local folder already exists
if [ -d "$FOLDER" ]; then
    echo "Error: Directory '$FOLDER' already exists locally."
    exit 1
fi

echo "1. Creating remote repository '$OWNER/$REPO' on GitHub..."
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"$REPO\", \"private\":true}")

if [ "$API_RESPONSE" -ne 201 ] && [ "$API_RESPONSE" -ne 222 ]; then
    echo "Error: Failed to create repository on GitHub (HTTP status: $API_RESPONSE)."
    echo "Make sure the repo doesn't already exist on GitHub and your token has repo permissions."
    exit 1
fi
echo "Remote repository created successfully!"

echo "2. Initializing local repository in '$FOLDER'..."
git init "$FOLDER" --initial-branch="$BRANCH" >/dev/null

# Create a starter README and commit it locally
echo "# $REPO" > "$FOLDER/README.md"
git -C "$FOLDER" add README.md
git -C "$FOLDER" commit -m "Initial commit" >/dev/null
echo "Local repository initialized and committed."

echo ""
echo "Success! Remote and local repositories are ready."
echo "Now run your push script to upload your code:"
echo "  ./push.sh $TOKEN_FILE"
