#!/bin/bash
set -euo pipefail

# MAXIMUM SPEED MOV→MP4 converter (aggressive hardware utilization)
# Usage: ./convertLarge4kMov_max_speed.sh /path/to/folder [file_name] [min_size_mb] [thread_queue_size] [bitrate] [threads] [max_muxing_queue_size] [codec] [min_width] [min_height] [min_fps]

# CapCut comparison:
# Same size: 4K Recommended HEVC mp4 60fps - 28M hevc_videotoolbox

# Default directory & size threshold
DEFAULT_DIR="${1:-/Users/artempriadkin/Downloads}"
FILE_NAME="${2:-}"                                # specific file name to process (optional)
MIN_SIZE_MB="${3:-200}"                           # minimum file size
THREAD_QUEUE_SIZE="${4:-32}"                      # thread queue size
BITRATE="${5:-28M}"                               # video bitrate
THREADS="${6:-0}"                                 # threads (0 = auto-detect all cores)
MAX_MUXING_QUEUE_SIZE="${7:-1024}"                # max muxing queue size
CODEC="${8:-hevc_videotoolbox}"                   # codec


FILE_NAME_SUFFIX="_${CODEC}_${BITRATE}_max_speed" # file name suffix using template
MIN_BYTES=$((MIN_SIZE_MB*1024*1024))
MIN_WIDTH="${9:-}"                              # minimum width (empty = use original)
MIN_HEIGHT="${10:-}"                            # minimum height (empty = use original)
MIN_FPS="${11:-}"                               # minimum FPS (empty = use original)


RED="\033[0;31m"; GRN="\033[0;32m"; YLW="\033[0;33m"; CYN="\033[0;36m"; NC="\033[0m"
log(){ echo -e "${2:-$YLW}MAX_SPEED | $1${NC}"; }

cd "$DEFAULT_DIR" || { echo "Folder not found"; exit 1; }

# Start timing
start_time=$(date +%s)

shopt -s nullglob nocaseglob

# First pass: count eligible files and build list
eligible_files=()
total_mov_files=0
skipped_size=0
skipped_resolution=0
skipped_fps=0
skipped_exists=0

if [[ -n "$FILE_NAME" ]]; then
  log "Processing specific file: $FILE_NAME" "$CYN"
  if [[ ! -f "$FILE_NAME" ]]; then
    log "Error: File '$FILE_NAME' not found in directory" "$RED"
    exit 1
  fi
  # Check if it's a MOV file
  if [[ ! "$FILE_NAME" =~ \.[mM][oO][vV]$ ]]; then
    log "Error: '$FILE_NAME' is not a MOV file" "$RED"
    exit 1
  fi
  files_to_check=("$FILE_NAME")
else
  log "Scanning for eligible MOV files..." "$CYN"
  files_to_check=(*.[mM][oO][vV])
fi

for f in "${files_to_check[@]}"; do
  # Skip if no files found (glob expansion)
  [[ "$f" == *.[mM][oO][vV] ]] && [[ ! -f "$f" ]] && continue
  
  total_mov_files=$((total_mov_files + 1))
  
  size=$(stat -f%z "$f"); (( size<MIN_BYTES )) && { skipped_size=$((skipped_size + 1)); continue; }
  
  info=$(ffprobe -v quiet -select_streams v:0 \
          -show_entries stream=width,height,r_frame_rate \
          -of csv=p=0:s=x "$f" 2>/dev/null)

  # Expected format: WIDTHxHEIGHTxFPS (e.g. 3840x2160x60/1)
  IFS='x' read -r width height fps_raw <<< "$info"

  # Validate numeric width/height
  [[ -z "$width" || -z "$height" ]] && { log "Skip (could not parse resolution) $f" "$RED"; continue; }

  # Convert fps_raw (may be 60/1 or 59.94/1) to decimal
  fps=$(awk -v fr="$fps_raw" 'BEGIN{split(fr,a,"/"); if(a[2]==""||a[2]==0){print a[1];} else {printf "%.2f", a[1]/a[2];}}')

  # Use original dimensions if minimum values are not provided
  if [[ -z "$MIN_WIDTH" ]]; then
    min_width_check=0  # Skip width check
  else
    min_width_check=$((width < MIN_WIDTH))
  fi
  
  if [[ -z "$MIN_HEIGHT" ]]; then
    min_height_check=0  # Skip height check
  else
    min_height_check=$((height < MIN_HEIGHT))
  fi
  
  if [[ -z "$MIN_FPS" ]]; then
    min_fps_check=0  # Skip FPS check
  else
    min_fps_check=$(awk -v f="$fps" -v min="$MIN_FPS" 'BEGIN{exit (f>min)?0:1}')
  fi

  (( min_width_check || min_height_check )) && { skipped_resolution=$((skipped_resolution + 1)); continue; }
  # Skip if FPS check fails
  (( min_fps_check )) && { skipped_fps=$((skipped_fps + 1)); continue; }

  out="${f%.*}${FILE_NAME_SUFFIX}.mp4"; [ -f "$out" ] && { skipped_exists=$((skipped_exists + 1)); continue; }

  eligible_files+=("$f")
