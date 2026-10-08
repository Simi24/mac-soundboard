#!/bin/zsh
# Stop the soundboard: local server, any playing monitor sound, Voice FX.
pkill -f "soundboard/server.py" 2>/dev/null
pkill -f "sb_monitor_" 2>/dev/null
pkill -TERM -f "VoiceFX.app/Contents/MacOS/voicefx" 2>/dev/null
echo "Soundboard stopped."
