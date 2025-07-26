#!/bin/bash

# Convert large 4K high-FPS MOV files to optimized MP4 with HEVC
# Usage: ./convertLarge4kMov.sh /path/to/folder [min_size_mb]

# Default folder and minimum file size
default_folder="/Users/artempriadkin/Downloads/1"
min_size_mb="${2:-500}" # Default: 500MB
min_size_bytes=$((min_size_mb * 1024 * 1024))

# Folder to process
folder="${1:-$default_folder}"

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
MAIN=$CYAN
ANALYSIS=$BLUE

# Function to log messages with color
log() {
    local color=$1
    local message=$2
    echo -e "${color}convertLarge4kMov | ${message}${NC}"
}

# Function to get file size in bytes
get_file_size() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        stat -f%z "$file"
    else
        # Linux
        stat -c%s "$file"
    fi
}

# Function to get video properties using ffprobe
get_video_info() {
    local file="$1"
    
    # Get all video stream info in one call
    local video_info=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=s=x:p=0 "$file" 2>/dev/null)
    
    # Parse the combined output (format: widthxheightxfps)
    if [[ -n "$video_info" && "$video_info" != "N/A" ]]; then
        # Extract width, height, and fps from combined output
        local width=$(echo "$video_info" | cut -d'x' -f1)
        local height=$(echo "$video_info" | cut -d'x' -f2)
        local fps_raw=$(echo "$video_info" | cut -d'x' -f3)
        
        # Validate width and height
        if [[ -z "$width" || -z "$height" || "$width" == "N/A" || "$height" == "N/A" ]]; then
            echo "0x0 0"
            return 1
        fi
        
        # Convert fractional FPS to decimal
        local fps="0"
        if [[ -n "$fps_raw" && "$fps_raw" != "N/A" ]]; then
            if [[ $fps_raw == *"/"* ]]; then
                local numerator=$(echo "$fps_raw" | cut -d'/' -f1 | tr -d ' ')
                local denominator=$(echo "$fps_raw" | cut -d'/' -f2 | tr -d ' ')
                
                # Validate numerator and denominator are numbers
                if [[ "$numerator" =~ ^[0-9]+$ && "$denominator" =~ ^[0-9]+$ && $denominator -ne 0 ]]; then
                    fps=$(echo "scale=2; $numerator / $denominator" | bc -l 2>/dev/null)
                    # If bc fails, use awk as fallback
                    if [[ $? -ne 0 ]]; then
                        fps=$(awk "BEGIN {printf \"%.2f\", $numerator / $denominator}" 2>/dev/null)
                    fi
                fi
            else
                # If fps is already a number
                if [[ "$fps_raw" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                    fps="$fps_raw"
                fi
            fi
        fi
        
        # Ensure fps is a valid number
        if [[ ! "$fps" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            fps="0"
        fi
        
        echo "${width}x${height} ${fps}"
    else
        echo "0x0 0"
        return 1
    fi
}

# Function to check if video is 4K (3840x2160 or higher)
is_4k_or_higher() {
    local resolution="$1"
    local width=$(echo $resolution | cut -d'x' -f1)
    local height=$(echo $resolution | cut -d'x' -f2)
    
    # 4K is typically 3840x2160, but we'll also include other high resolutions
    if [[ $width -ge 3840 && $height -ge 2160 ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Function to convert video
convert_video() {
    local file="$1"
    local filename_without_ext="${file%.*}"
    local output_file="${filename_without_ext}_converted.mp4"
    
    if [ -f "$output_file" ]; then
        log $INFO "Output file already exists, skipping: $output_file"
        return 0
    fi
    
    log $MAIN "Converting: $file to $output_file"
    log $INFO "Using GPU-accelerated HEVC codec, reducing FPS to 30"
    log $INFO "Note: CPU usage may still be high due to demuxing and preprocessing"
    
    # Try GPU-accelerated conversion if available
    if [[ "$gpu_available" == "true" ]]; then
        log $INFO "Attempting GPU-accelerated conversion..."
        
        # Get video duration and frame count for progress calculation
        duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null)
        total_frames=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$file" 2>/dev/null | tr -d ',')
        
        if [[ -z "$duration" ]]; then
            duration="0"
        fi
        if [[ -z "$total_frames" ]]; then
            total_frames="0"
        fi
        
        log $INFO "Video duration: ${duration}s, Total frames: ${total_frames}"
        log $INFO "Progress will be shown below:"
        
        # Run ffmpeg with progress output
        if ffmpeg -i "$file" \
            -c:v hevc_videotoolbox \
            -allow_sw 1 \
            -prio_speed 1 \
            -power_efficient 1 \
            -b:v 10M \
            -tag:v hvc1 \
            -r 30 \
            -c:a copy \
            -movflags +faststart \
            -threads 1 \
            -progress pipe:1 \
            "$output_file" 2>/dev/null | while IFS= read -r line; do
            # Extract progress information
            if [[ $line == time=* ]]; then
                time_value=$(echo "$line" | cut -d'=' -f2)
                # Convert time to seconds for display
                if [[ $time_value =~ ^[0-9]+:[0-9]+:[0-9]+\.[0-9]+$ ]]; then
                    # Convert HH:MM:SS.ms to seconds
                    hours=$(echo "$time_value" | cut -d':' -f1)
                    minutes=$(echo "$time_value" | cut -d':' -f2)
                    seconds=$(echo "$time_value" | cut -d':' -f3 | cut -d'.' -f1)
                    current_seconds=$((hours * 3600 + minutes * 60 + seconds))
                    
                    # Calculate percentage
                    if [[ $duration -gt 0 ]]; then
                        percentage=$(echo "scale=1; $current_seconds * 100 / $duration" | bc -l 2>/dev/null)
                        if [[ -z "$percentage" ]]; then
                            percentage="0"
                        fi
                        echo -ne "\r${CYAN}convertLarge4kMov | GPU Progress: ${time_value} (${percentage}%)${NC}"
                    else
                        echo -ne "\r${CYAN}convertLarge4kMov | GPU Progress: ${time_value}${NC}"
                    fi
                fi
            elif [[ $line == frame=* ]]; then
                frame=$(echo "$line" | cut -d'=' -f2)
                # Calculate percentage based on frame number if we have total frames
                if [[ -n "$frame" && $frame -gt 0 && $total_frames -gt 0 ]]; then
                    frame_percentage=$(echo "scale=1; $frame * 100 / $total_frames" | bc -l 2>/dev/null)
                    if [[ -n "$frame_percentage" && $(echo "$frame_percentage <= 100" | bc -l) -eq 1 ]]; then
                        echo -ne "\r${CYAN}convertLarge4kMov | GPU Progress: ${frame_percentage}%${NC}"
                    else
                        echo -ne "\r${CYAN}convertLarge4kMov | GPU Progress: Frame ${frame}${NC}"
                    fi
                elif [[ -n "$frame" && $frame -gt 0 ]]; then
                    echo -ne "\r${CYAN}convertLarge4kMov | GPU Progress: Frame ${frame}${NC}"
                fi
            fi
        done; then
            
            echo ""  # New line after progress
            log $SUCCESS "GPU conversion successful!"
            return 0
        else
            echo ""  # New line after progress
            log $INFO "GPU conversion failed, falling back to CPU..."
        fi
    fi
    
    # CPU conversion (fallback or primary if GPU not available)
    log $INFO "Using CPU conversion with 4 threads..."
    
    # Get video duration and frame count for progress calculation (if not already done)
    if [[ -z "$duration" || "$duration" == "0" ]]; then
        duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null)
        if [[ -z "$duration" ]]; then
            duration="0"
        fi
    fi
    if [[ -z "$total_frames" || "$total_frames" == "0" ]]; then
        total_frames=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$file" 2>/dev/null | tr -d ',')
        if [[ -z "$total_frames" ]]; then
            total_frames="0"
        fi
    fi
    
    log $INFO "Video duration: ${duration}s, Total frames: ${total_frames}"
    log $INFO "Progress will be shown below:"
    
    # Run ffmpeg with progress output
    if ffmpeg -i "$file" \
        -threads 4 \
        -c:v libx265 \
        -crf 23 \
        -preset medium \
        -r 30 \
        -c:a copy \
        -movflags +faststart \
        -progress pipe:1 \
        "$output_file" 2>/dev/null | while IFS= read -r line; do
        # Extract progress information
        if [[ $line == time=* ]]; then
            time_value=$(echo "$line" | cut -d'=' -f2)
            # Convert time to seconds for display
            if [[ $time_value =~ ^[0-9]+:[0-9]+:[0-9]+\.[0-9]+$ ]]; then
                # Convert HH:MM:SS.ms to seconds
                hours=$(echo "$time_value" | cut -d':' -f1)
                minutes=$(echo "$time_value" | cut -d':' -f2)
                seconds=$(echo "$time_value" | cut -d':' -f3 | cut -d'.' -f1)
                current_seconds=$((hours * 3600 + minutes * 60 + seconds))
                
                # Calculate percentage
                if [[ $duration -gt 0 ]]; then
                    percentage=$(echo "scale=1; $current_seconds * 100 / $duration" | bc -l 2>/dev/null)
                    if [[ -z "$percentage" ]]; then
                        percentage="0"
                    fi
                    echo -ne "\r${CYAN}convertLarge4kMov | CPU Progress: ${time_value} (${percentage}%)${NC}"
                else
                    echo -ne "\r${CYAN}convertLarge4kMov | CPU Progress: ${time_value}${NC}"
                fi
            fi
        elif [[ $line == frame=* ]]; then
            frame=$(echo "$line" | cut -d'=' -f2)
            # Calculate percentage based on frame number if we have total frames
            if [[ -n "$frame" && $frame -gt 0 && $total_frames -gt 0 ]]; then
                frame_percentage=$(echo "scale=1; $frame * 100 / $total_frames" | bc -l 2>/dev/null)
                if [[ -n "$frame_percentage" && $(echo "$frame_percentage <= 100" | bc -l) -eq 1 ]]; then
                    echo -ne "\r${CYAN}convertLarge4kMov | CPU Progress: ${frame_percentage}%${NC}"
                else
                    echo -ne "\r${CYAN}convertLarge4kMov | CPU Progress: Frame ${frame}${NC}"
                fi
            elif [[ -n "$frame" && $frame -gt 0 ]]; then
                echo -ne "\r${CYAN}convertLarge4kMov | CPU Progress: Frame ${frame}${NC}"
            fi
        fi
    done; then
        
        echo ""  # New line after progress
        log $SUCCESS "CPU conversion successful!"
        return 0
    else
        echo ""  # New line after progress
        return 1
    fi
    
    # Show file size comparison
    local original_size=$(get_file_size "$file")
    local new_size=$(get_file_size "$output_file")
    local original_mb=$((original_size / 1024 / 1024))
    local new_mb=$((new_size / 1024 / 1024))
    local savings=$((original_mb - new_mb))
    
    log $INFO "Size: ${original_mb}MB → ${new_mb}MB (saved ${savings}MB)"
    return 0
}

# Validate folder
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

# Check if required tools are available
if ! command -v ffmpeg &> /dev/null; then
    log $ERROR "ffmpeg is not installed or not in PATH. Exiting."
    exit 1
fi

if ! command -v ffprobe &> /dev/null; then
    log $ERROR "ffprobe is not installed or not in PATH. Exiting."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    log $ERROR "bc (calculator) is not installed. Please install it: brew install bc"
    exit 1
fi

# Check if GPU acceleration is available
gpu_available=false
if ffmpeg -encoders 2>/dev/null | grep -q "hevc_videotoolbox"; then
    gpu_available=true
    log $INFO "GPU acceleration (VideoToolbox) is available"
else
    log $INFO "GPU acceleration not available, will use CPU only"
fi

# Enable case-insensitive globbing
shopt -s nullglob nocaseglob

log $INFO "Scanning for MOV files larger than ${min_size_mb}MB..."
log $INFO "Will convert 4K videos with FPS > 45 to HEVC MP4 at 30FPS"

# Find and process MOV files
processed_files=0
skipped_files=0
total_files=0

for file in *.[mM][oO][vV]; do
    [ -f "$file" ] || continue
    total_files=$((total_files + 1))
    
    # Check file size
    file_size=$(get_file_size "$file")
    file_size_mb=$((file_size / 1024 / 1024))
    
    if [ $file_size -lt $min_size_bytes ]; then
        log $INFO "Skipping $file (${file_size_mb}MB < ${min_size_mb}MB)"
        skipped_files=$((skipped_files + 1))
        continue
    fi
    
    log $ANALYSIS "Analyzing: $file (${file_size_mb}MB)"
    
    # Get video properties
    video_info=$(get_video_info "$file")
    resolution=$(echo $video_info | cut -d' ' -f1)
    fps=$(echo $video_info | cut -d' ' -f2)
    
    # Debug: Show raw ffprobe output for troubleshooting
    if [[ "$resolution" == "0x0" || "$fps" == "0" ]]; then
        log $ERROR "Failed to get video properties for $file"
        log $INFO "Raw ffprobe output:"
        ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=s=x:p=0 "$file" 2>&1 | head -3
        skipped_files=$((skipped_files + 1))
        continue
    fi
    
    log $ANALYSIS "Properties: ${resolution} @ ${fps}fps"
    
    # Check if it's 4K and high FPS
    if is_4k_or_higher "$resolution"; then
        # Compare FPS with better error handling
        fps_compare=$(echo "$fps > 45" | bc -l 2>/dev/null)
        if [[ $? -eq 0 && "$fps_compare" == "1" ]]; then
            log $INFO "✓ Meets criteria: 4K+ resolution and ${fps}fps > 45fps"
            if convert_video "$file"; then
                processed_files=$((processed_files + 1))
            fi
        else
            log $INFO "✗ FPS too low: ${fps}fps ≤ 45fps, skipping"
            skipped_files=$((skipped_files + 1))
        fi
    else
        log $INFO "✗ Resolution too low: $resolution is not 4K+, skipping"
        skipped_files=$((skipped_files + 1))
    fi
done

# Disable case-insensitive globbing
shopt -u nocaseglob

# Final summary
log $SUCCESS "Processing complete!"
log $INFO "Total MOV files found: $total_files"
log $INFO "Files converted: $processed_files"
log $INFO "Files skipped: $skipped_files" 