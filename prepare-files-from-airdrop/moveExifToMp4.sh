#!/bin/bash

# Make sure you got permission by running "chmod +x moveExifToMp4.sh" before executing the script.
# To run script use this command ./moveExifToMp4.sh /path/to/your/folder [filename_with_extension]
# If filename is provided, only that file will be processed instead of all files in the folder.

# Default folder variable (in case no folder is provided as an argument)
default_folder="/Users/artempriadkin/Downloads" # Replace this with your desired folder path or leave as "<absolute_path_to_folder>"
default_filename=""
# Folder to process, either provided as an argument or defaults to $default_folder
folder="${1:-$default_folder}"
# Optional filename (with extension) to process only a specific file
filename="${2:-$default_filename}"

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
    local mp4_files_found=0
    
    log $MAIN "Looking for MP4 files that start with: $filename_without_ext"
    
    # Find all MP4 files that start with the same name (case-insensitive)
    # This will match files like: 123.mp4, 123_prefix.mp4, 123_anotherPrefix.mp4, etc.
    for mp4_file in *.[Mm][Pp][44]; do
        [ -f "$mp4_file" ] || continue  # Skip if not a file
        
        # Get the filename without extension
        local mp4_filename_without_ext="${mp4_file%.*}"
        
        # Check if this MP4 file starts with the same name as the source file
        # Using case-insensitive comparison
        if [[ "$(echo "$mp4_filename_without_ext" | tr '[:upper:]' '[:lower:]')" == "$(echo "$filename_without_ext" | tr '[:upper:]' '[:lower:]')"* ]]; then
            log $MAIN "Found matching MP4 file: $mp4_file"
            log $MAIN "Copying EXIF data from: $source_file to $mp4_file"
            
            # Run exiftool to move the EXIF data
            if exiftool -TagsFromFile "$source_file" -All:All -extractEmbedded -overwrite_original "$mp4_file"; then
                log $SUCCESS "Successfully moved EXIF data from $source_file to $mp4_file"
                processed_files=$((processed_files + 1))
                mp4_files_found=$((mp4_files_found + 1))
            else
                log $ERROR "Failed to move EXIF data from $source_file to $mp4_file"
            fi
        fi
    done
    
    if [ $mp4_files_found -eq 0 ]; then
        log $INFO "No matching MP4 files found for: $source_file, skipping."
    else
        log $SUCCESS "Processed $mp4_files_found MP4 file(s) for: $source_file"
    fi
}

# If a specific filename was provided, process only that file
if [ -n "$filename" ]; then
    log $INFO "Processing only file: $filename"
    
    # Check if the file exists with the provided extension
    if [ -f "$filename" ]; then
        # Extract the file extension to validate it's a supported format
        file_extension="${filename##*.}"
        # Convert to lowercase for case-insensitive comparison (macOS compatible)
        file_extension_lower=$(echo "$file_extension" | tr '[:upper:]' '[:lower:]')
        case "$file_extension_lower" in
            mov|avi)
                process_file "$filename"
                ;;
            *)
                log $ERROR "Unsupported file extension: $file_extension. Only .mov and .avi files are supported."
                ;;
        esac
    else
        log $ERROR "File not found: $filename"
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