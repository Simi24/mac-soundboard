#!/bin/zsh
# Avvia la soundboard: server locale + passthrough microfono→BlackHole + Chrome.
PORT=8765
DIR="$(cd "$(dirname "$0")" && pwd)"

# Server locale: pagina (setSinkId richiede localhost) + monitor via afplay
if ! lsof -iTCP:$PORT -sTCP:LISTEN -n -P >/dev/null 2>&1; then
  nohup python3 "$DIR/server.py" >/dev/null 2>&1 &
fi

sleep 0.5
open -a "Google Chrome" "http://localhost:$PORT/soundboard.html"
echo "Soundboard attiva. In Meet: Impostazioni → Audio → Microfono → 'Mic + Soundboard'."
echo "Per spegnere il server: $DIR/stop.sh"
