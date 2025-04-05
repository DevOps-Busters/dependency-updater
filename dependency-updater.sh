#!/bin/bash

set -e

# Constants
COMMIT_MESSAGE="Upgraded Dependencies"
MAIN_BRANCH="main"
BRANCH_NAME="${GITHUB_ACTOR}-dep-updates"

# Detect Dependencies files (recursive)
dependencies_detection() {
    echo "📂 Checking for dependencies file..."

    if find . -name "package.json" | grep -q .; then
        echo "package.json"
    elif find . -name "Dockerfile" | grep -q .; then
        echo "Dockerfile"
    elif find . -name "pom.xml" -o -name "build.gradle" | grep -q .; then
        echo "Java"
    elif find . -name "requirements.txt" -o -name "pyproject.toml" | grep -q .; then
        echo "Python"
    else
        echo "No dependencies file found"
        exit 0
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

    "Dockerfile")
        echo "🔄 Updating Docker base images..."
        tmp_file=$(mktemp)
        while IFS= read -r line; do
            if [[ $line == FROM* ]]; then
                base_image=$(echo "$line" | awk '{print $2}')
                image_name="${base_image%%:*}"
                latest_tag=$(curl -s "https://registry.hub.docker.com/v2/repositories/library/$image_name/tags" | \
                    jq -r '.results[].name' | grep -E '^[0-9]+' | sort -V | tail -n 1)

                if [[ -n "$latest_tag" && "$base_image" != "$image_name:$latest_tag" ]]; then
                    line="FROM $image_name:$latest_tag"
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

    "Python")
        echo "🔄 Updating Python dependencies..."
        if command -v pip-compile &> /dev/null; then
            # If pip-tools is installed, use it
            pip-compile --upgrade
        elif [[ -f "requirements.txt" ]]; then
            pip install --upgrade -r requirements.txt
            pip freeze > requirements.txt
        else
            echo "❌ Python dependencies file not found."
            exit 1
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

    elif [[ -f "pom.xml" || -f "build.gradle" ]]; then
        mvn test || { echo "❌ Tests failed"; exit 1; }

    elif [[ -f "requirements.txt" || -f "pyproject.toml" ]]; then
        if [[ -f "pytest.ini" || -d "tests" ]]; then
            pytest || { echo "❌ Tests failed"; exit 1; }
        else
            echo "⚠️ No Python tests found, skipping test step."
        fi
    fi

    echo "✅ All tests passed successfully"
}

# Generate changelog
generate_changelog() {
    echo "📝 Generating Changelog..."
    case "$1" in
    "package.json")
        ncu > changelog.txt
        ;;
    "Dockerfile")
        echo "Updated Docker base images to latest versions." > changelog.txt
        ;;
    "Java")
        echo "Updated Java dependencies to latest versions." > changelog.txt
        ;;
    "Python")
        echo "Updated Python dependencies using pip or pip-tools." > changelog.txt
        ;;
    esac
    echo "✅ Changelog generated successfully"
    cat changelog.txt
}

commit_and_push() {
    echo "📦 Committing and pushing changes..."
    git checkout -b "$BRANCH_NAME"
    git add .
    git commit -m "$COMMIT_MESSAGE"
    git push -u origin "$BRANCH_NAME"
    echo "✅ Changes committed and pushed successfully"
}

create_pull_request() {
    echo "🔀 Creating pull request..."
    gh pr create --title "Dependency updates" --body "$(cat changelog.txt)" --base "$MAIN_BRANCH" --head "$BRANCH_NAME"
    echo "✅ Pull request created successfully"
}

main() {
    file=$(dependencies_detection | tail -n1)

    if [[ "$file" == "No dependencies file found" ]]; then
        echo "⚠️ No dependency file detected. Skipping update process."
        exit 0
    fi

    echo "📂 Detected dependencies file: $file"

    dependencies_update "$file"
    run_test
    generate_changelog "$file"
    commit_and_push
    create_pull_request

    echo "🎉 Dependency update process completed successfully"
}

main
