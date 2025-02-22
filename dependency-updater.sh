#!/bin/bash

set -e

# Constants
COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"

# Dynamic branch name
BRANCH_NAME="${GITHUB_ACTOR}-dep-updates"

# Detect Dependencies files
dependencies_detection() {
    echo "📂 Checking for dependencies file..."
    if [[ -f "package.json" ]]; then
        echo "package.json"
    # elif [[ -f "requirements.txt" ]]; then
    #     echo "requirements.txt"
    elif [[ -f "Dockerfile" ]]; then
        echo "Dockerfile"
    elif [[ -f "pom.xml" || -f "build.gradle" ]]; then
        echo "Java"
    else 
        echo "No dependencies file found"
        exit 1
    fi
}

# Update dependencies
dependencies_update() {
    echo "🔄 Updating dependencies for $1"
    case "$1" in
    "package.json")
        echo "🔄 Updating Node.js dependencies..."
        ncu -u
        npm install
        ;;

    # "requirements.txt")
    #     echo "🔄 Updating Python dependencies..."
        
    #     # Extract outdated package names and upgrade them
    #     outdated_packages=$(pip list --outdated --format=columns | awk 'NR>2 {print $1}')

    #     if [[ -n "$outdated_packages" ]]; then
    #         echo "Upgrading: $outdated_packages"
    #         echo "$outdated_packages" | xargs -n1 pip install --upgrade
    #     else
    #         echo "✅ All dependencies are already up to date."
    #     fi
    #     ;;

    "Dockerfile")
        echo "🔄 Updating Docker base images..."
        tmp_file=$(mktemp)

        while IFS= read -r line; do
            if [[ $line == FROM* ]]; then
                base_image=$(echo "$line" | awk '{print $2}')
                
                if [[ -z "$base_image" ]]; then
                    echo "⚠️ Skipping empty FROM line."
                    continue
                fi

                image_name="${base_image%%:*}"
                echo "Checking latest version for $base_image..."

                latest_tag=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/$image_name/tags" | \
                    jq -r '.results[].name' | grep -E '^[0-9]+' | sort -V | tail -n 1)

                if [[ -n "$latest_tag" && "$base_image" != "$image_name:$latest_tag" ]]; then
                    new_image="$image_name:$latest_tag"
                    line="FROM $new_image"
                fi
            fi
            echo "$line"
        done < Dockerfile > "$tmp_file"

        mv "$tmp_file" Dockerfile
        ;;

    "Java")
        echo "🔄 Updating Java dependencies..."
        if [[ -f "pom.xml" ]]; then
            mvn versions:use-latest-versions
        elif [[ -f "build.gradle" ]]; then
            ./gradlew --refresh-dependencies
        fi
        ;;

    *)
        echo "❌ Unsupported dependencies file format: $1"
        exit 1
        ;;
    esac
}

# Run tests
run_test() {
    echo "🧪 Running tests..."
    
    if [[ -f "package.json" ]]; then
        npm test || { echo "❌ Tests failed"; exit 1; }
    
    # elif [[ -f "requirements.txt" ]]; then
    #     if ! command -v pytest &> /dev/null; then
    #         echo "⚠️ pytest not found. Installing pytest..."
    #         pip install pytest
    #     fi
    #     pytest || { echo "❌ Tests failed"; exit 1; }
    
    elif [[ -f "pom.xml" || -f "build.gradle" ]]; then
        mvn test || { echo "❌ Tests failed"; exit 1; }
    fi
    
    echo "✅ All tests passed successfully"
}


# Generate the Changelog
generate_changelog() {
    echo "📝 Generating Changelog..."
    case "$1" in
    "package.json")
        ncu > changelog.txt
        ;;

    # "requirements.txt")
    #     pip list --outdated > changelog.txt
    #     ;;

    "Dockerfile")
        echo "Updated Docker base images to latest versions." > changelog.txt
        ;;

    "Java")
        echo "Updated Java dependencies to latest versions." > changelog.txt
        ;;
    esac
    echo "✅ Changelog generated successfully"
    cat changelog.txt
}

# Commit and push changes
commit_and_push() {
    echo "📦 Committing and pushing changes..."
    git checkout -b "$BRANCH_NAME"
    git add .
    git commit -m "$COMMIT_MESSAGE"
    git push -u origin "$BRANCH_NAME"
    echo "✅ Changes committed and pushed successfully"
}

# Create pull request
create_pull_request() {
    echo "🔀 Creating pull request..."
    gh pr create --title "Dependency updates" --body "$(cat changelog.txt)" --base "$MAIN_BRANCH" --head "$BRANCH_NAME"
    echo "✅ Pull request created successfully"
}

# Main function
main() {
    file=$(dependencies_detection | tail -n1)
    echo "📂 Detected dependencies file: $file"

    dependencies_update "$file"
    run_test
    generate_changelog "$file"
    commit_and_push
    create_pull_request

    echo "🎉 Dependency update process completed successfully"
}

main