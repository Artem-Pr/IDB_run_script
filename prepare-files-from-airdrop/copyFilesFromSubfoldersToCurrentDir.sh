#!/bin/bash

# Make sure you got permission by running "chmod +x copyFilesFromSubfoldersToCurrentDir.sh" before executing the script.
# To run script use this command ./copyFilesFromSubfoldersToCurrentDir.sh /path/to/your/folder

# Default folder variable (in case no folder is provided as an argument)
default_folder="/Users/artempriadkin/Downloads/1" # Replace this with your desired folder path or leave as "<absolute_path_to_folder>"

# Folder to process, either provided as an argument or defaults to $default_folder
folder="${1:-$default_folder}"

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
    echo -e "${color}copy-test-files | ${message}${NC}"
}

# Initialize counters for moved files and deleted folders
moved_files=0
deleted_folders=0

# Function to generate a new filename if a file already exists
generate_new_filename() {
    local filename="$1"
    local extension="${filename##*.}"
    local basename="${filename%.*}"
    local new_filename="$filename"
    local counter=1

    while [ -e "./$new_filename" ]; do
        new_filename="${basename}_$(printf "%02d" $counter).$extension"
        counter=$((counter + 1))
    done

    echo "$new_filename"  # Return the new filename
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

# Ensure subdirectories exist
shopt -s nullglob
dirs=(*/)
if [ ${#dirs[@]} -eq 0 ]; then
    log $INFO "No subdirectories found to process."
    exit 0
fi

# Process each subdirectory
for dir in */; do
    [ -d "$dir" ] || continue  # Skip if not a directory
    log $MAIN "Processing directory: $dir"
    
    # Move all files from the directory to the current directory
    for file in "$dir"*; do
        [ -f "$file" ] || continue  # Skip if not a file
        filename="$(basename "$file")"
        
        # Check if file already exists and generate a new filename if needed
        if [ -e "./$filename" ]; then
            new_filename=$(generate_new_filename "$filename")
            if mv "$file" "./$new_filename"; then
                log $SUCCESS "Moved: $file to $new_filename"
            else
                log $ERROR "Failed to move: $file to $new_filename"
            fi
        else
            if mv "$file" .; then
                log $SUCCESS "Moved: $file"
            else
                log $ERROR "Failed to move: $file"
            fi
        fi
        moved_files=$((moved_files + 1))
    done

    # Remove the empty directory
    if rm -rf "$dir"; then
        log $SUCCESS "Deleted directory: $dir"
        deleted_folders=$((deleted_folders + 1))
    else
        log $ERROR "Failed to delete directory: $dir"
    fi
done

# Final output of the total number of moved files and deleted folders
log $SUCCESS "Total files moved to current directory: $moved_files"
log $SUCCESS "Total folders deleted: $deleted_folders"