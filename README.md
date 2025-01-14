# Dependency-Updater Script Documentation

This script automates the process of updating dependencies for Node.js, Python, and Docker projects. It detects the type of dependency file, updates the dependencies, runs tests, generates changelogs, commits the changes, and creates a pull request.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Script Overview](#script-overview)
   1. [Constants](#constants)
   2. [Functions](#functions)
      1. [dependencies_detection](#dependencies_detection)
      2. [dependencies_update](#dependencies_update)
      3. [run_test](#run_test)
      4. [generate_changelog](#generate_changelog)
      5. [commit_and_push](#commit_and_push)
      6. [create_pull_request](#create_pull_request)
   3. [Main Function](#main-function)
3. [Usage](#usage)

## Prerequisites ##

- **Node.js and npm** (for Node.js projects)
- **ncu (npm-check-updates)** installed globally (`npm install -g npm-check-updates`)
- **Python and pip** (for Python projects)
- **pip-review** installed (`pip install pip-review`)
- **Docker** (for Docker projects)
- **gh (GitHub CLI)** installed and authenticated
- **pytest** (for Python projects with tests)

## Script Overview

### Constants

- `BRANCH_NAME`: The name of the branch to create for dependency updates.
- `COMMIT_MESSAGE`: The commit message for the dependency updates.
- `MAIN_BRANCH`: The main branch of the repository.

### Functions

#### `dependencies_detection`

Detects the type of dependency file in the project directory.

- Checks for `package.json`, `requirements.txt`, and `Dockerfile`.
- Exits with an error message if no dependency file is found.

#### `dependencies_update`

Updates the dependencies based on the detected dependency file.

- For `package.json`: Runs `ncu -u` and `npm install`.
- For `requirements.txt`: Runs `pip-review --auto`.
- For `Dockerfile`: Updates the base image to the latest version.

#### `run_test`

Runs tests based on the detected dependency file.

- For `package.json`: Runs `npm test`.
- For `requirements.txt`: Runs `pytest`.

#### `generate_changelog`

Generates a changelog based on the detected dependency file.

- For `package.json`: Runs `ncu` and saves the output to `changelog.txt`.
- For `requirements.txt`: Runs `pip-review` and saves the output to `changelog.txt`.
- For `Dockerfile`: Writes a message indicating the Docker base image was updated to `changelog.txt`.

#### `commit_and_push`

Commits the changes and pushes them to a new branch.

- Creates a new branch with the name specified in `BRANCH_NAME`.
- Adds all changes and commits them with the message specified in `COMMIT_MESSAGE`.
- Pushes the branch to the remote repository.

#### `create_pull_request`

Creates a pull request using the GitHub CLI.

- Uses the changelog as the body of the pull request.
- Sets the base branch to `MAIN_BRANCH` and the head branch to `BRANCH_NAME`.

### Main Function

The main function orchestrates the entire process:

1. Detects the dependency file.
2. Updates the dependencies.
3. Runs tests.
4. Generates the changelog.
5. Commits and pushes the changes.
6. Creates a pull request.
