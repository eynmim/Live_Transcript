#!/usr/bin/env bash
# talktype logs — pretty-print the last N log events.
# Usage: ./scripts/logs.sh [N]

set -u
N="${1:-50}"
LOG_DIR="$HOME/Library/Logs/talktype"

G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; B='\033[1;34m'; D='\033[2m'; X='\033[0m'

today="$(date +%F)"
file="$LOG_DIR/talktype-$today.log.jsonl"

if [[ ! -f "$file" ]]; then
  file=$(ls -t "$LOG_DIR"/talktype-*.log.jsonl 2>/dev/null | head -1 || true)
fi

if [[ -z "$file" || ! -f "$file" ]]; then
  printf "${D}no log files in %s${X}\n" "$LOG_DIR"
  exit 0
fi

printf "${B}logs: %s  (last %s)${X}\n" "$file" "$N"
printf "${D}%s${X}\n" "────────────────────────────────────────────────"

tail -n "$N" "$file" | python3 -c '
import sys, json
from datetime import datetime

COLORS = {
    "debug": "\033[2m",
    "info":  "\033[1;32m",
    "warn":  "\033[1;33m",
    "error": "\033[1;31m",
}
RESET = "\033[0m"
DIM = "\033[2m"

for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        e = json.loads(raw)
    except Exception:
        print(raw); continue
    ts = e.pop("ts", "")
    lvl = e.pop("level", "info")
    msg = e.pop("msg", "")
    try:
        t = datetime.fromisoformat(ts.replace("Z", "+00:00")).strftime("%H:%M:%S")
    except Exception:
        t = ts[11:19] if len(ts) >= 19 else ts
    color = COLORS.get(lvl, "")
    meta = " ".join(f"{k}={v!r}" for k, v in e.items())
    print(f"{DIM}{t}{RESET} {color}{lvl:>5}{RESET} {msg} {DIM}{meta}{RESET}".rstrip())
'
