#!/usr/bin/env bash
# talktype doctor — one-shot diagnostic.
# Runs the wrapper's health probes plus platform permission checks.
# Never mutates state. Safe to run anytime.
#
# Flags:
#   --full    Also run real round-trip probes against configured LLM providers:
#             - Ollama /v1/chat/completions with the first installed model
#             - Anthropic /v1/messages (if ANTHROPIC_API_KEY env var set)
#             - Google Gemini /v1beta/models (if GEMINI_API_KEY env var set)
#             - Groq /openai/v1/chat/completions (if GROQ_API_KEY env var set)
#             - OpenAI /v1/chat/completions (if OPENAI_API_KEY env var set)

set -u

FULL=false
for arg in "$@"; do
  case "$arg" in
    --full) FULL=true ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN='\033[1;32m'; RED='\033[1;31m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; RESET='\033[0m'

pass() { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$1"; FAILED=1; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
section() { printf "\n${BLUE}%s${RESET}\n" "$1"; }

FAILED=0

section "macOS permissions"
if [[ "$(uname)" == "Darwin" ]]; then
  if tccutil --help >/dev/null 2>&1; then
    :
  fi
  if [[ -d "/Applications/talktype.app" ]] || pgrep -f "talktype" >/dev/null 2>&1; then
    pass "talktype app detected"
  else
    warn "talktype app not installed or not running (dev mode is fine)"
  fi
  warn "Mic + Accessibility permissions must be granted in System Settings → Privacy & Security. Verify manually."
else
  warn "Not macOS — skipping macOS-specific checks"
fi

section "Ollama (local)"
if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
  pass "ollama responding at :11434"
  MODELS=$(curl -fsS http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
  if echo "$MODELS" | grep -qE "qwen2\\.5|llama3\\.2"; then
    pass "cleanup model present"
  else
    fail "no cleanup model found — run: ollama pull qwen2.5:3b"
  fi
else
  fail "ollama not reachable at :11434 — run 'ollama serve' or 'docker compose -f docker/docker-compose.yml up -d ollama'"
fi

section "Anthropic (cloud, optional)"
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  pass "ANTHROPIC_API_KEY set in env"
else
  CFG="$HOME/Library/Application Support/talktype/config.json"
  if [[ -f "$CFG" ]] && grep -q '"apiKey":"sk-ant' "$CFG"; then
    pass "Anthropic key in config"
  else
    warn "No Anthropic key — cloud mode will fall back to local. This is fine for local-only usage."
  fi
fi

section "Network"
if curl -sS -I https://api.anthropic.com/v1/messages --max-time 3 -o /dev/null 2>/dev/null; then
  pass "internet reachable (api.anthropic.com)"
else
  warn "offline — cloud mode unavailable"
fi

section "Disk"
FREE_GB=$(df -Pk "$ROOT" | awk 'NR==2 {print int($4/1024/1024)}')
if [[ "$FREE_GB" -ge 5 ]]; then
  pass "free space: ${FREE_GB} GB"
else
  fail "low disk: ${FREE_GB} GB free (need at least 5 GB for models + logs)"
fi

section "Wrapper tests"
if (cd "$ROOT/wrapper" && npm test --silent >/dev/null 2>&1); then
  pass "vitest green"
else
  warn "vitest failed or not installed (run: npm --workspace wrapper install && npm test)"
fi

if $FULL; then
  section "Round-trip probes (--full)"

  # Ollama
  first_model=$(curl -fsS -m 2 http://localhost:11434/v1/models 2>/dev/null \
    | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin)
  data=d.get("data") or []
  print(data[0]["id"] if data else "")
except: pass' 2>/dev/null)
  if [[ -n "$first_model" ]]; then
    start=$(date +%s%N)
    resp=$(curl -fsS -m 30 http://localhost:11434/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$first_model\",\"stream\":false,\"messages\":[{\"role\":\"user\",\"content\":\"reply ok\"}]}" 2>/dev/null)
    if [[ -n "$resp" ]]; then
      elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
      pass "Ollama round-trip ($first_model) — ${elapsed}ms"
    else
      fail "Ollama round-trip ($first_model) — no response"
    fi
  else
    warn "Ollama: no models installed — skip round-trip"
  fi

  # Anthropic
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    start=$(date +%s%N)
    http=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d '{"model":"claude-haiku-4-5","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' \
      https://api.anthropic.com/v1/messages 2>/dev/null)
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    [[ "$http" == "200" ]] && pass "Anthropic Haiku 4.5 — HTTP $http · ${elapsed}ms" || fail "Anthropic — HTTP $http · ${elapsed}ms"
  else
    warn "ANTHROPIC_API_KEY not in env — skipping probe"
  fi

  # Gemini
  if [[ -n "${GEMINI_API_KEY:-}" ]]; then
    start=$(date +%s%N)
    http=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" \
      "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" 2>/dev/null)
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    [[ "$http" == "200" ]] && pass "Gemini API — HTTP $http · ${elapsed}ms" || fail "Gemini — HTTP $http · ${elapsed}ms"
  else
    warn "GEMINI_API_KEY not in env — skipping probe"
  fi

  # Groq
  if [[ -n "${GROQ_API_KEY:-}" ]]; then
    start=$(date +%s%N)
    http=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $GROQ_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"model":"llama-3.3-70b-versatile","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' \
      https://api.groq.com/openai/v1/chat/completions 2>/dev/null)
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    [[ "$http" == "200" ]] && pass "Groq llama-3.3-70b — HTTP $http · ${elapsed}ms" || fail "Groq — HTTP $http · ${elapsed}ms"
  else
    warn "GROQ_API_KEY not in env — skipping probe"
  fi

  # OpenAI
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    start=$(date +%s%N)
    http=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{"model":"gpt-5-nano","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' \
      https://api.openai.com/v1/chat/completions 2>/dev/null)
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    [[ "$http" == "200" ]] && pass "OpenAI gpt-5-nano — HTTP $http · ${elapsed}ms" || fail "OpenAI — HTTP $http · ${elapsed}ms"
  else
    warn "OPENAI_API_KEY not in env — skipping probe"
  fi
fi

printf "\n"
if [[ "$FAILED" -eq 0 ]]; then
  printf "${GREEN}All critical checks passed.${RESET}\n"
  exit 0
else
  printf "${RED}One or more critical checks failed.${RESET}\n"
  exit 1
fi
