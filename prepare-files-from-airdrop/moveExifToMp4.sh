#!/bin/bash

# Make sure you got permission by running "chmod +x moveExifToMp4.sh" before executing the script.
# To run script use this command ./moveExifToMp4.sh /path/to/your/folder [filename_without_extension]
# If filename is provided, only that file will be processed instead of all files in the folder.

# Default folder variable (in case no folder is provided as an argument)
default_folder="/Volumes/Lexar_SL500/MEGA_sync/с олиного телефона" # Replace this with your desired folder path or leave as "<absolute_path_to_folder>"

# Folder to process, either provided as an argument or defaults to $default_folder
folder="${1:-$default_folder}"

# Optional filename (without extension) to process only a specific file
filename="$2"

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
    echo -e "${color}moveExifToMp4 | ${message}${NC}"
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

# Process files based on whether a specific filename was provided
processed_files=0

# Function to process a single file
process_file() {
    local source_file="$1"
    local filename_without_ext="${source_file%.*}"
    local target_file="${filename_without_ext}.mp4"
    
    # Check for MP4 file with case insensitivity
    if [ ! -f "$target_file" ] && [ ! -f "${filename_without_ext}.MP4" ]; then
        log $INFO "Corresponding MP4 file not found for: $source_file, skipping."
        return
    fi
    
    # Use the actual MP4 file that exists (preserving case)
    if [ ! -f "$target_file" ] && [ -f "${filename_without_ext}.MP4" ]; then
        target_file="${filename_without_ext}.MP4"
    fi
    
    log $MAIN "Copying EXIF data from: $source_file to $target_file"
    
    # Run exiftool to move the EXIF data
    if exiftool -TagsFromFile "$source_file" -extractEmbedded "$target_file"; then
        log $SUCCESS "Successfully moved EXIF data from $source_file to $target_file"
        processed_files=$((processed_files + 1))
    else
        log $ERROR "Failed to move EXIF data from $source_file to $target_file"
    fi
}

# If a specific filename was provided, process only that file
if [ -n "$filename" ]; then
    log $INFO "Processing only file: $filename"
    
    # Check for both .mov and .avi extensions (case-insensitive)
    if [ -f "${filename}.mov" ] || [ -f "${filename}.MOV" ]; then
        # Use the actual file extension that exists (preserving case)
        if [ -f "${filename}.mov" ]; then
            process_file "${filename}.mov"
        else
            process_file "${filename}.MOV"
        fi
    elif [ -f "${filename}.avi" ] || [ -f "${filename}.AVI" ]; then
        # Use the actual file extension that exists (preserving case)
        if [ -f "${filename}.avi" ]; then
            process_file "${filename}.avi"
        else
            process_file "${filename}.AVI"
        fi
    else
        log $ERROR "File not found: $filename.mov or $filename.avi"
    fi
else
    # Process all .mov and .avi files (case-insensitive)
    # The nocaseglob option ensures *.{mov,avi} matches both uppercase and lowercase extensions
    for file in *.[Mm][Oo][Vv] *.[Aa][Vv][Ii]; do
        [ -f "$file" ] || continue  # Skip if not a file
        process_file "$file"
    done
fi

# Disable case-insensitive globbing after processing
shopt -u nocaseglob

# Final summary
if [ $processed_files -gt 0 ]; then
    log $SUCCESS "Total files processed: $processed_files"
else
    log $INFO "No files were processed."
fi