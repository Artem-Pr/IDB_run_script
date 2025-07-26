#!/bin/bash

# Make sure you got permission by running "chmod +x mainScript.sh" before executing the script.
# To run script use this command ./mainScript.sh /path/to/folder fileName.ext

# Default folder variable (used if no folder is provided as an argument)
# default_folder="/Volumes/Lexar_SL500/MEGA_sync/test" # Replace this with your desired folder path
default_folder="/Users/artempriadkin/Downloads"
# default_folder="/Volumes/Lexar_SL500/MEGA_sync/SSD/с телефона Артема 2"
# default_folder="/Volumes/Lexar_SL500/MEGA_sync/с олиного телефона"
# default_folder="/Volumes/Lexar_SL500/MEGA_sync/с телефона Артема"

# Folder to process, either provided as an argument or defaults to $default_folder
folder="${1:-$default_folder}"
# File name to process, provided as second argument
fileName="${2}"

# Array of scripts to run (use absolute or relative paths)
scripts_to_run=(
    # "./copyFilesFromSubfoldersToCurrentDir.sh"
    # "./convertToMp4.sh"
    # "./convertLarge4kMov_max_speed.sh"
    # ./convertLarge4kMov_max_speed.sh "" 500 32 28M
    "./moveExifToMp4.sh"
    # "./cleanFiles.sh"
    # "./renameEditedFiles.sh"
)

# Define color variables
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

SUCCESS=$GREEN
ERROR=$RED
INFO=$YELLOW
MAIN=$YELLOW

# Function to log messages with color
log() {
    local color=$1
    local message=$2
    echo -e "${color}mainScript | ${message}${NC}"
}

# Ensure the folder is valid
if [ -z "$folder" ] || [ "$folder" == "<absolute_path_to_folder>" ]; then
    log $ERROR "No folder specified and default folder is not set correctly. Exiting."
    exit 1
fi

if [ ! -d "$folder" ]; then
    log $ERROR "Specified folder does not exist: $folder. Exiting."
    exit 1
fi

# Check if fileName is provided (optional)
if [ -z "$fileName" ]; then
    log $INFO "No fileName specified. Running scripts without fileName parameter."
fi

# Display the list of scripts to run
if [ -n "$fileName" ]; then
    log $INFO "Run scripts for folder: $folder, fileName: $fileName"
else
    log $INFO "Run scripts for folder: $folder (no fileName specified)"
fi
for script in "${scripts_to_run[@]}"; do
    echo "- $script"
done

# Run each script, passing the folder and fileName as arguments
for script in "${scripts_to_run[@]}"; do
    log $MAIN "------------------------------------------------------------------"
    log $MAIN "Run $script"
    log $MAIN "------------------------------------------------------------------"

    if [ -x "$script" ]; then
        # Execute the script, passing the folder and fileName as arguments (if fileName is provided)
        if [ -n "$fileName" ]; then
            if "$script" "$folder" "$fileName"; then
                log $SUCCESS "Successfully ran: $script"
            else
                log $ERROR "Failed to execute: $script"
            fi
        else
            if "$script" "$folder"; then
                log $SUCCESS "Successfully ran: $script"
            else
                log $ERROR "Failed to execute: $script"
            fi
        fi
    else
        log $ERROR "Script is not executable or not found: $script"
    fi
done

# Final summary
log $SUCCESS "All scripts have been processed."