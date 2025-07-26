#!/bin/bash
set -euo pipefail

# Parallel GPU-speed MOV→MP4 converter
# Usage: ./convertLarge4kMov_gpu_speed_parallel.sh /path/to/folder [min_size_mb] [max_parallel]
# Example: ./convertLarge4kMov_gpu_speed_parallel.sh ~/Downloads/1 200 2
#
# * Spawns up to N concurrent ffmpeg jobs (default 2)
# * Each worker uses the high-GPU settings from convertLarge4kMov_gpu_speed.sh
# * Monitors the number of background jobs and queues new files when slots free up
# * Tracks total elapsed time for performance measurement
#
# NOTE: Running multiple simultaneous VideoToolbox encodes will share the hardware
# encoder – overall throughput may improve slightly, but single-encode speed will drop.
# Test 2 parallel jobs first; raise only if GPU still <90 % and CPU acceptable.

DIR="${1:-/Users/artempriadkin/Downloads/1}"      # target directory
MIN_MB="${2:-200}"                                # minimum file size
PARALLEL="${3:-6}"                                # max concurrent jobs
BITRATE="${4:-12M}"                               # video bitrate (20M is better, but bigger)
THREAD_QUEUE_SIZE="${5:-32}"                      # thread queue size
MIN_BYTES=$((MIN_MB*1024*1024))

RED="\033[0;31m"; GRN="\033[0;32m"; YLW="\033[0;33m"; CYN="\033[0;36m"; NC="\033[0m"
log(){ echo -e "${2:-$YLW}GPU_PAR | $1${NC}"; }

cd "$DIR" || { echo "Directory $DIR not found"; exit 1; }
shopt -s nullglob nocaseglob

# Build list of eligible MOV files
files=()
for f in *.[mM][oO][vV]; do
  size=$(stat -f%z "$f"); (( size<MIN_BYTES )) && continue
  info=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0:s=x "$f" 2>/dev/null)
  IFS='x' read -r width height fps_raw <<< "$info"
  [[ -z "$width" || -z "$height" ]] && continue
  fps=$(awk -v fr="$fps_raw" 'BEGIN{split(fr,a,"/"); if(a[2]==""||a[2]==0){print a[1];} else {printf "%.2f", a[1]/a[2];}}')
  (( width<3840 || height<2160 )) && continue
  awk -v f="$fps" 'BEGIN{exit (f>45)?0:1}' || continue
  out="${f%.*}_gpu_fast.mp4"
  [ -f "$out" ] && continue
  files+=("$f")
done

[ ${#files[@]} -eq 0 ] && { log "No eligible MOV files found" "$CYN"; exit 0; }
log "Processing ${#files[@]} files with up to $PARALLEL parallel jobs" "$GRN"

# Start timing
start_time=$(date +%s)

# Function to encode one file
encode() {
  local src="$1"
  local out="${src%.*}_gpu_fast_parallel.mp4"
  log "[PID $$] Start $src" "$CYN"
  nice -n 15 ffmpeg -v warning \
      -stats \
      -progress pipe:1 \
      -hwaccel videotoolbox \
      -hwaccel_output_format videotoolbox_vld \
      -i "$src" \
      -c:v hevc_videotoolbox \
      -prio_speed 1 \
      -b:v "$BITRATE" \
      -tag:v hvc1 \
      -threads 0 \
      -thread_type slice \
      -thread_queue_size "$THREAD_QUEUE_SIZE" \
      -max_muxing_queue_size 1024 \
      -c:a copy \
      -movflags +faststart \
      "$out" && \
  log "[PID $$] Done $src" "$GRN"
}

# Export function for subshells when using xargs (not needed here – we use background jobs)

active_jobs() { jobs -rp | wc -l | tr -d ' '; }

for file in "${files[@]}"; do
  while [ $(active_jobs) -ge "$PARALLEL" ]; do sleep 1; done
  encode "$file" &
done

wait

# Calculate and display performance metrics
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
total_files=${#files[@]}

log "All conversions finished" "$GRN"
log "Performance Summary:" "$CYN"
log "  Total files processed: $total_files" "$CYN"
log "  Parallel jobs: $PARALLEL" "$CYN"
log "  Total elapsed time: ${elapsed_time}s" "$CYN"

if [ $total_files -gt 0 ]; then
  avg_time_per_file=$(echo "scale=1; $elapsed_time / $total_files" | bc -l 2>/dev/null || echo "N/A")
  log "  Average time per file: ${avg_time_per_file}s" "$CYN"
fi

shopt -u nullglob nocaseglob 