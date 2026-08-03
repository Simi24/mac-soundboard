# Soundboard for Google Meet

Sound effects that the other participants can hear in your Google Meet calls, on macOS. A dependency-free local web app + [BlackHole](https://github.com/ExistentialAudio/BlackHole) as a virtual audio cable.

```
soundboard (http://localhost:8765) ──► BlackHole 2ch ─┐
                                                      ├─► "Mic + Soundboard" ──► Meet's microphone
physical microphone ──────────────────────────────────┘
        └─ local monitor via afplay (outside Chrome)
```

## Install

```sh
./setup/setup.sh
```

The script installs the BlackHole driver (brew), creates the "Mic + Soundboard" aggregate device and links the Claude skill. If the driver is installed but not loaded yet, the script stops and asks you to run `sudo killall coreaudiod`, then run it again.

## Usage

```sh
./start.sh   # starts the local server and opens the soundboard in Chrome
./stop.sh    # shuts everything down at the end of the day
```

In Meet: ⋮ → Settings → Audio → **Microphone → "Mic + Soundboard"**, and turn noise cancellation off (it eats sound effects).

On the board: drag your mp3/wav files onto the page (they persist in the browser), hotkeys `1`–`9` to play, `Esc` to stop everything, "Test output" to verify the BlackHole link.

Sounds are not included in the repo (`sounds/` is gitignored): bring your own, or grab some from [myinstants.com](https://www.myinstants.com) — direct links look like `https://www.myinstants.com/media/sounds/<file>.mp3`.

With Claude Code you can just say **"activate the soundboard"** / **"deactivate the soundboard"**.

## Why it's built this way (non-obvious constraints)

- **The page must be served from localhost**: opened via `file://`, `setSinkId` (audio output selection) fails silently and sounds never reach BlackHole.
- **The local monitor ("listen too") plays outside Chrome** (`server.py` → `afplay`): if it played inside the browser, Chrome's echo cancellation would use it as a reference signal and cancel the sounds in Meet.
- **No mixing process needed**: Chrome captures every channel of the aggregate device (mic on channel 1, BlackHole on channels 2-3), so voice and sounds arrive together without a passthrough.

Operational details and troubleshooting live in the skill: [`skills/soundboard/SKILL.md`](skills/soundboard/SKILL.md).

## Layout

```
soundboard.html            # the web app (vanilla JS, single file, IndexedDB)
server.py                  # serves the page + /monitor (afplay) and /stop endpoints
start.sh / stop.sh         # start and stop
setup/setup.sh             # one-shot install (idempotent)
setup/create_aggregate.swift  # creates the aggregate device via CoreAudio
skills/soundboard/         # Claude skill (symlinked into ~/.claude/skills)
sounds/                    # your mp3s (not versioned)
```
