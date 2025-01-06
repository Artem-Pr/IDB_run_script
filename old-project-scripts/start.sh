#!/bin/bash

# Make sure to give it execute permission by running "chmod +x start.sh" before executing the script.
# chmod +x start.sh
# chmod +x stop.sh

# Define color variables
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

SUCCESS=$GREEN
ERROR=$RED
INFO=$PURPLE
MAIN=$CYAN

# Define GitHub URLs for the projects
PROJECT1_GIT_URL="https://github.com/Artem-Pr/IDB_Front_2.0.git"
PROJECT2_GIT_URL="https://github.com/Artem-Pr/ImageDataBaseBackend.git"

# New variable to track the build flag
BUILD_FLAG=false

# Define paths to the project directories and their corresponding branches
PROJECT1_PATH="./IDB_Front_2.0"
PROJECT1_BRANCH="main"

PROJECT2_PATH="./ImageDataBaseBackend" # Make sure this path is correct
PROJECT2_BRANCH="master"

# Function to parse command-line arguments
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --build) BUILD_FLAG=true ;;
            *) echo -e "${ERROR}Unknown parameter passed: $1${NC}"; exit 1 ;;
        esac
        shift
    done
}

# Function to apply color to a message
log() {
    local color=$1
    local message=$2
    echo -e "${color}IDB_run_script : ${message}${NC}"
}

# Function to clone a repository if the directory doesn't exist or is empty
clone_if_missing() {
    local project_path=$1
    local git_url=$2

    if [ ! -d "$project_path" ] || [ -z "$(ls -A "$project_path")" ]; then
        log $INFO "Directory '$project_path' is missing or empty. Cloning repository..."
        git clone "$git_url" "$project_path"
        if [ $? -eq 0 ]; then
            log $SUCCESS "Repository cloned successfully."
        else
            log $ERROR "Failed to clone the repository. Please check the URL and your connection."
            exit 1
        fi
    else
        log $SUCCESS "Directory '$project_path' already exists and is not empty."
    fi
}

# Function to check for updates in a git repository
check_for_updates() {
    local project_path=$1
    local branch_name=$2

    if [ -d "$project_path" ]; then
        log $INFO "Checking for updates in the repository at '$project_path' on branch '$branch_name'..."
        cd "$project_path" || return
        git fetch
        local updates=$(git rev-list HEAD...origin/"$branch_name" --count)
        if [ "$updates" -gt 0 ]; then
            log $SUCCESS "New updates found ($updates commit(s)). Pulling the latest changes..."
            git pull origin "$branch_name"
            cd - || return
            return 0
        else
            log $SUCCESS "No updates found. The repository '$project_path' is up-to-date."
            cd - || return
            return 1
        fi
    else
        log $ERROR "The project path '$project_path' does not exist."
        return 1
    fi
}

log $MAIN "Starting the update and Docker service management process..."

# Call the parse_args function with all the command-line arguments
parse_args "$@"

# Clone the repositories if necessary
# clone_if_missing "$PROJECT1_PATH" "$PROJECT1_GIT_URL"
clone_if_missing "$PROJECT2_PATH" "$PROJECT2_GIT_URL"

# Assume no updates are available initially
updates_available=false

# Check each project for updates
# if check_for_updates "$PROJECT1_PATH" "$PROJECT1_BRANCH"; then
#     updates_available=true
# fi
if check_for_updates "$PROJECT2_PATH" "$PROJECT2_BRANCH"; then
    updates_available=true
fi

# If updates are available, rebuild and start Docker services
if [ "$updates_available" = true ]; then
    log $INFO "Rebuilding images..."
    docker-compose down --rmi all
    docker-compose build --no-cache
    log $SUCCESS "Rebuilding process complete."
    log $INFO "Removing dangling images..."
    docker image prune -f
    log $SUCCESS "Dangling images removed."
fi

# Start or restart the Docker services
log $INFO "Starting or restarting the Docker services..."
if [ "$BUILD_FLAG" = true ]; then
    docker compose up -d --build
else
    docker compose up -d
fi
log $SUCCESS "Docker services are now running."

log $MAIN "Update and Docker service management process completed."