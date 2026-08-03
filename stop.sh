#!/bin/zsh
# Stop the soundboard: local server and any playing monitor sound.
pkill -f "soundboard/server.py" 2>/dev/null
pkill -f "sb_monitor_" 2>/dev/null
echo "Soundboard stopped."
