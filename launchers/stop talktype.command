#!/usr/bin/env bash
# Double-click to stop talktype.
# Kills Electron + Vite + stale ports, leaves native Ollama alone.
# Auto-closes the Terminal window when done.

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true

clear
echo "┌──────────────────────────────────────────┐"
echo "│  talktype — stop                         │"
echo "└──────────────────────────────────────────┘"

echo "  ▶ asking talktype to stop..."
./talktype stop 2>&1 | tail -2 || true

echo "  ▶ killing leftovers (Electron/Vite/ports)..."
pkill -9 -f "Electron.*talktype|Electron.*OpenWhispr|run-electron|vite.*OpenWhispr|concurrently.*electron" 2>/dev/null || true
lsof -ti:5180,5181,5182,5183,5184,8180 2>/dev/null | xargs kill -9 2>/dev/null || true
rm -f "$DIR/.talktype.pid"

echo ""
echo "  ✓ talktype stopped"
echo "    (native Ollama still running — managed by brew services)"
echo "    to stop it too: brew services stop ollama"
echo ""
echo "  closing this Terminal in 2s..."
sleep 2

osascript -e 'tell application "Terminal" to close front window saving no' &>/dev/null || true
