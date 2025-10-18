#!/bin/bash#!/bin/bash



# setversion.sh - Update version number in multiple files# setversion.sh - Update version number in multiple files

# Usage: ./scripts/setversion.sh <new_version># Usage: ./scripts/setversion.sh <new_version>

# Example: ./scripts/setversion.sh 0.0.1# Example: ./scripts/setversion.sh 0.0.1



set -e  # Exit on any errorset -e  # Exit on any error



# Get script directory and load configuration# Get script directory and load configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_FILE="$SCRIPT_DIR/project-config.sh"CONFIG_FILE="$SCRIPT_DIR/project-config.sh"



if [ ! -f "$CONFIG_FILE" ]; thenif [ ! -f "$CONFIG_FILE" ]; then

    echo "Error: Configuration file not found: $CONFIG_FILE"    echo "Error: Configuration file not found: $CONFIG_FILE"

    echo "Please create project-config.sh with your project settings."    echo "Please create project-config.sh with your project settings."

    exit 1    exit 1

fifi



# Source the configuration# Source the configuration

source "$CONFIG_FILE"source "$CONFIG_FILE"



# Validate configuration# Validate configuration

if ! validate_config; thenif ! validate_config; then

    echo "Error: Invalid configuration in $CONFIG_FILE"    echo "Error: Invalid configuration in $CONFIG_FILE"

    exit 1    exit 1

fifi



# Check if version argument is provided# Check if version argument is provided

if [ $# -ne 1 ]; thenif [ $# -ne 1 ]; then

    echo "Usage: $0 <version>"    echo "Usage: $0 <version>"

    echo "Example: $0 0.0.1"    echo "Example: $0 0.0.1"

    exit 1    exit 1

fifi



NEW_VERSION="$1"NEW_VERSION="$1"



# Validate version format (basic check for semantic versioning)# Validate version format (basic check for semantic versioning)

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; thenif ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

    echo "Error: Version must be in format X.Y.Z (e.g., 0.0.1)"    echo "Error: Version must be in format X.Y.Z (e.g., 0.0.1)"

    exit 1    exit 1

fifi



echo "Setting version to: $NEW_VERSION for $PROJECT_NAME"echo "Setting version to: $NEW_VERSION for $PROJECT_NAME"



# Update .version file (if configured)# Update .version file (if configured)

if [ -n "$VERSION_FILE" ]; thenif [ -n "$VERSION_FILE" ]; then

    echo "$NEW_VERSION" > "$VERSION_FILE"    echo "$NEW_VERSION" > "$VERSION_FILE"

    echo "✓ Updated $VERSION_FILE"    echo "✓ Updated $VERSION_FILE"

fifi



# Update all configured source files# Update all configured source files

for file_config in "${VERSION_FILES[@]}"; dofor file_config in "${VERSION_FILES[@]}"; do

    IFS=':' read -r filepath pattern <<< "$file_config"    IFS=':' read -r filepath pattern <<< "$file_config"

        

    if [ -f "$filepath" ]; then    if [ -f "$filepath" ]; then

        # Check if the pattern exists in the file        # Check if the pattern exists in the file

        if grep -q "$pattern" "$filepath"; then        if grep -q "$pattern" "$filepath"; then

            # Use sed with capture group to preserve the matched pattern exactly            # Use the pattern for matching, but reconstruct the replacement without regex chars

            # \1 captures and replays the matched pattern without the regex special chars            sed -i.bak "s/\(${pattern}\) = \".*\"/\1 = \"$NEW_VERSION\"/" "$filepath"

            sed -i.bak "s/\(${pattern}\) = \".*\"/\1 = \"$NEW_VERSION\"/" "$filepath"            rm "${filepath}.bak"  # Remove backup file

            rm "${filepath}.bak"  # Remove backup file            echo "✓ Updated $filepath"

            echo "✓ Updated $filepath"        else

        else            echo "⚠ Warning: VERSION pattern '$pattern' not found in $filepath"

            echo "⚠ Warning: VERSION pattern '$pattern' not found in $filepath"        fi

        fi    else

    else        echo "⚠ Warning: $filepath not found"

        echo "⚠ Warning: $filepath not found"    fi

    fidone

done

echo ""

echo ""echo "Version update complete! 🎉"

echo "Version update complete! 🎉"echo "Files updated with version: $NEW_VERSION"

echo "Files updated with version: $NEW_VERSION"

# Show what was changed

# Show what was changedecho ""

echo ""echo "Changed files:"

echo "Changed files:"if [ -n "$VERSION_FILE" ] && [ -f "$VERSION_FILE" ]; then

if [ -n "$VERSION_FILE" ] && [ -f "$VERSION_FILE" ]; then    echo "  $VERSION_FILE: $(cat "$VERSION_FILE")"

    echo "  $VERSION_FILE: $(cat "$VERSION_FILE")"fi

fi

for file_config in "${VERSION_FILES[@]}"; do

for file_config in "${VERSION_FILES[@]}"; do    IFS=':' read -r filepath pattern <<< "$file_config"

    IFS=':' read -r filepath pattern <<< "$file_config"    if [ -f "$filepath" ] && grep -q "$pattern" "$filepath"; then

    if [ -f "$filepath" ] && grep -q "$pattern" "$filepath"; then        echo "  $filepath: $(grep "$pattern" "$filepath")"

        echo "  $filepath: $(grep "$pattern" "$filepath")"    fi

    fidone

done

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