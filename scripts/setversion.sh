#!/bin/bash

# setversion.sh - Update version number in multiple files
# Usage: ./scripts/setversion.sh <new_version>
# Example: ./scripts/setversion.sh 0.0.1

set -e  # Exit on any error

# Check if version argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.0.1"
    exit 1
fi

NEW_VERSION="$1"

# Validate version format (basic check for semantic versioning)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 0.0.1)"
    exit 1
fi

echo "Setting version to: $NEW_VERSION"

# Update .version file
echo "$NEW_VERSION" > .version
echo "✓ Updated .version"

# Update rule.lua
if [ -f "rule.lua" ]; then
    # Use sed to replace the VERSION line
    if grep -q "^local VERSION" rule.lua; then
        sed -i.bak "s/^local VERSION = \".*\"/local VERSION = \"$NEW_VERSION\"/" rule.lua
        rm rule.lua.bak  # Remove backup file
        echo "✓ Updated rule.lua"
    else
        echo "⚠ Warning: VERSION declaration not found in rule.lua"
    fi
else
    echo "⚠ Warning: rule.lua not found"
fi

# Update updater.lua
if [ -f "updater.lua" ]; then
    # Use sed to replace the VERSION line
    if grep -q "^local VERSION" updater.lua; then
        sed -i.bak "s/^local VERSION = \".*\"/local VERSION = \"$NEW_VERSION\"/" updater.lua
        rm updater.lua.bak  # Remove backup file
        echo "✓ Updated updater.lua"
    else
        echo "⚠ Warning: VERSION declaration not found in updater.lua"
    fi
else
    echo "⚠ Warning: updater.lua not found"
fi

echo ""
echo "Version update complete! 🎉"
echo "Files updated with version: $NEW_VERSION"

# Show what was changed
echo ""
echo "Changed files:"
if [ -f ".version" ]; then
    echo "  .version: $(cat .version)"
fi
if [ -f "rule.lua" ] && grep -q "^local VERSION" rule.lua; then
    echo "  rule.lua: $(grep "^local VERSION" rule.lua)"
fi
if [ -f "updater.lua" ] && grep -q "^local VERSION" updater.lua; then
    echo "  updater.lua: $(grep "^local VERSION" updater.lua)"
fi