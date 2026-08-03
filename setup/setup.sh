#!/bin/zsh
# One-shot soundboard setup on a new Mac. Idempotent: safe to re-run.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "== 1/3 BlackHole driver =="
if ! system_profiler SPAudioDataType 2>/dev/null | grep -q "BlackHole 2ch"; then
  if [ ! -d "/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver" ]; then
    brew install blackhole-2ch
  fi
  echo ""
  echo ">>> The driver is installed but not loaded. Run this command YOURSELF"
  echo ">>> (it restarts the audio service, audio drops for ~2 seconds):"
  echo ""
  echo "    sudo killall coreaudiod"
  echo ""
  echo ">>> Then run this script again."
  exit 1
fi
echo "BlackHole active ✓"

echo "== 2/3 'Mic + Soundboard' aggregate device =="
swift "$DIR/setup/create_aggregate.swift"

echo "== 3/3 Claude skill =="
SKILL_LINK="$HOME/.claude/skills/soundboard"
if [ ! -e "$SKILL_LINK" ]; then
  mkdir -p "$HOME/.claude/skills"
  ln -s "$DIR/skills/soundboard" "$SKILL_LINK"
  echo "Skill linked at $SKILL_LINK ✓"
else
  echo "Skill already present ✓"
fi

echo ""
echo "Setup complete. Start with: $DIR/start.sh"
echo "Select 'Mic + Soundboard' as microphone in your call app."
