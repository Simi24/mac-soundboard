---
name: soundboard
description: Soundboard for Google Meet (repo ~/soundboard) — activation, shutdown, install and troubleshooting. Triggers — "activate/start the soundboard", "deactivate/stop the soundboard", "install the soundboard", "the soundboard doesn't work", "sounds don't come through in meet", plus the Italian equivalents ("attiva/disattiva la soundbar/soundboard", "la soundboard non funziona", "non si sentono i suoni in meet"), or any request about playing sound effects during Google Meet calls.
---

# Soundboard for Google Meet

Local web app + BlackHole to fire sound effects the other participants can hear in Google Meet. Repo: `~/soundboard`.

## Architecture (do not change it without a reason)

```
soundboard (http://localhost:8765) ──► BlackHole 2ch ─┐
                                                      ├─► "Mic + Soundboard" aggregate ──► Meet's mic
physical microphone ──────────────────────────────────┘
        └─ local monitor via afplay (server.py /monitor) — OUTSIDE Chrome
```

Constraints learned the hard way — violating them breaks things silently:

1. **The page MUST run on localhost**: via `file://`, `setSinkId` fails silently and sounds end up on the speakers instead of BlackHole.
2. **The local monitor must NEVER play inside Chrome**: Chrome's echo cancellation uses it as a reference and cancels the sounds in Meet (symptom: sounds only come through with "local monitor" off). That's why the monitor goes through `server.py` → `afplay`.
3. **No sox/mic→BlackHole passthrough**: with the aggregate device it duplicates the voice (metallic sound). The aggregate is enough: Chrome captures all of its channels.
4. **TCC**: freshly compiled binaries do NOT have microphone permission (they record digital silence at -91 dB); use sox/ffmpeg which already have it.

## Activate ("activate the soundboard")

1. Run `~/soundboard/start.sh` (starts `server.py` on :8765 if down and opens Chrome).
2. Verify: `curl -sf http://localhost:8765/soundboard.html` → 200; `system_profiler SPAudioDataType | grep "Mic + Soundboard"` → exists.
3. Remind the user (first launch of the day only): in Meet ⋮ → Settings → Audio → **Microphone = "Mic + Soundboard"** and noise cancellation off; on the page the status LED must read "BlackHole connected".

## Deactivate ("deactivate the soundboard")

Run `~/soundboard/stop.sh` (kills server and monitor). The aggregate device and the driver stay: they are passive, no need to touch them. The user only needs to switch back to the normal microphone in Meet if they ask.

## Install on a new Mac

Run `~/soundboard/setup/setup.sh`: installs the `blackhole-2ch` cask, creates the aggregate via `setup/create_aggregate.swift`, links this skill. If the driver isn't loaded, the script stops and asks the user to run `sudo killall coreaudiod` (needs their password; `launchctl kickstart` is blocked by SIP) and re-run.

## Troubleshooting

- **"No sound in Meet"** — in order of likelihood:
  1. Monitor playing inside Chrome (constraint 2) — check the page is the version using `/monitor`.
  2. Page opened via `file://` (constraint 1) — the URL must be `http://localhost:8765/...`.
  3. Wrong microphone in Meet (must be "Mic + Soundboard").
  4. Wrong output on the board (must be "BlackHole 2ch" or "Mic + Soundboard", equivalent).
- **Measuring where the chain breaks**: record BlackHole with `ffmpeg -f avfoundation -i ":BlackHole 2ch" -t 10 out.wav` while the user presses a pad, then `ffmpeg -i out.wav -af volumedetect -f null -` → -91 dB = nothing is arriving; for the aggregate use `-i ":Mic + Soundboard"` and `astats` for per-channel levels (ch1 = mic, ch2-3 = BlackHole).
- **BlackHole gone after a macOS update**: `ls /Library/Audio/Plug-Ins/HAL/` and if the driver is there, have the user run `sudo killall coreaudiod`.
- **Aggregate device gone**: re-run `swift ~/soundboard/setup/create_aggregate.swift`.
- **Adding sounds**: drag them onto the page (they persist in IndexedDB); backup mp3s in `~/soundboard/sounds/`, downloadable from myinstants.com (direct links: `https://www.myinstants.com/media/sounds/<file>.mp3`).
