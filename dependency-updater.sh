#!/bin/bash

set -e

# Constants
COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"

# Dynamic branch name
BRANCH_NAME="${GITHUB_ACTOR}-dep-updates"

# Check if necessary tools are installed
check_dependencies() {
    if ! command -v gh &> /dev/null; then
        echo "GitHub CLI (gh) is not installed. Please install it."
        exit 1
    fi
    if ! command -v ncu &> /dev/null; then
        npm install -g npm-check-updates
    fi
}

# Detect Dependencies files
dependencies_detection() {
    if [[ -f "package.json" ]]; then
        echo "package.json"
    elif [[ -f "requirements.txt" ]]; then
        echo "requirements.txt"
    elif [[ -f "Dockerfile" ]]; then
        echo "Dockerfile"
    else 
        echo "No dependencies file found"
        exit 1
    fi
}

# Update dependencies
dependencies_update() {
    case "$1" in
    "package.json")
        echo "Updating Node.js dependencies... "
        ncu -u
        npm install
        ;;
    "requirements.txt")
        echo "Updating Python dependencies... "
        pip list --outdated --format=freeze | cut -d= -f1 | xargs -n1 pip install -U
        ;;
    "Dockerfile")
        echo "Updating Docker dependencies... "
        while IFS= read -r line; do
            if [[ $line == *"FROM"* ]]; then
                base_image=$(echo $line | awk '{print $2}')
                latest_image=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$base_image" | head -n1)
                sed -i "s|$base_image|$latest_image|g" Dockerfile
            fi
        done <Dockerfile
        ;;
    *)
        echo "Unsupported dependencies file format: $1"
        exit 1
        ;;
    esac
}

# Run tests
run_test() {
    echo "Running tests..."
    if [[ -f "package.json" ]]; then
        npm test || { echo "Tests failed"; exit 1; }
    elif [[ -f "requirements.txt" ]]; then
        pytest || { echo "Tests failed"; exit 1; }
    fi
    echo "All tests passed successfully"
}

# Generate the Changelogs
generate_changelog() {
    echo "Generating Changelogs..."
    case "$1" in
    "package.json")
        ncu > changelog.txt
        ;;
    "requirements.txt")
        pip list --outdated > changelog.txt
        ;;
    "Dockerfile")
        echo "Updated Docker base image..." > changelog.txt
        ;;
    esac
    echo "Changelogs generated successfully"
    cat changelog.txt
}

# Commit and push changes
commit_and_push() {
    echo "Committing and pushing changes..."
    git fetch origin
    if git rev-parse --verify origin/"$BRANCH_NAME"; then
        git checkout "$BRANCH_NAME"
        git pull
    else
        git checkout -b "$BRANCH_NAME"
    fi
    git add .
    git commit -m "$COMMIT_MESSAGE"
    git push -u origin "$BRANCH_NAME"
    echo "Changes committed and pushed successfully"
}

# Create pull request
create_pull_request() {
    echo "Creating pull request..."
    gh pr create --title "Dependency updates" --body "$(cat changelog.txt)" --base "$MAIN_BRANCH" --head "$BRANCH_NAME" || {
        echo "Failed to create pull request"
        exit 1
    }
    echo "Pull request created successfully"
}

# Main function
main() {
    check_dependencies
    file=$(dependencies_detection)
    echo "Detected dependencies file: $file"

    dependencies_update "$file"
    run_test
    generate_changelog "$file"
    commit_and_push
    create_pull_request

    echo "Dependency update process completed successfully"
}

main
