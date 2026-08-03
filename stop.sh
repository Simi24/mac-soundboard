#!/bin/zsh
# Ferma la soundboard: server locale e monitor in riproduzione.
pkill -f "soundboard/server.py" 2>/dev/null
pkill -f "sb_monitor_" 2>/dev/null
echo "Soundboard fermata."
