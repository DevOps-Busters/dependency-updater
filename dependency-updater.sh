#!/bin/bash

set -e

# Constants
COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"
BRANCH_NAME="${GITHUB_ACTOR}-dep-updates"

# Detect Dependencies files
dependencies_detection() {
    echo "📂 Checking for dependencies file..."
    if [[ -f "package.json" ]]; then
        echo "Detected package.json"
        echo "package.json"  # Return the file name
    elif [[ -f "requirements.txt" ]]; then
        echo "Detected requirements.txt"
        echo "requirements.txt"  # Return the file name
    else
        echo "No dependencies file found"
        exit 1
    fi
}

# Update dependencies
dependencies_update() {
    echo "🔄 Updating dependencies for $1"
    case "$1" in
    "requirements.txt")
        echo "🔄 Updating Python dependencies..."
        # Update the Python dependencies
        pip install --upgrade -r requirements.txt

        # Regenerate the requirements.txt file to reflect updated dependencies
        pip freeze > requirements.txt
        ;;

    *)
        echo "❌ Unsupported dependencies file format: $1"
        exit 1
        ;;
    esac
}

# Commit and push changes
commit_and_push() {
    echo "📦 Committing and pushing changes..."
    git checkout -b "$BRANCH_NAME"
    git add requirements.txt
    git commit -m "$COMMIT_MESSAGE"
    git push -u origin "$BRANCH_NAME"
    echo "✅ Changes committed and pushed successfully"
}

# Main function
main() {
    file=$(dependencies_detection)
    echo "📂 Detected dependencies file: $file"

    dependencies_update "$file"
    commit_and_push

    echo "🎉 Dependency update process completed successfully"
}

main
