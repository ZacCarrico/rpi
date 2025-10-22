#!/bin/bash

# Configuration
IMG_DIR="/tmp/pose_imgs"
LOG_FILE="/var/log/capture_and_upload.log"
MAX_PROCESSES=5
MAX_DISK_USAGE=80  # percentage
GCS_BUCKET="gs://living_room_dogs/"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Cleanup function for stuck processes
cleanup_stuck_processes() {
    # Count running gsutil processes
    GSUTIL_COUNT=$(pgrep -f "gsutil" | wc -l)
    if [ "$GSUTIL_COUNT" -gt "$MAX_PROCESSES" ]; then
        log "WARNING: Too many gsutil processes ($GSUTIL_COUNT), killing all"
        pkill -9 gsutil 2>/dev/null || true
        sleep 2
    fi

    # Count running libcamera processes
    CAMERA_COUNT=$(pgrep -f "libcamera-still" | wc -l)
    if [ "$CAMERA_COUNT" -gt "$MAX_PROCESSES" ]; then
        log "WARNING: Too many libcamera processes ($CAMERA_COUNT), killing all"
        pkill -9 libcamera-still 2>/dev/null || true
        sleep 2
    fi
}

# Check disk space
check_disk_space() {
    USAGE=$(df /tmp | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$USAGE" -gt "$MAX_DISK_USAGE" ]; then
        log "ERROR: Disk usage at ${USAGE}%, cleaning up old images"
        find "$IMG_DIR" -name "*.jpg" -mmin +5 -delete 2>/dev/null || true
        return 1
    fi
    return 0
}

# Main execution
mkdir -p "$IMG_DIR"
log "Starting capture and upload service"

# Clean up any stuck processes from previous runs
log "Cleaning up any stuck processes from previous runs"
pkill -9 libcamera-still 2>/dev/null || true
pkill -9 gsutil 2>/dev/null || true
sleep 2

# Trap to cleanup on exit
trap 'log "Service stopped"; exit 0' SIGTERM SIGINT

FAILURE_COUNT=0
MAX_CONSECUTIVE_FAILURES=10
ITERATION=0

while true; do
    ITERATION=$((ITERATION + 1))

    # Periodic cleanup every 30 iterations (roughly every minute with 2s sleep)
    if [ $((ITERATION % 30)) -eq 0 ]; then
        cleanup_stuck_processes
        check_disk_space || continue
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    IMG_FILE="${IMG_DIR}/img_${TIMESTAMP}.jpg"

    # Capture with timeout (10 second max wait, increased timeout for camera initialization)
    if timeout 10s libcamera-still --width 432 --height 368 --output "$IMG_FILE" --nopreview --timeout 100 2>/dev/null; then
        # Verify file was created
        if [ ! -f "$IMG_FILE" ]; then
            log "ERROR: Image file not created"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        else
            # Upload with timeout (10 second max wait)
            if timeout 10s gsutil -q cp "$IMG_FILE" "$GCS_BUCKET" 2>/dev/null; then
                rm "$IMG_FILE"
                FAILURE_COUNT=0
            else
                log "ERROR: Upload failed for $IMG_FILE"
                FAILURE_COUNT=$((FAILURE_COUNT + 1))
                # Delete failed upload to prevent disk fill
                rm "$IMG_FILE" 2>/dev/null || true
            fi
        fi
    else
        log "ERROR: Camera capture failed or timed out"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        # Clean up any partial file
        rm "$IMG_FILE" 2>/dev/null || true
        # Give camera extra time to recover after failure
        sleep 3
    fi

    # Exit if too many consecutive failures
    if [ "$FAILURE_COUNT" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
        log "CRITICAL: $MAX_CONSECUTIVE_FAILURES consecutive failures, exiting for restart"
        exit 1
    fi

    # Wait between captures to avoid overwhelming the camera
    sleep 2
done
