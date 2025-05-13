#!/bin/bash

# Make sure you got permission by running "chmod +x renameEditedFiles.sh" before executing the script.
# To run script use this command ./renameEditedFiles.sh /path/to/your/folder

# Default folder variable (in case no folder is provided as an argument)
default_folder="/Volumes/Lexar_SL500/MEGA_sync/с телефона Артема 3" # Replace this with your desired folder path or leave as "<absolute_path_to_folder>"

# Folder to process, either provided as an argument or defaults to $default_folder
folder="${1:-$default_folder}"

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
    echo -e "${color}renameImgFiles | ${message}${NC}"
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

# Process all files that start with IMG_E
processed_files=0

for file in IMG_E*; do
    [ -f "$file" ] || continue  # Skip if not a file

    # Extract the base name and extension
    filename_without_ext="${file%.*}" # Remove the file extension
    extension="${file##*.}" # Get the file extension

    # Check if the filename starts with IMG_E and has at least one character after E
    if [[ "$filename_without_ext" =~ ^IMG_E(.*) ]]; then
        new_filename_without_ext="IMG_${BASH_REMATCH[1]}E"
        new_file="${new_filename_without_ext}.${extension}"

        # Rename the file
        if mv "$file" "$new_file"; then
            log $SUCCESS "Successfully renamed $file to $new_file"
            processed_files=$((processed_files + 1))
        else
            log $ERROR "Failed to rename $file to $new_file"
        fi
    else
        log $INFO "File $file does not match the expected pattern, skipping."
    fi
done

# Disable case-insensitive globbing after processing
shopt -u nocaseglob

# Final summary
if [ $processed_files -gt 0 ]; then
    log $SUCCESS "Total files processed: $processed_files"
else
    log $INFO "No files were processed."
fi