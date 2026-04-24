#!/usr/bin/env bash
# Double-click to see a quick status snapshot. Auto-closes on keypress.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true

clear
./talktype status

echo ""
echo "  press any key to close..."
read -n 1 -s

osascript -e 'tell application "Terminal" to close front window saving no' &>/dev/null || true
