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

# Update src/rule.lua
if [ -f "src/rule.lua" ]; then
    # Use sed to replace the VERSION line
    if grep -q "^local VERSION" src/rule.lua; then
        sed -i.bak "s/^local VERSION = \".*\"/local VERSION = \"$NEW_VERSION\"/" src/rule.lua
        rm src/rule.lua.bak  # Remove backup file
        echo "✓ Updated src/rule.lua"
    else
        echo "⚠ Warning: VERSION declaration not found in src/rule.lua"
    fi
else
    echo "⚠ Warning: src/rule.lua not found"
fi

# Update src/eventrunner.lua
if [ -f "src/eventrunner.lua" ]; then
    # Use sed to replace the VERSION line
    if grep -q "^local VERSION" src/eventrunner.lua; then
        sed -i.bak "s/^local VERSION = \".*\"/local VERSION = \"$NEW_VERSION\"/" src/eventrunner.lua
        rm src/eventrunner.lua.bak  # Remove backup file
        echo "✓ Updated src/eventrunner.lua"
    else
        echo "⚠ Warning: VERSION declaration not found in src/eventrunner.lua"
    fi
else
    echo "⚠ Warning: src/eventrunner.lua not found"
fi

# Update src/updater.lua
if [ -f "src/updater.lua" ]; then
    # Use sed to replace the VERSION line
    if grep -q "^local VERSION" src/updater.lua; then
        sed -i.bak "s/^local VERSION = \".*\"/local VERSION = \"$NEW_VERSION\"/" src/updater.lua
        rm src/updater.lua.bak  # Remove backup file
        echo "✓ Updated src/updater.lua"
    else
        echo "⚠ Warning: VERSION declaration not found in src/updater.lua"
    fi
else
    echo "⚠ Warning: src/updater.lua not found"
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
if [ -f "src/rule.lua" ] && grep -q "^local VERSION" src/rule.lua; then
    echo "  src/rule.lua: $(grep "^local VERSION" src/rule.lua)"
fi
if [ -f "src/eventrunner.lua" ] && grep -q "^local VERSION" src/eventrunner.lua; then
    echo "  src/eventrunner.lua: $(grep "^local VERSION" src/eventrunner.lua)"
fi
if [ -f "src/updater.lua" ] && grep -q "^local VERSION" src/updater.lua; then
    echo "  src/updater.lua: $(grep "^local VERSION" src/updater.lua)"
fi