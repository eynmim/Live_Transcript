#!/usr/bin/env bash
# Double-click to restart talktype cleanly (use after a crash or a patch update).
# Detached launch — survives closing the Terminal window.

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true

LOG_DIR="$HOME/Library/Logs/talktype"
mkdir -p "$LOG_DIR"
LAUNCHER_LOG="$LOG_DIR/launcher.log"

clear
echo "┌──────────────────────────────────────────┐"
echo "│  talktype — restart                      │"
echo "└──────────────────────────────────────────┘"

echo "  ▶ stop phase"
./talktype stop 2>&1 | tail -1 || true
pkill -9 -f "Electron.*talktype|Electron.*OpenWhispr|run-electron|vite.*OpenWhispr|concurrently.*electron" 2>/dev/null || true
lsof -ti:5180,5181,5182,5183,5184,8180 2>/dev/null | xargs kill -9 2>/dev/null || true
rm -f "$DIR/.talktype.pid"
sleep 1

echo "  ▶ start phase (detached, logs: $LAUNCHER_LOG)"
nohup ./talktype start </dev/null >>"$LAUNCHER_LOG" 2>&1 &
disown
sleep 3
echo "  ✓ restarted"

echo ""
echo "  closing this Terminal in 2s..."
sleep 2

osascript -e 'tell application "Terminal" to close front window saving no' &>/dev/null || true
