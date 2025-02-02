#!/bin/bash

set -e

# Log file to capture all output
LOG_FILE="dependency-updater.log"

# Constants
COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"

# Dynamic branch name
BRANCH_NAME="${GITHUB_ACTOR}-dep-updates"

# Detect Dependencies files
dependencies_detection() {
    if [[ -f "package.json" ]]; then
        echo "package.json" >> "$LOG_FILE"
    elif [[ -f "requirements.txt" ]]; then
        echo "requirements.txt" >> "$LOG_FILE"
    elif [[ -f "Dockerfile" ]]; then
        echo "Dockerfile" >> "$LOG_FILE"
    else 
        echo "No dependencies file found" >> "$LOG_FILE"
        exit 1
    fi
}

# Update dependencies
dependencies_update() {
    case "$1" in
    "package.json")
        echo "🔄 Updating Node.js dependencies..." >> "$LOG_FILE"
        ncu -u >> "$LOG_FILE" 2>&1
        npm install >> "$LOG_FILE" 2>&1
        ;;
    "requirements.txt")
        echo "🔄 Updating Python dependencies..." >> "$LOG_FILE"
        # Use pip-review to upgrade outdated dependencies from requirements.txt
        pip-review --auto >> "$LOG_FILE" 2>&1
        ;;
    "Dockerfile")
        echo "🔄 Updating Docker base images..." >> "$LOG_FILE"
        tmp_file=$(mktemp)

        while IFS= read -r line; do
            if [[ $line == FROM* ]]; then
                base_image=$(echo "$line" | awk '{print $2}')
                if [[ -z "$base_image" ]]; then
                    echo "⚠️ Skipping empty FROM line." >> "$LOG_FILE"
                    continue
                fi

                # Extract image name (without tag)
                image_name="${base_image%%:*}"
                echo "Checking latest version for $base_image..." >> "$LOG_FILE"

                # Fetch latest tag from Docker Hub API
                latest_tag=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/$image_name/tags" | \
                    jq -r '.results[].name' | grep -E '^[0-9]+' | sort -V | tail -n 1)

                if [[ -n "$latest_tag" && "$base_image" != "$image_name:$latest_tag" ]]; then
                    new_image="$image_name:$latest_tag"
                    line="FROM $new_image"
                fi
            fi
            echo "$line" >> "$tmp_file"
        done < Dockerfile

        mv "$tmp_file" Dockerfile
        ;;
    *)
        echo "❌ Unsupported dependencies file format: $1" >> "$LOG_FILE"
        exit 1
        ;;
    esac
}

# Run tests
run_test() {
    echo "🧪 Running tests..." >> "$LOG_FILE"
    if [[ -f "package.json" ]]; then
        npm test >> "$LOG_FILE" 2>&1 || { echo "❌ Tests failed" >> "$LOG_FILE"; exit 1; }
    elif [[ -f "requirements.txt" ]]; then
        pytest >> "$LOG_FILE" 2>&1 || { echo "❌ Tests failed" >> "$LOG_FILE"; exit 1; }
    fi
    echo "✅ All tests passed successfully" >> "$LOG_FILE"
}

# Generate the Changelog
generate_changelog() {
    echo "📝 Generating Changelog..." >> "$LOG_FILE"
    case "$1" in
    "package.json")
        ncu >> "$LOG_FILE" 2>&1
        ;;
    "requirements.txt")
        pip list --outdated >> "$LOG_FILE" 2>&1
        ;;
    "Dockerfile")
        echo "Updated Docker base images to latest versions." >> "$LOG_FILE"
        ;;
    esac
    echo "✅ Changelog generated successfully" >> "$LOG_FILE"
    cat "$LOG_FILE"
}

# Commit and push changes
commit_and_push() {
    echo "📦 Committing and pushing changes..." >> "$LOG_FILE"
    git checkout -b "$BRANCH_NAME" >> "$LOG_FILE" 2>&1
    git add . >> "$LOG_FILE" 2>&1
    git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1
    git push -u origin "$BRANCH_NAME" >> "$LOG_FILE" 2>&1
    echo "✅ Changes committed and pushed successfully" >> "$LOG_FILE"
}

# Create pull request
create_pull_request() {
    echo "🔀 Creating pull request..." >> "$LOG_FILE"
    gh pr create --title "Dependency updates" --body "$(cat changelog.txt)" --base "$MAIN_BRANCH" --head "$BRANCH_NAME" >> "$LOG_FILE" 2>&1
    echo "✅ Pull request created successfully" >> "$LOG_FILE"
}

# Main function
main() {
    file=$(dependencies_detection)
    echo "📂 Detected dependencies file: $file" >> "$LOG_FILE"

    dependencies_update "$file"
    run_test
    generate_changelog "$file"
    commit_and_push
    create_pull_request

    echo "🎉 Dependency update process completed successfully" >> "$LOG_FILE"
}

main
