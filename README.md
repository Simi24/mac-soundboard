# Soundboard for video calls (macOS)

Sound effects — and live voice effects — that the other participants can hear in your calls — Google Meet, Zoom, Discord, Teams, or **any app that asks for a microphone**. A dependency-free local web app + [BlackHole](https://github.com/ExistentialAudio/BlackHole) as a virtual audio cable.

The trick: "Mic + Soundboard" is a real macOS input device that mixes your physical microphone with whatever the soundboard plays. Any app that can pick a microphone can pick it.

```
soundboard (http://localhost:8765) ──► BlackHole 2ch ─┐
                                                      ├─► "Mic + Soundboard" ──► your app's microphone
physical microphone ──────────────────────────────────┘
        └─ local monitor via afplay (outside the browser)
```

## Install

```sh
./setup/setup.sh
```

The script installs the BlackHole driver (brew), creates the "Mic + Soundboard" aggregate device, builds VoiceFX (needs the Xcode Command Line Tools) and links the Claude skill. If the driver is installed but not loaded yet, the script stops and asks you to run `sudo killall coreaudiod`, then run it again.

## Usage

```sh
./start.sh   # starts the local server and opens the soundboard in Chrome
./stop.sh    # shuts everything down at the end of the day
```

Then select **"Mic + Soundboard"** as the microphone in your call app. For apps without a mic picker, set it as the system default input (System Settings → Sound → Input).

Most call apps ship a noise/voice filter that will happily eat your sound effects — turn it off:

| App | Setting to disable |
|---|---|
| Google Meet | Settings → Audio → Noise cancellation |
| Zoom | Audio → enable "Original sound for musicians" |
| Discord | Voice & Video → Noise suppression (Krisp) → None |
| Teams | Devices → Noise suppression → Off |

On the board: drag your mp3/wav files onto the page (they persist in the browser), hotkeys `1`–`9` to play, `Esc` to stop everything, "Test output" to verify the BlackHole link.

Sounds are not included in the repo (`sounds/` is gitignored): bring your own, or grab some from [myinstants.com](https://www.myinstants.com) — direct links look like `https://www.myinstants.com/media/sounds/<file>.mp3`.

With Claude Code you can just say **"activate the soundboard"** / **"deactivate the soundboard"**.

## Voice FX

Live effects on your voice: robot, radio, echo, cathedral, chipmunk, female, demon, alien. An adaptive noise gate runs before every voice (clean included), so mic hiss doesn't get turned into sizzle by the effects. Turn on **Voice FX** on the board, then pick a voice with a click or <kbd>⇧</kbd>+<kbd>1</kbd>–<kbd>9</kbd>.

```
physical mic ──► VoiceFX.app (native, effects) ──┐
                                                 ├─► BlackHole 2ch ──► your app's microphone
soundboard (browser) ────────────────────────────┘
```

**While Voice FX is on, the call app's microphone must be "BlackHole 2ch"**, not "Mic + Soundboard": the aggregate also carries the raw mic, so the call would get your voice twice. Turn Voice FX off → switch back to "Mic + Soundboard".

The first time it starts, macOS asks for microphone permission for "VoiceFX": allow it. After a rebuild it may ask again.

VoiceFX is a small Swift program (`voicefx/`), no dependencies: all the DSP is written from scratch — FFT, biquad filters (RBJ cookbook), delay lines, ring modulator, Freeverb, a granular pitch shifter, a phase vocoder, cepstral formant shifting (pitch and formants move independently: that's what makes "female" a voice rather than a chipmunk) and a noise gate. Latency is one 256-frame buffer each way (~5 ms at 48 kHz), plus 16 ms for the pitch presets.

```sh
voicefx/build.sh                       # build VoiceFX.app
voicefx/test.sh                        # DSP test suite
voicefx/.build/release/voicefx render robot in.wav out.wav   # try a preset offline
```

## Why it's built this way (non-obvious constraints)

- **The page must be served from localhost**: opened via `file://`, `setSinkId` (audio output selection) fails silently and sounds never reach BlackHole.
- **The local monitor ("listen too") plays outside the browser** (`server.py` → `afplay`): if it played inside Chrome, Chrome's echo cancellation would use it as a reference signal and cancel the sounds in any call running in Chrome (like Meet). Other apps have their own AEC, but playing the monitor out-of-browser is safe everywhere.
- **No mixing process needed**: apps capture every channel of the aggregate device (mic on channel 1, BlackHole on channels 2-3), so voice and sounds arrive together without a passthrough.
- **VoiceFX is native, not Web Audio**: lower latency and it does not depend on a browser tab staying alive. It runs one IOProc on a *private* aggregate (mic + BlackHole) created at launch, so input and output share one clock and one callback, with no drift between devices.
- **VoiceFX must be an `.app` bundle**: macOS grants microphone access (TCC) per app; a bare binary started in the background gets digital silence instead of a permission prompt.

Operational details and troubleshooting live in the skill: [`skills/soundboard/SKILL.md`](skills/soundboard/SKILL.md).

## Layout

```
soundboard.html            # the web app (vanilla JS, single file, IndexedDB)
server.py                  # serves the page + /monitor (afplay), /stop and /voice* endpoints
voice.py                   # starts/stops VoiceFX.app, talks to it over UDP (127.0.0.1:8766)
start.sh / stop.sh         # start and stop
setup/setup.sh             # one-shot install (idempotent)
setup/create_aggregate.swift  # creates the aggregate device via CoreAudio
voicefx/                   # native voice effects (Swift package)
  Sources/DSP/             #   pure DSP, no CoreAudio: Core/ (FFT, Biquad, DelayLine…), Effects/, Voice/ (presets, engine)
  Sources/voicefx/         #   macOS host: CoreAudio I/O, UDP control, WAV render
  Tests/DSPTests/          #   swift-testing suite
skills/soundboard/         # Claude skill (symlinked into ~/.claude/skills)
sounds/                    # your mp3s (not versioned)
```
