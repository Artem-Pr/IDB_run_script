#!/bin/bash

# Make sure you got permission by running "chmod +x cleanFiles.sh" before executing the script.
# To run the script use this command ./cleanFiles.sh /path/to/your/folder

# Default folder variable (in case no folder is provided as an argument)
default_folder="/Users/artempriadkin/Downloads/1" # Replace this with your desired folder path or leave as "<absolute_path_to_folder>"

# Folder to process, either provided as an argument or defaults to $default_folder
folder="${1:-$default_folder}"

# Specify the extensions to delete
extensionsToDelete=(
    "aae"
    # "avi"
    # "mov"
    # "mp4_original"
)

# Define color variables
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

SUCCESS=$GREEN
ERROR=$RED
INFO=$YELLOW
MAIN=$CYAN

# Function to log messages with color
log() {
    local color=$1
    local message=$2
    echo -e "${color}cleanFiles | ${message}${NC}"
}

# Ensure the script runs in the specified folder
if [ -z "$folder" ] || [ "$folder" == "<absolute_path_to_folder>" ]; then
    log $ERROR "No folder specified and default folder is not set correctly. Exiting."
    exit 1
fi

if [ -d "$folder" ]; then
    cd "$folder" || {
        log $ERROR "Failed to switch to the specified folder: $folder. Exiting."
        exit 1
    }
else
    log $ERROR "Specified folder does not exist: $folder. Exiting."
    exit 1
fi

# Enable case-insensitive globbing for file extensions
shopt -s nullglob
shopt -s nocaseglob

deleted_files=0

# Loop through the specified extensions and delete matching files
for ext in "${extensionsToDelete[@]}"; do
    for file in *."$ext"; do
        [ -f "$file" ] || continue  # Skip if not a file
        log $MAIN "Deleting file: $file"
        if rm "$file"; then
            log $SUCCESS "Successfully deleted: $file"
            deleted_files=$((deleted_files + 1))
        else
            log $ERROR "Failed to delete: $file"
        fi
    done
done

# Disable case-insensitive globbing after processing
shopt -u nocaseglob

# Final summary
if [ $deleted_files -gt 0 ]; then
    log $SUCCESS "Total files deleted: $deleted_files"
else
    log $INFO "No files were deleted."
fi