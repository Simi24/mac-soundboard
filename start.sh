#!/bin/zsh
# Start the soundboard: local server + Chrome.
PORT=8765
DIR="$(cd "$(dirname "$0")" && pwd)"

# Local server: page (setSinkId requires localhost) + monitor via afplay
if ! lsof -iTCP:$PORT -sTCP:LISTEN -n -P >/dev/null 2>&1; then
  nohup python3 "$DIR/server.py" >/dev/null 2>&1 &
fi

sleep 0.5
open -a "Google Chrome" "http://localhost:$PORT/soundboard.html"
echo "Soundboard up. Call mic: 'Mic + Soundboard' ('BlackHole 2ch' while Voice FX is on)."
echo "To shut down: $DIR/stop.sh"