done

# Display file count and processing variables
log "=== FILE ANALYSIS ===" "$GRN"
log "Total MOV files found: $total_mov_files" "$CYN"
log "Files to convert: ${#eligible_files[@]}" "$GRN"
log "Skipped (size < ${MIN_SIZE_MB}MB): $skipped_size" "$YLW"
if [[ -n "$MIN_WIDTH" || -n "$MIN_HEIGHT" ]]; then
  log "Skipped (resolution < min): $skipped_resolution" "$YLW"
else
  log "Skipped (resolution check): $skipped_resolution" "$YLW"
fi
if [[ -n "$MIN_FPS" ]]; then
  log "Skipped (FPS < min): $skipped_fps" "$YLW"
else
  log "Skipped (FPS check): $skipped_fps" "$YLW"
fi
log "Skipped (output exists): $skipped_exists" "$YLW"

if [ ${#eligible_files[@]} -eq 0 ]; then
  log "No files to convert. Exiting." "$RED"
  exit 0
fi

log "=== PROCESSING VARIABLES ===" "$GRN"
log "Target directory: $DEFAULT_DIR" "$CYN"
log "Minimum file size: ${MIN_SIZE_MB}MB (${MIN_BYTES} bytes)" "$CYN"
log "Threads: $THREADS (0 = auto-detect all cores)" "$CYN"
log "Thread queue size: $THREAD_QUEUE_SIZE" "$CYN"
log "Max muxing queue: $MAX_MUXING_QUEUE_SIZE" "$CYN"
log "Video bitrate: $BITRATE" "$CYN"
log "Hardware acceleration: VideoToolbox" "$CYN"
log "Priority: Normal (no nice restriction)" "$CYN"
if [[ -n "$MIN_WIDTH" ]]; then
  log "Minimum width: $MIN_WIDTH" "$CYN"
else
  log "Minimum width: use original" "$CYN"
fi
if [[ -n "$MIN_HEIGHT" ]]; then
  log "Minimum height: $MIN_HEIGHT" "$CYN"
else
  log "Minimum height: use original" "$CYN"
fi
if [[ -n "$MIN_FPS" ]]; then
  log "Minimum FPS: $MIN_FPS" "$CYN"
else
  log "Minimum FPS: use original" "$CYN"
fi
if [[ -n "$FILE_NAME" ]]; then
  log "Specific file: $FILE_NAME" "$CYN"
fi

log "=== STARTING CONVERSION ===" "$GRN"

processed_files=0
for f in "${eligible_files[@]}"; do
  out="${f%.*}${FILE_NAME_SUFFIX}.mp4"
  
  log "Converting $f → $out (MAXIMUM SPEED mode)" "$GRN"
  # NO nice priority - let ffmpeg use full CPU
  time ffmpeg -v warning \
    -stats \
    -hwaccel videotoolbox \
    -hwaccel_output_format videotoolbox_vld \
    -i "$f" \
    -c:v "$CODEC" \
    -prio_speed 1 \
    -b:v "$BITRATE" \
    -tag:v hvc1 \
    -threads "$THREADS" \
    -thread_type slice \
    -thread_queue_size "$THREAD_QUEUE_SIZE" \
    -max_muxing_queue_size "$MAX_MUXING_QUEUE_SIZE" \
    -c:a copy \
    -movflags +faststart \
    "$out"
  
  processed_files=$((processed_files + 1))
done
shopt -u nullglob nocaseglob

# Calculate and display performance metrics
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

# Convert seconds to HH:MM:SS format
hours=$((elapsed_time / 3600))
minutes=$(((elapsed_time % 3600) / 60))
seconds=$((elapsed_time % 60))
formatted_time=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)

log "Done" "$GRN"
log "Performance Summary:" "$CYN"
log "  Files processed: $processed_files" "$CYN"
log "  Total elapsed time: ${formatted_time}" "$CYN"

if [ $processed_files -gt 0 ]; then
  avg_time_per_file=$(echo "scale=1; $elapsed_time / $processed_files" | bc -l 2>/dev/null || echo "N/A")
  log "  Average time per file: ${avg_time_per_file}s" "$CYN"
fi 