#!/bin/bash

# Make sure you got permission by running "chmod +x convertToMp4.sh" before executing the script.
# To run script use this command ./convertToMp4.sh /path/to/your/folder

# Default folder variable (in case no folder is provided as an argument)
default_folder="/Users/artempriadkin/Downloads/1" # Replace this with your desired folder path or leave as "<absolute_path_to_folder>"

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
    echo -e "${color}convertToMp4 | ${message}${NC}"
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

# Process all .mov and .avi files (case-insensitive)
processed_files=0

for file in *.{mov,avi}; do
    [ -f "$file" ] || continue  # Skip if not a file
    filename_without_ext="${file%.*}" # Remove the file extension
    output_file="${filename_without_ext}.mp4"

    if [ -f "$output_file" ]; then
        log $INFO "Output file already exists, skipping: $output_file"
        continue
    fi

    log $MAIN "Converting: $file to $output_file"

    # Run ffmpeg to convert the file
    if ffmpeg -i "$file" -c:v copy -c:a copy "$output_file"; then
        log $SUCCESS "Successfully converted: $file to $output_file"
        processed_files=$((processed_files + 1))
    else
        log $ERROR "Failed to convert: $file"
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