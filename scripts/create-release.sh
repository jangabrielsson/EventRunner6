#!/bin/bash

# create-release.sh - Automated release creation script
# Creates GitHub releases with version bumping, changelog updates, and artifact generation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get current version
get_current_version() {
    if [ -f ".version" ]; then
        cat .version | tr -d '\n'
    else
        echo "0.0.0"
    fi
}

# Function to increment version
increment_version() {
    local version=$1
    local type=$2
    
    IFS='.' read -ra PARTS <<< "$version"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}
    
    case $type in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Function to check git status
check_git_status() {
    info "Checking git repository status..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository!"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        error "You have uncommitted changes. Please commit or stash them first."
        git status --porcelain
        exit 1
    fi
    
    # Check if we're ahead of remote (unpushed commits)
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null || echo "")
    
    if [ -n "$remote_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
        if ! git merge-base --is-ancestor "$local_commit" "$remote_commit"; then
            error "Your branch is behind the remote. Please pull first."
            exit 1
        fi
        
        error "You have unpushed commits. Please push them first before creating a release."
        echo "Unpushed commits:"
        git log --oneline "$remote_commit..HEAD"
        exit 1
    fi
    
    success "Git repository is clean and up-to-date"
}

# Function to check required tools
check_dependencies() {
    info "Checking required dependencies..."
    
    local missing_deps=()
    
    if ! command_exists "git"; then
        missing_deps+=("git")
    fi
    
    if ! command_exists "plua"; then
        missing_deps+=("plua")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    success "All dependencies available"
}

# Function to get last release tag
get_last_release_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Function to generate release notes from commits
generate_release_notes() {
    local last_tag=$1
    local new_version=$2
    
    # Don't use info() here as it might be captured
    
    local commit_range
    if [ -n "$last_tag" ]; then
        commit_range="$last_tag..HEAD"
    else
        commit_range="HEAD"
    fi
    
    local notes="## Changes in v$new_version\n\n"
    
    if [ -n "$last_tag" ]; then
        notes+="### Commits since $last_tag:\n\n"
    else
        notes+="### All commits:\n\n"
    fi
    
    # Get commit messages and format them
    local commits
    commits=$(git log $commit_range --pretty=format:"%s" --no-merges)
    
    if [ -n "$commits" ]; then
        # Process each commit message
        while IFS= read -r commit; do
            if [[ $commit == feat* ]]; then
                notes+="- ✨ **Feature**: ${commit#feat: }\n"
            elif [[ $commit == fix* ]]; then
                notes+="- 🐛 **Fix**: ${commit#fix: }\n"
            elif [[ $commit == docs* ]]; then
                notes+="- 📚 **Docs**: ${commit#docs: }\n"
            elif [[ $commit == refactor* ]]; then
                notes+="- ♻️ **Refactor**: ${commit#refactor: }\n"
            elif [[ $commit == test* ]]; then
                notes+="- 🧪 **Test**: ${commit#test: }\n"
            else
                notes+="- ✨ **Feature**: $commit\n"
            fi
        done <<< "$commits"
    else
        notes+="- No new commits since last release\n"
    fi
    
    notes+="\n---\n*Generated automatically from git commits*"
    
    echo -e "$notes"
}

# Function to update changelog
update_changelog() {
    local version=$1
    local release_notes=$2
    
    info "Updating CHANGELOG.md..."
    
    local temp_file=$(mktemp)
    local date=$(date '+%Y-%m-%d')
    
    # Create new changelog entry
    echo "# Changelog" > "$temp_file"
    echo "" >> "$temp_file"
    echo "## [v$version] - $date" >> "$temp_file"
    echo "" >> "$temp_file"
    echo -e "$release_notes" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Append existing changelog if it exists and has content
    if [ -s "CHANGELOG.md" ] && [ "$(head -1 CHANGELOG.md)" != "# Changelog" ]; then
        echo "# Changelog" > CHANGELOG.md
        echo "" >> CHANGELOG.md
    fi
    
    if [ -s "CHANGELOG.md" ]; then
        # Skip the first two lines (# Changelog and empty line) if they exist
        if head -1 CHANGELOG.md | grep -q "# Changelog"; then
            tail -n +3 CHANGELOG.md >> "$temp_file"
        else
            cat CHANGELOG.md >> "$temp_file"
        fi
    fi
    
    mv "$temp_file" CHANGELOG.md
    success "Updated CHANGELOG.md"
}

# Function to create artifacts
create_artifacts() {
    info "Creating release artifacts..."
    
    # Create dist directory if it doesn't exist
    mkdir -p dist
    
    # Create EventRunner6.fqa
    if [ -f "src/eventrunner.lua" ]; then
        info "Creating dist/EventRunner6.fqa..."
        plua -t pack src/eventrunner.lua dist/EventRunner6.fqa
        success "Created dist/EventRunner6.fqa"
    else
        warning "src/eventrunner.lua not found, skipping EventRunner6.fqa"
    fi
    
    # Create ERUpdater.fqa
    if [ -f "src/updater.lua" ]; then
        info "Creating dist/ERUpdater.fqa..."
        plua -t pack src/updater.lua dist/ERUpdater.fqa
        success "Created dist/ERUpdater.fqa"
    else
        warning "src/updater.lua not found, skipping ERUpdater.fqa"
    fi
}

