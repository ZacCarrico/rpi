Run these in tmux so that when your ssh connection terminates they keep playing

To play on headphone jack speakers:  
`mpv --loop=inf --gapless-audio=yes brown_noise.mp3`

To play on bluetooth:  
`mpv --audio-device=pulse/bluez_sink.F4_4E_FD_2C_0B_AD.a2dp_sink --loop=inf --gapless-audio=yes brown_noise.mp3`
But for bluetooth, it kept giving static pops, coincident with `Audio device underrun detected` shown in the terminal. This was for the rpi3b+. I haven't tried anything else.

---

## rpi5 + comiso-X26 (2026-05-09) — UNSOLVED

Speaker MAC: `F4:4E:FD:2C:0B:AD`  
Audio system: PipeWire (not PulseAudio)  
Player: `ffplay` (mpv not installed; ffmpeg is)

**Nothing worked. The speaker disconnects within seconds of connecting every time. Pi is back to stock config.**

### What was tried (all failed)

**`mpv --audio-device=pulse/bluez_output.F4_4E_FD_2C_0B_AD.1 --loop=inf`** — audio played for a moment then speaker disconnected.

**`PIPEWIRE_NODE=bluez_output.F4_4E_FD_2C_0B_AD.1 ffplay -loop 0`** — same result.

Note: without explicit sink targeting, audio silently routes to "Dummy Output" and you hear nothing. Both approaches above do reach the speaker, but the connection drops seconds later regardless.

**`Class = 0x20041C` in `/etc/bluetooth/main.conf`** — made things worse. Caused the speaker to initiate HFP (hands-free phone profile) instead of A2DP, which failed immediately. Reverted.

**WirePlumber override to disable HFP backend and prevent idle suspend** (`~/.config/wireplumber/bluetooth.lua.d/50-bluez-config.lua`) — no improvement. Reverted.

**`btusb.enable_autosuspend=n` in `/boot/firmware/cmdline.txt`** — no improvement. Reverted.

**`loginctl enable-linger zac`** — keeps PipeWire/WirePlumber alive after SSH disconnect (without this, WirePlumber dies when SSH drops, killing the BT sink). Correct fix for that specific problem, but the speaker was still disconnecting even with linger enabled. Reverted.

### What the logs show

Every connection attempt follows the same pattern:
1. `bluetoothctl connect` succeeds, A2DP transport opens (`fd ready`)
2. BlueZ tries to also open a reverse A2DP source channel (speaker→Pi) and fails: `a2dp-source profile connect failed: Device or resource busy`
3. Speaker disconnects within seconds

It's not clear whether the `a2dp-source` failure is causing the disconnect or is just a coincident benign error. The speaker also tries HFP (hands-free) which fails with modem AT commands — again unclear if that triggers the drop.

WirePlumber logs: `journalctl --user -u wireplumber`  
Bluetooth logs: `journalctl -u bluetooth`

### Next things to try

- `loginctl enable-linger zac` is still worth keeping — it's the right fix for WirePlumber dying on SSH disconnect, even though the speaker drop is a separate problem
- Pipe audio with no gap: `ffmpeg -stream_loop -1 -i brown_noise.mp3 -f wav - | pw-cat --playback -`
- Try a different speaker to determine if this is comiso-X26-specific behavior
