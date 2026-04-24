#!/usr/bin/env bash
# talktype bootstrap — idempotent one-shot setup.
# Clones the pinned OpenWhispr commit into app/, installs wrapper deps,
# optionally pulls Ollama models. Safe to re-run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UPSTREAM_REPO="https://github.com/OpenWhispr/openwhispr.git"
UPSTREAM_SHA="$(grep -m1 '^- \*\*Commit:\*\*' UPSTREAM.md | sed -E 's/.*`([a-f0-9]+)`.*/\1/')"

if [[ -z "${UPSTREAM_SHA:-}" ]]; then
  echo "ERROR: could not parse UPSTREAM.md for commit SHA" >&2
  exit 1
fi

log() { printf "\033[1;34m[bootstrap]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[bootstrap]\033[0m %s\n" "$*" >&2; }
fail() { printf "\033[1;31m[bootstrap]\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- 0. preflight ----------
REQUIRED_NODE_MAJOR=24
CURRENT_NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo "0")
if [[ "$CURRENT_NODE_MAJOR" -lt "$REQUIRED_NODE_MAJOR" ]]; then
  cat >&2 <<EOF

  ✗ Node $REQUIRED_NODE_MAJOR+ required by OpenWhispr (found: $(node --version 2>/dev/null || echo 'none'))

  Install one of:
    brew install node@24 && brew link --overwrite node@24
    nvm install 24 && nvm use 24
    fnm install 24 && fnm use 24

  Then re-run: ttype bootstrap

EOF
  exit 1
fi
log "node $(node --version) OK"

# ---------- 1. clone upstream ----------
if [[ ! -d "$ROOT/app/.git" ]]; then
  log "cloning OpenWhispr into app/ at $UPSTREAM_SHA"
  rm -rf "$ROOT/app"
  git clone --no-checkout "$UPSTREAM_REPO" "$ROOT/app"
  git -C "$ROOT/app" checkout "$UPSTREAM_SHA"
else
  CURRENT_SHA="$(git -C "$ROOT/app" rev-parse HEAD)"
  if [[ "$CURRENT_SHA" != "$UPSTREAM_SHA" ]]; then
    log "upstream at $CURRENT_SHA; re-checking out pinned $UPSTREAM_SHA"
    git -C "$ROOT/app" fetch --all --prune
    git -C "$ROOT/app" checkout "$UPSTREAM_SHA"
  else
    log "app/ already at pinned $UPSTREAM_SHA"
  fi
fi

# ---------- 2. apply our patches ----------
if [[ -d "$ROOT/patches" ]]; then
  log "applying local patches"
  for patch in "$ROOT/patches"/*.patch; do
    [[ -e "$patch" ]] || continue
    if git -C "$ROOT/app" apply --check --recount "$patch" 2>/dev/null; then
      git -C "$ROOT/app" apply --recount "$patch"
      log "  applied $(basename "$patch")"
    else
      warn "  $(basename "$patch") already applied or conflicts — skipping"
    fi
  done
fi

# ---------- 3. install deps ----------
log "installing wrapper deps"
(cd "$ROOT" && npm install --workspace wrapper)

log "installing app deps"
if [[ -f "$ROOT/app/package-lock.json" ]]; then
  (cd "$ROOT/app" && npm ci)
else
  (cd "$ROOT/app" && npm install)
fi

# ---------- 3b. download native binaries OpenWhispr expects at build time ----------
# These are fetched by `prebuild:mac` during a production build, but `npm install`
# alone skips them — so a dev run fails with "whisper-server binary not found".
log "downloading native binaries (whisper-server + llama-server + sherpa-onnx)"
(cd "$ROOT/app" && npm run download:whisper-cpp)   || warn "whisper-server download failed — local STT will not work"
(cd "$ROOT/app" && npm run download:llama-server)  || warn "llama-server download failed — local LLM cleanup will not work"
(cd "$ROOT/app" && npm run download:sherpa-onnx)   || warn "sherpa-onnx download failed — Parakeet STT unavailable (optional)"
# meeting-aec-helper and diarization-models are only needed for meeting
# transcription features — skip unless you use them.

# ---------- 4. Ollama (native preferred, Docker optional) ----------
# Default path: native Ollama installed via `brew install ollama`.
# Docker compose is still supported for home-server / remote-GPU setups but
# is no longer required for daily local use.
if command -v ollama >/dev/null 2>&1; then
  if ! curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
    log "starting native ollama service (brew services)"
    brew services start ollama >/dev/null 2>&1 || ollama serve >/dev/null 2>&1 &
    for i in 1 2 3 4 5 6 7 8; do
      curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1 && break
      sleep 1
    done
  fi
  log "native ollama reachable — pulling cleanup models"
  ollama pull aya:8b     || warn "pull aya:8b failed (ignoring)"
  ollama pull qwen2.5:3b || warn "pull qwen2.5:3b failed (ignoring)"
  # Mark native so talktype CLI skips Docker
  touch "$ROOT/.talktype.native-ollama"
else
  warn "native ollama not found. Install with:"
  warn "    brew install ollama && brew services start ollama"
  warn "Docker compose path is still available: ttype start (auto-detects)."
fi

log "bootstrap complete"
log "next: ./scripts/doctor.sh && npm run dev"
