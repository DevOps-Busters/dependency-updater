#!/bin/bash

set -e

COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"

# dynamic branch-name
generate_branch_name() {
    local username=$(whoami) 
    local timestamp=$(date +%Y%m%d%H%M%S) 
    echo "${username}-dep-updates-${timestamp}"
}

# Detection of Dependencies files
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
        pip-review --auto
        ;;
    "Dockerfile")
        echo "Updating Docker dependencies... "
        while IFS= read -r line; do
            if [[ $line == *"FROM"* ]]; then
                base_image=$(echo $line | awk '{print $2}')
                latest_image=$(docker pull $base_image | grep "latest" | awk '{print $NF}')
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
        pip-review > changelog.txt
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
    local branch_name="$1"
    git checkout -b "$branch_name"
    git add .
    git commit -m "$COMMIT_MESSAGE"
    git push -u origin "$branch_name"
    echo "Changes committed and pushed successfully"
}

# Create pull request
create_pull_request() {
    echo "Creating pull request..."
    gh pr create --title "Dependency updates" --body "$(cat changelog.txt)" --base "$MAIN_BRANCH" --head "$1"
    echo "Pull request created successfully"
}

# Main function
main() {
    local branch_name=$(generate_branch_name)
    file=$(dependencies_detection)
    echo "Detected dependencies file: $file"
    echo "Using branch name: $branch_name"

    dependencies_update "$file"
    run_test
    generate_changelog "$file"
    commit_and_push "$branch_name"
    create_pull_request "$branch_name"

    echo "Dependency update process completed successfully"
}

main
