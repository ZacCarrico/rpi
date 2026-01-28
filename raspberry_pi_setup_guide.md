# Raspberry Pi 3B+ Setup Guide - Terminal Only OS with SSH

This guide documents the complete process for installing Raspberry Pi OS Lite (terminal-only) on a Raspberry Pi 3B+ and configuring SSH access.

## Requirements

- Raspberry Pi 3B+
- MicroSD card (minimum 8GB, we used 119GB)
- SD card reader
- 5V 2.5A+ power supply (3A recommended for stable operation)
- Ethernet cable (for initial setup)
- Computer running Linux

## Quick Connection Reference

**SSH:**
```bash
ssh pi@raspberrypi.local
```

**SCP (file transfer):**
```bash
scp /path/to/file pi@raspberrypi.local:~/
```

Using `raspberrypi.local` (mDNS) is more reliable than IP addresses which may change.

## Step 1: Download Raspberry Pi OS Lite

Download the latest Raspberry Pi OS Lite (64-bit) image:

```bash
cd /tmp
wget -O raspios-lite.img.xz "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-11-19/2024-11-19-raspios-bookworm-arm64-lite.img.xz"
```

## Step 2: Identify SD Card Device

Insert your SD card and identify its device name:

```bash
lsblk -p
```

Look for your SD card (in our case it was `/dev/sdb` with 119.1G size).

**WARNING:** Make absolutely sure you identify the correct device. Writing to the wrong device will destroy data!

## Step 3: Write Image to SD Card

Write the image to your SD card:

```bash
cd /tmp
xzcat raspios-lite.img.xz | sudo dd of=/dev/sdb bs=4M status=progress conv=fsync
```

Replace `/dev/sdb` with your actual SD card device. This process takes several minutes.

## Step 4: Configure the SD Card

After writing completes, refresh the partition table:

```bash
sudo partprobe /dev/sdb
sleep 2
lsblk -p /dev/sdb
```

You should see two partitions:
- `/dev/sdb1` - Boot partition (512M, FAT32)
- `/dev/sdb2` - Root partition (2.1G, ext4)

## Step 5: Mount Boot Partition

Create mount point and mount the boot partition:

```bash
sudo mkdir -p /media/zac/bootfs
sudo mount /dev/sdb1 /media/zac/bootfs
```

## Step 6: Enable SSH

Create an empty `ssh` file to enable SSH on first boot:

```bash
sudo touch /media/zac/bootfs/ssh
```

## Step 7: Configure User Credentials

Create user credentials (required for newer Raspberry Pi OS versions):

```bash
echo 'pi:'$(echo 'raspberry' | openssl passwd -6 -stdin) | sudo tee /media/zac/bootfs/userconf.txt
```

Replace `raspberry` with your desired password. The format is `username:hashed_password`.

**Note:** You can change the password after logging in using the `passwd` command.

## Step 8: Configure Wi-Fi (Optional)

Create Wi-Fi configuration file:

```bash
sudo tee /media/zac/bootfs/wpa_supplicant.conf << 'EOF'
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="your_wifi_name"
    psk="your_wifi_password"
}
EOF
```

Replace:
- `US` with your country code
- `your_wifi_name` with your Wi-Fi network name (SSID)
- `your_wifi_password` with your Wi-Fi password

**Important:** The Raspberry Pi 3B+ only supports 2.4GHz Wi-Fi networks, not 5GHz.

## Step 9: Unmount SD Card

Sync and safely unmount the SD card:

```bash
sync
sudo umount /media/zac/bootfs
```

## Step 10: Boot the Raspberry Pi

