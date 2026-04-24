#!/usr/bin/env bash
# talktype upstream sync.
# 1. Fetches upstream OpenWhispr main.
# 2. Moves the pin in UPSTREAM.md to the new HEAD.
# 3. Re-applies our patches (app/patches/*.patch).
# 4. Runs wrapper tests.
#
# If any patch fails to apply, script stops and prints the conflict.
# Resolve the patch, regenerate it with `git -C app diff > patches/NN-name.patch`,
# then commit and re-run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf "\033[1;34m[sync]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[sync]\033[0m %s\n" "$*" >&2; }

if [[ ! -d "$ROOT/app/.git" ]]; then
  err "app/ is not a git clone. Run ./scripts/bootstrap.sh first."
  exit 1
fi

log "fetching upstream"
git -C "$ROOT/app" fetch origin main --prune

OLD_SHA="$(grep -m1 '^- \*\*Commit:\*\*' "$ROOT/UPSTREAM.md" | sed -E 's/.*`([a-f0-9]+)`.*/\1/')"
NEW_SHA="$(git -C "$ROOT/app" rev-parse origin/main)"

if [[ "$OLD_SHA" == "$NEW_SHA" ]]; then
  log "already at upstream HEAD ($NEW_SHA) — nothing to do"
  exit 0
fi

log "upstream moved: $OLD_SHA -> $NEW_SHA"
NEW_DATE="$(git -C "$ROOT/app" log -1 --format=%cI origin/main)"
NEW_MSG="$(git -C "$ROOT/app" log -1 --format=%s origin/main)"

log "checking out $NEW_SHA"
git -C "$ROOT/app" checkout "$NEW_SHA"

log "re-applying patches"
if [[ -d "$ROOT/patches" ]]; then
  for patch in "$ROOT/patches"/*.patch; do
    [[ -e "$patch" ]] || continue
    log "  applying $(basename "$patch")"
    if ! git -C "$ROOT/app" apply --check "$patch"; then
      err "patch $(basename "$patch") does not apply cleanly on $NEW_SHA"
      err "resolve manually, regenerate the patch, and re-run."
      exit 2
    fi
    git -C "$ROOT/app" apply "$patch"
  done
fi

log "updating UPSTREAM.md pin"
python3 - <<PY
import re, pathlib
p = pathlib.Path("$ROOT/UPSTREAM.md")
t = p.read_text()
t = re.sub(r'(- \*\*Commit:\*\* )\`[a-f0-9]+\`', r"\\1\`$NEW_SHA\`", t, count=1)
t = re.sub(r'(- \*\*Date:\*\* ).*', r"\\1$NEW_DATE", t, count=1)
t = re.sub(r'(- \*\*Message:\*\* ).*', lambda m: m.group(1) + """$NEW_MSG""", t, count=1)
p.write_text(t)
PY

log "running wrapper tests"
(cd "$ROOT" && npm test)

log "sync complete. Commit UPSTREAM.md + any regenerated patches."
