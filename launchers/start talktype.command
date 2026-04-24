#!/usr/bin/env bash
# Double-click to start talktype.
# Detached launch — survives closing the Terminal window.
# Idempotent — if already running, just brings the app to front.

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

# Load user's shell env (PATH for node/ollama)
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true

LOG_DIR="$HOME/Library/Logs/talktype"
mkdir -p "$LOG_DIR"
LAUNCHER_LOG="$LOG_DIR/launcher.log"

clear
echo "┌──────────────────────────────────────────┐"
echo "│  talktype — start                        │"
echo "└──────────────────────────────────────────┘"

# Already running?
if pgrep -f "Electron.*OpenWhispr|Electron.*talktype" >/dev/null 2>&1; then
  echo "  ℹ already running — bringing to front"
  # Best-effort: focus the Electron window via AppleScript
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "Electron") to true' &>/dev/null || true
else
  echo "  ▶ launching detached (logs: $LAUNCHER_LOG)"
  # Detached so terminal close → SIGHUP doesn't kill the app.
  # setsid isn't on macOS by default, so we use nohup + disown + new stdin.
  nohup ./talktype start </dev/null >>"$LAUNCHER_LOG" 2>&1 &
  disown
  sleep 2
  echo "  ✓ started"
fi

echo ""
echo "  closing this Terminal in 2s..."
sleep 2

# Auto-close this Terminal window (AppleScript). Ignored if it fails.
# Close the Terminal window we're running in (always frontmost).
# Fallback: nothing — user can close manually.
osascript -e 'tell application "Terminal" to close front window saving no' &>/dev/null || true
