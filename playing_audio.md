Run these in tmux so that when your ssh connection terminates they keep playing

To play on headphone jack speakers:  
`mpv --loop=inf --gapless-audio=yes brown_noise.mp3`

To play on bluetooth:  
`mpv --audio-device=pulse/bluez_sink.F4_4E_FD_2C_0B_AD.a2dp_sink --loop=inf --gapless-audio=yes brown_noise.mp3`
But for bluetooth, it kept giving static pops, coincident with `Audio device underrun detected` shown in the terminal. This was for the rpi3b+. I haven't tried anything else.
