#!/bin/bash

set -e

# Constants
COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"
BRANCH_NAME="${GITHUB_ACTOR}-dep-updates"
LOG_FILE="dependency-updater.log"

# Ensure necessary commands are available
command -v ncu >/dev/null 2>&1 || { echo "❌ 'ncu' not found, please install it."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "❌ 'jq' not found, please install it."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "❌ 'gh' not found, please install GitHub CLI."; exit 1; }

# Ensure GitHub CLI is authenticated
gh auth status || { echo "❌ GitHub CLI not authenticated."; exit 1; }

# Logging function to log to file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Detect Dependencies files
dependencies_detection() {
    log "📂 Checking for dependencies file..."
    if [[ -f "package.json" ]]; then
        log "Detected package.json"
        echo "package.json"
    elif [[ -f "requirements.txt" ]]; then
        log "Detected requirements.txt"
        echo "requirements.txt"
    elif [[ -f "Dockerfile" ]]; then
        log "Detected Dockerfile"
        echo "Dockerfile"
    else 
        log "No dependencies file found"
        exit 1
    fi
}

# Update dependencies
dependencies_update() {
    case "$1" in
    "package.json")
        log "🔄 Updating Node.js dependencies..."
        ncu -u || { log "❌ Failed to update Node.js dependencies."; exit 1; }
        npm install || { log "❌ Failed to install Node.js dependencies."; exit 1; }
        ;;
    "requirements.txt")
        log "🔄 Updating Python dependencies..."
        pip list --outdated --format=freeze | cut -d= -f1 | xargs -n1 pip install -U || { log "❌ Failed to update Python dependencies."; exit 1; }
        ;;
    "Dockerfile")
        log "🔄 Updating Docker base images..."
        tmp_file=$(mktemp)

        while IFS= read -r line; do
            if [[ $line == FROM* ]]; then
                base_image=$(echo "$line" | awk '{print $2}')
                if [[ -z "$base_image" ]]; then
                    log "⚠️ Skipping empty FROM line."
                    continue
                fi

                image_name="${base_image%%:*}"
                log "Checking latest version for $base_image..."

                latest_tag=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/$image_name/tags" | jq -r '.results[].name' | grep -E '^[0-9]+' | sort -V | tail -n 1)

                if [[ -n "$latest_tag" && "$base_image" != "$image_name:$latest_tag" ]]; then
                    new_image="$image_name:$latest_tag"
                    line="FROM $new_image"
                fi
            fi
            echo "$line"
        done < Dockerfile > "$tmp_file"

        mv "$tmp_file" Dockerfile
        ;;
    *)
        log "❌ Unsupported dependencies file format: $1"
        exit 1
        ;;
    esac
}

# Run tests
run_test() {
    log "🧪 Running tests..."
    if [[ -f "package.json" ]]; then
        npm test || { log "❌ Tests failed"; exit 1; }
    elif [[ -f "requirements.txt" ]]; then
        pytest || { log "❌ Tests failed"; exit 1; }
    fi
    log "✅ All tests passed successfully"
}

# Generate the Changelog
generate_changelog() {
    log "📝 Generating Changelog..."
    case "$1" in
    "package.json")
        ncu > changelog.txt || { log "❌ Failed to generate changelog"; exit 1; }
        ;;
    "requirements.txt")
        pip list --outdated > changelog.txt || { log "❌ Failed to generate changelog"; exit 1; }
        ;;
    "Dockerfile")
        echo "Updated Docker base images to latest versions." > changelog.txt
        ;;
    esac
    log "✅ Changelog generated successfully"
    cat changelog.txt
}

# Commit and push changes
commit_and_push() {
    log "📦 Committing and pushing changes..."
    git checkout -b "$BRANCH_NAME"
    git add . || { log "❌ Git add failed"; exit 1; }
    git commit -m "$COMMIT_MESSAGE" || { log "❌ Git commit failed"; exit 1; }
    git push -u origin "$BRANCH_NAME" || { log "❌ Git push failed"; exit 1; }
    log "✅ Changes committed and pushed successfully"
}

# Create pull request
create_pull_request() {
    log "🔀 Creating pull request..."
    gh pr create --title "Dependency updates" --body "$(cat changelog.txt)" --base "$MAIN_BRANCH" --head "$BRANCH_NAME" || { log "❌ Pull request creation failed"; exit 1; }
    log "✅ Pull request created successfully"
}

# Main function
main() {
    log "Running Dependency Updater Script..."
    file=$(dependencies_detection)  # Capture the file detected
    log "📂 Detected dependencies file: $file"

    dependencies_update "$file"
    run_test
    generate_changelog "$file"
    commit_and_push
    create_pull_request

    log "🎉 Dependency update process completed successfully"
}

main
