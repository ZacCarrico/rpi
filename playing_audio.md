Run these in tmux so that when your ssh connection terminates they keep playing

To play on headphone jack speakers:  
`mpv --loop=inf --gapless-audio=yes brown_noise.mp3`

To play on bluetooth:  
`mpv --audio-device=pulse/bluez_sink.F4_4E_FD_2C_0B_AD.a2dp_sink --loop=inf --gapless-audio=yes brown_noise.mp3`
But for bluetooth, it kept giving static pops, coincident with `Audio device underrun detected` shown in the terminal. This was for the rpi3b+. I haven't tried anything else.

---

## rpi5 + comiso-X26 (2026-05-09) — WORKING

Speaker MAC: `F4:4E:FD:2C:0B:AD`  
Audio system: PipeWire (not PulseAudio)  
Player: `ffplay` (mpv not installed; ffmpeg is)

### Status: unresolved — speaker keeps disconnecting during playback

### What was tried

**`mpv --audio-device=pulse/bluez_output.F4_4E_FD_2C_0B_AD.1 --loop=inf`** — audio played for a moment then speaker disconnected. (This approach is also what the setup guide documents, but it didn't hold.)

**`PIPEWIRE_NODE=bluez_output.F4_4E_FD_2C_0B_AD.1 ffplay -loop 0`** — same result, brief audio then disconnect.

Both approaches correctly route audio to the BT sink (without explicit targeting, audio silently goes to "Dummy Output"). The routing isn't the problem — the speaker drops regardless.

**`Class = 0x20041C` in `/etc/bluetooth/main.conf`** — made things worse. Changed how the Pi identifies itself, causing the speaker to initiate HFP (hands-free phone profile) instead of A2DP, which immediately failed its modem handshake and dropped.

**WirePlumber override (`~/.config/wireplumber/bluetooth.lua.d/50-bluez-config.lua`)** — tried disabling HFP backend and setting `session.suspend-timeout-seconds=0`, but didn't prevent drops.

**`btusb.enable_autosuspend=n` in `/boot/firmware/cmdline.txt`** — reverted, didn't help.

All system config changes were reverted. Pi is back to defaults.

### Why Bluetooth drops (from logs)

WirePlumber (`journalctl --user -u wireplumber`) is restarting repeatedly — it receives SIGTERM, reconnects to BlueZ, and each restart tears down and rebuilds the BT sink. Every time it restarts there's a race condition logged as `Object activation aborted: proxy destroyed`, meaning the A2DP sink object gets destroyed before WirePlumber can finish activating it.

The restarts during this debugging session were caused by manual `systemctl --user restart wireplumber` calls. But the underlying issue — the speaker disconnecting when audio pauses at the loop boundary — is still present. PipeWire may briefly release the A2DP transport between ffplay loop iterations, the speaker detects silence/inactivity, and powers off.

### Next things to try

- Use `ffmpeg` to pipe audio continuously into `pw-cat` (no gap at loop boundary)
- Or use `sox play` with `repeat` which avoids any inter-file gap
- Check if WirePlumber is also restarting spontaneously (not just from manual restarts) by watching logs over a longer window
