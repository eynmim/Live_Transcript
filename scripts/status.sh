#!/usr/bin/env bash
# talktype status — compact live dashboard of every component.
# Zero side effects. Safe to run as often as you want.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$HOME/Library/Logs/talktype"

G='\033[1;32m'; R='\033[1;31m'; Y='\033[1;33m'; B='\033[1;34m'; D='\033[2m'; X='\033[0m'

badge_ok()   { printf "${G}● up${X}"; }
badge_down() { printf "${R}● down${X}"; }
badge_warn() { printf "${Y}● warn${X}"; }
badge_na()   { printf "${D}● n/a${X}"; }

line() { printf "${D}%s${X}\n" "────────────────────────────────────────────────"; }

# ---------- header ----------
printf "\n${B}talktype — status${X}   ${D}$(date '+%Y-%m-%d %H:%M:%S')${X}\n"
line

# ---------- ollama ----------
ollama_status=$(curl -fsS -m 2 http://localhost:11434/api/tags 2>/dev/null || echo "")
if [[ -n "$ollama_status" ]]; then
  model_count=$(printf "%s" "$ollama_status" | grep -o '"name":' | wc -l | tr -d ' ')
  model_names=$(printf "%s" "$ollama_status" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | paste -sd ',' -)
  # Distinguish native (brew) vs Docker
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^talktype-ollama$'; then
    backend="docker"
  elif command -v ollama >/dev/null 2>&1; then
    backend="native"
  else
    backend="?"
  fi
  printf "ollama ($backend)  $(badge_ok)   ${D}:11434  %s model(s): %s${X}\n" "$model_count" "${model_names:-none}"
else
  printf "ollama          $(badge_down) ${D}:11434 unreachable — run ./talktype start${X}\n"
fi

# ---------- app ----------
if [[ -f "$ROOT/.talktype.pid" ]]; then
  pid=$(cat "$ROOT/.talktype.pid")
  if kill -0 "$pid" 2>/dev/null; then
    printf "app             $(badge_ok)   ${D}pid %s${X}\n" "$pid"
  else
    printf "app             $(badge_down) ${D}stale pid %s${X}\n" "$pid"
  fi
else
  # check if app/ even exists
  if [[ -d "$ROOT/app" ]]; then
    printf "app             $(badge_down) ${D}not running — run ./talktype start${X}\n"
  else
    printf "app             $(badge_na)   ${D}not bootstrapped — run ./talktype bootstrap${X}\n"
  fi
fi

# ---------- loki + grafana ----------
if curl -fsS -m 1 http://localhost:3100/ready >/dev/null 2>&1; then
  printf "loki            $(badge_ok)   ${D}:3100${X}\n"
else
  printf "loki            $(badge_na)   ${D}observability profile not running${X}\n"
fi
if curl -fsS -m 1 http://localhost:3000/api/health >/dev/null 2>&1; then
  printf "grafana         $(badge_ok)   ${D}:3000 → http://localhost:3000${X}\n"
else
  printf "grafana         $(badge_na)   ${D}observability profile not running${X}\n"
fi

# ---------- network ----------
if curl -sS -m 2 -o /dev/null -I https://api.anthropic.com/v1/messages 2>/dev/null; then
  printf "network (cloud) $(badge_ok)   ${D}api.anthropic.com reachable${X}\n"
else
  printf "network (cloud) $(badge_warn) ${D}offline — cloud mode will fall back to local${X}\n"
fi

line

# ---------- logs summary ----------
today="$(date +%F)"
logfile="$LOG_DIR/talktype-$today.log.jsonl"
if [[ -f "$logfile" ]]; then
  total=$(wc -l < "$logfile" | tr -d ' ')
  errors=$(grep -c '"level":"error"' "$logfile" 2>/dev/null || echo 0)
  warns=$(grep -c '"level":"warn"' "$logfile" 2>/dev/null || echo 0)
  cleanups=$(grep -c '"msg":"cleanup.done"' "$logfile" 2>/dev/null || echo 0)
  last_cleanup=$(grep '"msg":"cleanup.done"' "$logfile" 2>/dev/null | tail -1 | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
  printf "logs today      ${D}$logfile${X}\n"
  printf "  events: %-6s errors: " "$total"
  if [[ "$errors" -gt 0 ]]; then printf "${R}%s${X}" "$errors"; else printf "%s" "$errors"; fi
  printf "  warns: "
  if [[ "$warns" -gt 0 ]]; then printf "${Y}%s${X}" "$warns"; else printf "%s" "$warns"; fi
  printf "  cleanups: %s\n" "$cleanups"
  if [[ -n "${last_cleanup:-}" ]]; then
    printf "  last dictation: ${D}%s${X}\n" "$last_cleanup"
  fi
else
  printf "logs today      ${D}no log file yet for $today${X}\n"
fi

# ---------- panic ----------
panic_dir="$LOG_DIR/panic"
if [[ -d "$panic_dir" ]]; then
  panic_count=$(find "$panic_dir" -name "panic-*.pcm" -mtime -7 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$panic_count" -gt 0 ]]; then
    printf "panic dumps     ${R}%s in last 7 days${X}   ${D}$panic_dir${X}\n" "$panic_count"
  fi
fi

# ---------- disk + upstream pin ----------
free_gb=$(df -Pk "$ROOT" | awk 'NR==2 {print int($4/1024/1024)}')
if [[ "$free_gb" -lt 5 ]]; then
  printf "disk            ${R}%s GB free${X}  ${D}(tight)${X}\n" "$free_gb"
else
  printf "disk            %s GB free\n" "$free_gb"
fi

pin=$(grep -m1 '^- \*\*Commit:\*\*' "$ROOT/UPSTREAM.md" 2>/dev/null | sed -E 's/.*`([a-f0-9]+)`.*/\1/' | cut -c1-8)
if [[ -d "$ROOT/app/.git" ]]; then
  current=$(git -C "$ROOT/app" rev-parse --short=8 HEAD 2>/dev/null || echo "?")
  if [[ "$current" == "$pin" ]]; then
    printf "upstream        ${D}pinned %s (matches app/)${X}\n" "$pin"
  else
    printf "upstream        ${Y}pinned %s but app/ at %s — run ./talktype sync${X}\n" "$pin" "$current"
  fi
else
  printf "upstream        ${D}pinned %s (app/ not cloned yet)${X}\n" "$pin"
fi

line
