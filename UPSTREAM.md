# Upstream

We fork [OpenWhispr/openwhispr](https://github.com/OpenWhispr/openwhispr). This file records the pinned commit and our deltas.

## Pinned

- **Repo:** `https://github.com/OpenWhispr/openwhispr`
- **Branch:** `main`
- **Commit:** `dbe1b6ac239bed7a64a5d36ccdfbb865adeda556`
- **Date:** 2026-04-21T02:04:04Z
- **Message:** feat(folders): cascade delete notes with confirmation dialog

## Why this pin

Picked from the latest `main` at the time of bootstrap. OpenWhispr ships releases frequently (75 so far); we prefer `main` over tagged releases for the freshest fixes, and rebase our patches weekly via `scripts/sync-upstream.sh`.

## Our patches (applied in order)

Each patch lives under `patches/NN-name.patch` and is regenerated with `scripts/sync-upstream.sh`. Patches should be as small and orthogonal as possible.

Current patches:

1. **`01-ollama-preset-in-selfhosted.patch`** (162 lines) — enhances `src/components/SelfHostedPanel.tsx` for the Reasoning/Dictation-Cleanup path:
   - Adds a "🦙 Use local Ollama" preset button that fills the URL field with `http://localhost:11434/v1`.
   - Probes the URL and shows a live reachability badge (green: "reachable · N models" / red: "unreachable (timeout)" / muted: "probing…").
   - When reachable, lists detected models as chips so the user can verify their Ollama has the model they expect.
   - Shows an install hint if Ollama is not running.
   - All strings use `t()` with `defaultValue` fallbacks for graceful i18n.
   - **No IPC changes, no schema changes** — UI-only enhancement of an existing component.

2. **`02-play-button-on-history.patch`** (147 lines, v2) — enhances `src/components/ui/TranscriptionItem.tsx`:
   - Adds a **Play/Pause button** on every history item that has audio (`has_audio === 1`).
   - Fetches audio via `window.electronAPI.getAudioBuffer(id)` (preload binding; v1 mistakenly used `window.api`), wraps in a Blob URL, plays via hidden `<audio>` element.
   - Defensive buffer normalization — handles `ArrayBuffer`, `Uint8Array`, and the `{type:"Buffer",data:[...]}` shape that Node Buffers sometimes serialize to across the IPC boundary.
   - `isPlaying` state chained to the actual `.play()` promise so the icon reliably toggles ▶ ⇄ ⏸ even if autoplay is briefly blocked.
   - Cleans up blob URLs on unmount.
   - **No IPC changes, no schema changes** — uses the existing `getAudioBuffer` preload surface. Upstream already tracked `has_audio`, they just never shipped in-app playback.

3. **`03-never-delete-retention.patch`** (37 lines) — adds a "Never delete (keep forever)" option to the audio retention dropdown in Settings → Privacy & Data.
   - `src/helpers/audioStorage.js` — `cleanupExpiredAudio` short-circuits when `retentionDays < 0`, returning `{ deleted: 0, kept: <all files> }` and logging "retention=never".
   - `src/components/SettingsPage.tsx` — new `<option value={-1}>` at the top of the dropdown.
   - No DB changes, no IPC changes, no store changes (the store already accepts any number).

5. **`05-voice-action-triggers.patch`** (116 lines) — voice-triggered post-paste actions. Touches three files:
   - `src/helpers/ipcHandlers.js` — new `simulate-key-press` IPC handler. macOS-only (via `osascript key code N`). Safelist: `return`/`enter`/`tab`/`escape`. Returns `{success: false}` on unknown key or non-Darwin.
   - `preload.js` — exposes `window.electronAPI.simulateKeyPress(key)`.
   - `src/helpers/audioManager.js` — `safePaste(text, opts)` now first calls `_detectVoiceAction(text)`, which checks the tail of the transcript against a rule set of trigger phrases. On match: strip the phrase, paste the cleaned text, wait 300 ms for paste's clipboard restore to finish, then fire the mapped key.
   - Defaults shipped (no settings UI yet):
     - **Enter/Return:**
       - EN: `send it` · `send this` · `send message` · `press enter` · `hit enter` · `submit` · `submit it` · `post it`
       - FA: `بفرستش` · `بفرستیدش` · `ارسالش کن` · `ارسال کن` · `بفرست` · `اوکی کن` · `تایید کن`
     - **Tab:**
       - EN: `press tab` · `hit tab` · `next field` · `tab over`
       - FA: `تب بزن` · `فیلد بعدی` · `برو بعدی`
     - **Escape:**
       - EN: `press escape` · `hit escape` · `cancel this` · `cancel it` · `close this` · `close it` · `close dialog`
       - FA: `کنسل کن` · `ببندش` · `لغوش کن` · `بی خیال`
   - Example: dictating `"سلام نانا خوبی بفرستش"` in iMessage now pastes `سلام نانا خوبی` and presses Enter — message sends.

4. **`04-panic-dump-on-crash.patch`** (61 lines) — augments `main.js` error handlers:
   - On `uncaughtException` or `unhandledRejection` (non-EPIPE), writes a structured JSON dump to `~/Library/Logs/talktype/panic/panic-<iso-ts>.json`.
   - Dump contains: error message, stack, error code, Node + Electron versions, platform, arch, argv, pid, timestamp.
   - Idea was "last 60 s of audio" from the original plan — revised because OpenWhispr doesn't maintain a continuous ring buffer (audio is only persisted once transcription completes). A debugging context dump is still high-value for post-mortem crash analysis.
   - No IPC changes, no schema changes. Handler is pure Node `fs`, no Electron APIs that could be mid-teardown during the crash.

Deferred / not planned:

- `05-notes-audio-linkage.patch` — **deferred** (~300 lines, 6 files): `notes.transcription_id` column + migration backfill + IPC handler `note:get-audio-path` + Play button on Note list items + `exportAudioWithNotes` setting that copies `.webm` alongside `.md` in markdown-mirror. Users can already re-listen from transcription **History** via the Play button shipped in patch 02, so the incremental value is modest.
- `06-ollama-as-6th-local-tile.patch` — **not planned** (redundant): would add Ollama as a separate tile under "Local" mode in the provider picker. Patch 01's 🦙 preset button in Self-Hosted delivers equivalent UX with a much smaller patch. Skip unless upstream changes Self-Hosted behavior.
- `07-wrapper-hooks.patch` — **skipped**: would import `wrapper/src/index.ts` (TypeScript ESM) into `main.js` (CommonJS). Provides nominally richer logging + a seam for future 2Brain capture, but the existing `logger.info("Pipeline timing", …, "performance")` line in `src/helpers/audioManager.js:594` already carries `model` (the actual provider) + `reasoningProcessingDurationMs`. ESM/CJS interop cost isn't justified.

## Sync procedure

```bash
./scripts/sync-upstream.sh
# Fetches upstream main, rebases our patches, runs tests.
# If a patch fails to apply, the script stops and prints the conflict.
# Resolve, commit, then re-run.
```

## Divergence policy

If upstream adds a feature that makes one of our patches obsolete, drop the patch. If upstream changes an interface we depend on, update our wrapper — never fork deeper into `app/`.

We never patch `app/` for something the wrapper could do.
