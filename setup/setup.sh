#!/bin/zsh
# Setup one-shot della soundboard su un Mac nuovo. Idempotente: rilanciabile.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "== 1/3 Driver BlackHole =="
if ! system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole 2ch"; then
  if [ ! -d "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver" ]; then
    brew install blackhole-2ch
  fi
  echo ""
  echo ">>> Il driver è installato ma non caricato. Esegui TU questo comando"
  echo ">>> (riavvia il servizio audio, l'audio cade per 2 secondi):"
  echo ""
  echo "    sudo killall coreaudiod"
  echo ""
  echo ">>> Poi rilancia questo script."
  exit 1
fi
echo "BlackHole attivo ✓"

echo "== 2/3 Dispositivo aggregato 'Mic + Soundboard' =="
swift "$DIR/setup/create_aggregate.swift"

echo "== 3/3 Skill Claude =="
SKILL_LINK="$HOME/.claude/skills/soundboard"
if [ ! -e "$SKILL_LINK" ]; then
  mkdir -p "$HOME/.claude/skills"
  ln -s "$DIR/skills/soundboard" "$SKILL_LINK"
  echo "Skill collegata in $SKILL_LINK ✓"
else
  echo "Skill già presente ✓"
fi

echo ""
echo "Setup completo. Avvia con: $DIR/start.sh"
echo "In Meet: Impostazioni → Audio → Microfono → 'Mic + Soundboard'."