1. Remove the SD card from your computer
2. Insert it into your Raspberry Pi 3B+
3. Connect Ethernet cable (recommended for first boot)
4. Connect power supply (ensure it's 5V 2.5A+)
5. Wait 1-2 minutes for first boot

**LED Indicators:**
- **Red LED** should be solid (indicates stable power)
- **Green LED** will blink during boot (SD card activity)

If red LED is flickering or turning off, you have insufficient power. Use a better power supply.

## Step 11: Find the Raspberry Pi on Network

Scan your network to find the Pi's IP address:

```bash
sudo nmap -sn 192.168.1.0/24
```

Replace `192.168.1.0/24` with your network's IP range.

Look for a device with MAC address showing "Raspberry Pi Foundation".

In our case: `192.168.1.232` with MAC `B8:27:EB:40:42:AC`

## Step 12: Connect via SSH

Connect to your Raspberry Pi:

```bash
ssh pi@192.168.1.232
```

Replace `192.168.1.232` with your Pi's actual IP address.

Use the password you set in Step 7 (default: `raspberry`).

If you get a "host key changed" warning, remove the old key:

```bash
ssh-keygen -f "/home/zac/.ssh/known_hosts" -R "192.168.1.232"
```

## Step 13: Change Default Password

Once logged in, immediately change your password:

```bash
passwd
```

## Step 14: Configure Wi-Fi Country and Enable Wi-Fi (Critical!)

**IMPORTANT:** Even though you created `wpa_supplicant.conf`, Wi-Fi will be blocked by rfkill until you set the country code through raspi-config.

After first boot via Ethernet, SSH in and run:

```bash
sudo raspi-config
```

Navigate to: `Localisation Options` → `WLAN Country` → Select your country (e.g., `US`)

This unblocks rfkill and allows Wi-Fi to work.

## Step 15: Manually Configure Wi-Fi Network (If Needed)

If Wi-Fi still doesn't connect automatically after setting the country, manually add the network:

```bash
sudo wpa_cli -i wlan0 add_network
```

This returns a network ID (usually `0`). Then configure it:

```bash
sudo wpa_cli -i wlan0 set_network 0 ssid '"your_wifi_name"'
sudo wpa_cli -i wlan0 set_network 0 psk '"your_wifi_password"'
sudo wpa_cli -i wlan0 enable_network 0
```

Verify connection:

```bash
sudo wpa_cli status
```

Should show `wpa_state=COMPLETED`

Get Wi-Fi IP address:

```bash
sudo systemctl restart dhcpcd
ip addr show wlan0 | grep "inet "
```

Now you can disconnect Ethernet and SSH via Wi-Fi!

## Configured Devices

**Raspberry Pi 3B+ (this setup):**
- Username: `pi`
- Ethernet IP: `192.168.1.232`
- Wi-Fi IP: `192.168.1.81`
- Wi-Fi Network: `greyfeathers`
- MAC (Ethernet): `B8:27:EB:40:42:AC`
- MAC (Wi-Fi): `B8:27:EB:15:17:F9`

**Raspberry Pi 5:**
- Username: `zac`
- IP: `192.168.1.249`
- Hostname: `rpi5.attlocal.net`

## Fixing Wi-Fi with NetworkManager (nmcli)

Newer Raspberry Pi OS versions use NetworkManager instead of wpa_supplicant. If Wi-Fi isn't connecting, SSH in via Ethernet and use nmcli:

**Check Wi-Fi status:**
```bash
nmcli device status
```

If wlan0 shows "disconnected", the Pi isn't connected to any network.

**List available networks:**
```bash
nmcli device wifi list
```

**Connect to a network:**
```bash
sudo nmcli device wifi connect 'YOUR_SSID' password 'YOUR_PASSWORD'
```

**Verify connection and get IP:**
```bash
ip addr show wlan0 | grep "inet "
```

The connection is saved automatically and will reconnect on future boots.

## Troubleshooting

### Pi Not Appearing on Network

**Check Power:**
- Red LED should be solid
- If red LED flickers or turns off, use a better power supply (3A recommended)

**Check Wi-Fi Configuration:**
- Pi 3B+ only supports 2.4GHz networks
- Verify SSID and password are correct
- Some networks with WPA3 may not work (use WPA2)

**Use Ethernet Instead:**
- Connect Pi directly to router with Ethernet cable
- This bypasses Wi-Fi issues

### DNS Resolution Failing (apt update fails)

If `apt update` shows "Temporary failure resolving" errors:

```bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

This sets Google's DNS temporarily. For a permanent fix, check your DHCP/router settings.

### Cannot SSH - Password Rejected

**If userconf.txt isn't working:**
1. The Pi may have already booted once with old credentials
2. Re-image the SD card completely (Step 3)
3. Configure SSH, userconf.txt, and Wi-Fi immediately (Steps 6-8)
4. Boot Pi for the first time

**Password must be hashed:**
- Don't manually type passwords in userconf.txt
- Always use `openssl passwd -6` to generate the hash

### SD Card Not Detected

**If lsblk shows 0B:**
1. Remove and firmly reinsert the SD card
2. Try a different USB port
3. Try a different card reader
4. The SD card may be damaged

## Success Confirmation

You've successfully set up your Raspberry Pi when:
- ✅ Red LED is solid
- ✅ Pi appears on network scan
- ✅ SSH connection works
- ✅ You can log in with your credentials

## Default Configuration

**After successful setup:**
- OS: Raspberry Pi OS Lite (64-bit, Bookworm)
- Username: `pi` (or whatever you configured)
- Hostname: `raspberrypi`
- SSH: Enabled
- Desktop Environment: None (terminal only)

## Next Steps

After logging in, you may want to:

1. **Update the system:**
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

2. **Configure hostname:**
   ```bash
   sudo raspi-config
   ```

3. **Set up static IP address**

4. **Install required software packages**

## Notes

- The boot partition files (`ssh`, `userconf.txt`, `wpa_supplicant.conf`) are automatically moved/deleted after first boot
- Always use a quality power supply - insufficient power causes random issues
- For headless setup (no monitor), Ethernet is more reliable than Wi-Fi for initial setup