# Function to commit and push changes
commit_and_push() {
    local version=$1
    
    info "Committing release changes..."
    
    # Add all changed files
    git add .version CHANGELOG.md
    
    # Add source files that may have been updated
    [ -f "src/rule.lua" ] && git add src/rule.lua
    [ -f "src/eventrunner.lua" ] && git add src/eventrunner.lua
    [ -f "src/updater.lua" ] && git add src/updater.lua
    
    # Add artifacts if they exist
    [ -f "dist/EventRunner6.fqa" ] && git add dist/EventRunner6.fqa
    [ -f "dist/ERUpdater.fqa" ] && git add dist/ERUpdater.fqa
    
    # Commit the changes
    git commit -m "chore: release v$version

- Update version to $version in all files
- Update CHANGELOG.md with release notes
- Generate release artifacts (dist/EventRunner6.fqa, dist/ERUpdater.fqa)"
    
    success "Committed release changes"
    
    info "Pushing changes to remote..."
    # Push changes
    git push origin $(git branch --show-current)
    
    success "Pushed all changes to remote"
}

# Function to create and push tag
create_and_push_tag() {
    local version=$1
    local release_notes=$2
    
    info "Creating and pushing release tag..."
    
    # Create annotated tag with release notes
    git tag -a "v$version" -m "Release v$version

$release_notes"
    
    # Push the tag
    git push origin "v$version"
    
    success "Created and pushed tag v$version"
}

# Main function
main() {
    echo -e "${CYAN}[INFO] 🚀 GitHub Release Helper for EventRunner${NC}"
    echo ""
    
    # Check dependencies and git status
    check_dependencies
    check_git_status
    
    # Get current version
    local current_version=$(get_current_version)
    info "Current version: $current_version"
    
    # Version selection
    echo ""
    echo "Select version bump type:"
    echo "1) Patch ($current_version → $(increment_version $current_version patch))"
    echo "2) Minor ($current_version → $(increment_version $current_version minor))"
    echo "3) Major ($current_version → $(increment_version $current_version major))"
    echo "4) Custom version"
    echo ""
    
    local new_version
    while true; do
        read -p "Choice (1-4): " choice
        case $choice in
            1)
                new_version=$(increment_version $current_version patch)
                break
                ;;
            2)
                new_version=$(increment_version $current_version minor)
                break
                ;;
            3)
                new_version=$(increment_version $current_version major)
                break
                ;;
            4)
                read -p "Enter custom version (X.Y.Z): " new_version
                if [[ $new_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    break
                else
                    error "Invalid version format. Please use X.Y.Z format."
                fi
                ;;
            *)
                error "Invalid choice. Please select 1-4."
                ;;
        esac
    done
    
    # Release notes selection
    echo ""
    echo "Release notes options:"
    echo "1) Auto-generate from git commits since last release"
    echo "2) Enter custom release notes"
    echo "3) Use simple default message"
    echo ""
    
    local release_notes
    while true; do
        read -p "Choice (1-3): " notes_choice
        case $notes_choice in
            1)
                local last_tag=$(get_last_release_tag)
                if [ -z "$last_tag" ]; then
                    warning "No previous releases found. Generating from all commits."
                else
                    info "Generating release notes from commits since $last_tag..."
                fi
                release_notes=$(generate_release_notes "$last_tag" "$new_version")
                break
                ;;
            2)
                echo "Enter release notes (press Ctrl+D when finished):"
                release_notes=$(cat)
                break
                ;;
            3)
                release_notes="Release v$new_version

This release includes various improvements and bug fixes."
                break
                ;;
            *)
                error "Invalid choice. Please select 1-3."
                ;;
        esac
    done
    
    # Show generated release notes and confirm
    echo ""
    info "Generated release notes:"
    echo -e "$release_notes"
    echo ""
    
    read -p "Use these release notes? (Y/n): " confirm_notes
    if [[ $confirm_notes =~ ^[nN]$ ]]; then
        echo "Enter custom release notes (press Ctrl+D when finished):"
        release_notes=$(cat)
    fi
    
    # Final confirmation
    echo ""
    info "📋 Release Summary:"
    echo "  Version: $new_version"
    echo "  Notes: $release_notes"
    echo ""
    
    read -p "Create this release? (y/N): " final_confirm
    if [[ ! $final_confirm =~ ^[yY]$ ]]; then
        info "Release cancelled."
        exit 0
    fi
    
    # Execute release steps
    echo ""
    info "🚀 Creating release v$new_version..."
    echo ""
    
    # Step 1: Update version in files
    info "Step 1: Updating version in source files..."
    ./scripts/setversion.sh "$new_version"
    
    # Step 2: Update changelog
    info "Step 2: Updating CHANGELOG.md..."
    update_changelog "$new_version" "$release_notes"
    
    # Step 3: Create artifacts
    info "Step 3: Creating release artifacts..."
    create_artifacts
    
    # Step 4: Commit and push all changes
    info "Step 4: Committing and pushing changes..."
    commit_and_push "$new_version"
    
    # Step 5: Create and push tag (this creates the GitHub release)
    info "Step 5: Creating and pushing release tag..."
    create_and_push_tag "$new_version" "$release_notes"
    
    echo ""
    success "🎉 Release v$new_version created successfully!"
    info "GitHub release will be available at: https://github.com/jangabrielsson/EventRunner6/releases/tag/v$new_version"
}

# Run main function
main "$@"
