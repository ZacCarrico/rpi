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

### What works

Run in tmux so it survives SSH disconnects:

```bash
bluetoothctl connect F4:4E:FD:2C:0B:AD
tmux new -s audio   # or: tmux attach -t audio
PIPEWIRE_NODE=bluez_output.F4_4E_FD_2C_0B_AD.1 \
  PULSE_RUNTIME_PATH=/run/user/1000/pulse \
  ffplay -nodisp -loop 0 ~/brown_noise.mp3
```

`PIPEWIRE_NODE` is the critical part — without it, ffplay routes to Dummy Output instead of the speaker.

### What was tried and failed

**`Class = 0x20041C` in `/etc/bluetooth/main.conf`** — broke the connection. Changing the device class caused the speaker to use HFP (hands-free phone profile) instead of A2DP, which failed its modem handshake and immediately dropped.

**WirePlumber override to disable HFP backend** (`~/.config/wireplumber/bluetooth.lua.d/50-bluez-config.lua`) — partially helped (stopped the modem errors) but audio still wasn't routing to the BT sink because the default sink remained `auto_null`.

**`btusb.enable_autosuspend=n` in `/boot/firmware/cmdline.txt`** — reverted, not needed once routing was fixed.

**Systemd user service** — the approach was sound but had two bugs: (1) the `ExecStartPre` BT connect raced with boot and lost; (2) `PIPEWIRE_NODE` wasn't set so ffplay played to Dummy Output silently.

All of the above were reverted. The working solution above has no system config changes.
