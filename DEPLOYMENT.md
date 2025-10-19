# Raspberry Pi Camera Capture and Upload - Deployment Guide

## Overview
This service continuously captures images from a Raspberry Pi camera and uploads them to Google Cloud Storage. It includes robust error handling, process cleanup, and automatic restart capabilities.

## Prerequisites
- Raspberry Pi with camera module connected
- `libcamera-still` installed (included in recent Raspberry Pi OS)
- Google Cloud SDK (`gsutil`) installed and authenticated
- Systemd (standard on Raspberry Pi OS)

## Installation Steps

### 1. Transfer Files to Raspberry Pi
```bash
# From your Mac:
cd ~/github/rpi/
scp capture_and_upload.sh pi@YOUR_PI_IP:/home/pi/
scp capture-upload.service pi@YOUR_PI_IP:/tmp/
```

Or using git:
```bash
# On Raspberry Pi:
cd /home/pi
git clone YOUR_REPO_URL
# or git pull if already cloned
```

### 2. Set Up the Script
```bash
# On Raspberry Pi:
cd /home/pi
chmod +x capture_and_upload.sh

# Test the script manually first (Ctrl+C to stop):
./capture_and_upload.sh
```

### 3. Install the Systemd Service
```bash
# On Raspberry Pi:
sudo cp /tmp/capture-upload.service /etc/systemd/system/
# Or if using git:
# sudo cp ~/rpi/capture-upload.service /etc/systemd/system/

# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable capture-upload.service

# Start the service
sudo systemctl start capture-upload.service
```

## Managing the Service

### Check Service Status
```bash
sudo systemctl status capture-upload.service
```

### View Live Logs
```bash
# View service logs from systemd journal
sudo journalctl -u capture-upload.service -f

# View application log file
tail -f /var/log/capture_and_upload.log
```

### Start/Stop/Restart
```bash
# Stop the service
sudo systemctl stop capture-upload.service

# Start the service
sudo systemctl start capture-upload.service

# Restart the service
sudo systemctl restart capture-upload.service
```

### Disable Auto-start
```bash
sudo systemctl disable capture-upload.service
```

## Troubleshooting

### Diagnose Previous Crash

If your Pi became unresponsive, check these logs after reboot:

```bash
# Check for Out-of-Memory (OOM) killer events from previous boot
sudo journalctl -b -1 | grep -i "oom"

# Check system logs from previous boot
sudo journalctl -b -1 | tail -200

# Check kernel messages (dmesg doesn't support -b flag on all systems)
sudo journalctl -k -b -1 | tail -100

# Check for memory pressure issues
sudo journalctl -b -1 | grep -i "memory\|killed"
```

### Common Issues

#### Camera Not Working
```bash
# Check if camera is detected
libcamera-hello --list-cameras

# Test camera capture manually
libcamera-still -o test.jpg
```

#### Upload Failures
```bash
# Test gsutil authentication
gsutil ls gs://living_room_dogs/

# Re-authenticate if needed
gcloud auth login
```

#### Service Won't Start
```bash
# Check service logs for errors
sudo journalctl -u capture-upload.service -n 50

# Verify script has execute permissions
ls -l /home/pi/capture_and_upload.sh

# Verify script path in service file
sudo cat /etc/systemd/system/capture-upload.service
```

#### High Resource Usage
```bash
# Monitor system resources
htop

# Check for stuck processes
ps aux | grep -E "gsutil|libcamera"

# Kill stuck processes
pkill -9 gsutil
pkill -9 libcamera-still
```

### Disk Space Issues
```bash
# Check disk usage
df -h

# Check /tmp directory
du -sh /tmp/pose_imgs

# Manually clean up if needed
rm -rf /tmp/pose_imgs/*.jpg
```

## Configuration

Edit `/home/pi/capture_and_upload.sh` to modify:

- `IMG_DIR`: Temporary storage location (default: `/tmp/pose_imgs`)
- `LOG_FILE`: Log file location (default: `/var/log/capture_and_upload.log`)
- `MAX_PROCESSES`: Maximum allowed stuck processes (default: 5)
- `MAX_DISK_USAGE`: Maximum disk usage percentage (default: 80)
- `GCS_BUCKET`: Google Cloud Storage bucket (default: `gs://living_room_dogs/`)
- Image dimensions: `--width 432 --height 368`
- Capture interval: `sleep 1` (1 second between captures)

After editing, restart the service:
```bash
sudo systemctl restart capture-upload.service
```

## Monitoring

### Set Up Alerts (Optional)
Consider setting up monitoring for:
- Service uptime
- Upload success rate
- System memory usage
- Disk space

### Log Rotation
The application log at `/var/log/capture_and_upload.log` will grow over time. Set up log rotation:

```bash
# Create logrotate config
sudo nano /etc/logrotate.d/capture-upload
```

Add:
```
/var/log/capture_and_upload.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## Resource Limits

The systemd service includes these limits to prevent system exhaustion:
- **Memory**: Maximum 200MB
- **CPU**: Maximum 50% of one core

These can be adjusted in `/etc/systemd/system/capture-upload.service` if needed.

## Uninstallation

```bash
# Stop and disable the service
sudo systemctl stop capture-upload.service
sudo systemctl disable capture-upload.service

# Remove service file
sudo rm /etc/systemd/system/capture-upload.service

# Reload systemd
sudo systemctl daemon-reload

# Remove script and logs
rm /home/pi/capture_and_upload.sh
sudo rm /var/log/capture_and_upload.log

# Clean up temporary files
rm -rf /tmp/pose_imgs
```

## Notes

- The service automatically restarts on failure with a 10-second delay
- Processes are cleaned up every 60 seconds to prevent accumulation
- Failed uploads are deleted to prevent disk fill
- After 10 consecutive failures, the service exits and systemd will restart it
- All times are logged in the format: `[YYYY-MM-DD HH:MM:SS] message`
