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

# Function to apply color to a message
log() {
    local color=$1
    local message=$2
    echo -e "${color}IDB_run_script : ${message}${NC}"
}

log $INFO "Running Docker containers:"
docker ps

# Stop the Docker containers
docker compose down
log $MAIN "Docker containers stopped."

log $INFO "Removing dangling images..."
docker image prune -f
log $SUCCESS "Dangling images removed."

log $INFO "Existed Docker images:"
docker images