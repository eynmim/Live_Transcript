# talktype — full handoff prompt for Ali (Windows edition)

Paste everything below (from `---` to end) into a coding assistant (Claude Code, Cursor, Copilot workspace, ChatGPT, whatever). It's self-contained: no decisions left open, no questions to come back with.

Target user: Ali Mansoori. He picked Windows of his own free will, so every macOS-ism below has a Windows-first alternative. If you see both paths, do the Windows one unless Ali overrides.

---

## 0. What this project is (1-minute version)

**talktype** is a local-first AI voice dictation app. Press hotkey → speak English or Persian (or whatever) → polished text gets pasted at the cursor. Built by forking [OpenWhispr](https://github.com/OpenWhispr/openwhispr) (MIT-licensed Electron dictation app) and adding a **reliability wrapper + CLI + observability layer + 5 code patches**.

Why fork OpenWhispr instead of building from scratch:
- It already has whisper.cpp (local STT), llama.cpp (local LLM), all the major cloud providers (OpenAI / Anthropic / Gemini / Groq), global hotkey, mic capture, paste-at-cursor, audio retention, meeting detection, vector search, and a notes app.
- MIT license → we can relicense / patch freely.
- Active (release on 2026-04-20, 2.6k stars, 43 contributors).

Why not Wispr Flow: closed-source + cloud-only + subscription. We want local-first + bilingual (Persian!) + extensible.

---

## 1. Final stack to reproduce

```
talktype/
├── app/                         # cloned OpenWhispr (pinned commit) — NOT committed
├── wrapper/                     # TypeScript reliability layer (vitest) — committed
├── patches/                     # 5 .patch files applied on top of app/ — committed
├── scripts/                     # bootstrap / doctor / sync-upstream / status / logs
├── docker/                      # optional — compose with Ollama + Loki + Grafana
├── launchers/                   # double-click .command (mac) / .bat (windows)
├── docs/                        # architecture + reliability + second-brain seam
├── .gitlab-ci.yml               # wrapper tests on every push
├── .github/workflows/ci.yml     # same but for GitHub
├── talktype                     # bash CLI entry (use via Git Bash on Windows)
├── package.json                 # workspaces: wrapper
├── UPSTREAM.md                  # pinned SHA + our patch list
├── CLAUDE.md                    # instructions for Claude Code
├── README.md
└── PROMPT.md                    # this file
```

### Upstream pin

`dbe1b6ac239bed7a64a5d36ccdfbb865adeda556` of `github.com/OpenWhispr/openwhispr` (commit "feat(folders): cascade delete notes with confirmation dialog", 2026-04-21).

### Models (runtime)

| Layer | Model | Disk | Notes |
|---|---|---|---|
| **STT (local)** | Whisper `large-v3-turbo` | ~1.5 GB | Bundled via OpenWhispr's `npm run download:whisper-cpp` |
| **LLM cleanup (local)** | `aya-expanse:32b` via Ollama | ~19 GB | Cohere's strongest multilingual 32B (great Persian) |
| **LLM cleanup (cloud, free)** | Gemini 3 Flash | 0 | Google AI Studio key, free tier 15 RPM / 1M TPD |
| **LLM cleanup (cloud, free)** | Groq llama-3.3-70b | 0 | Free tier, very fast |
| **LLM cleanup (cloud, paid)** | Claude Haiku 4.5 | 0 | Best Persian quality, ~$0.50/mo typical |
| **LLM cleanup (cloud, paid)** | GPT-5-nano | 0 | Cheapest paid tier |

Ali can start free (Gemini + Groq + local Ollama). Add paid only if he wants A/B quality comparison.

---

## 2. Platform prerequisites (Windows)

Install these before anything else. On Windows, use **winget** where possible, or direct installer. Everything below runs in **Git Bash** (ships with Git for Windows) because our scripts are bash.

```powershell
# Run in PowerShell (as administrator for first install)

# 1. Git for Windows — gives us git + Git Bash
winget install --id Git.Git -e

# 2. Node 24 — OpenWhispr pins engines.node >=24
winget install --id OpenJS.NodeJS -e --version 24.15.0
# OR via nvm-windows for easy version switching:
# winget install CoreyButler.NVMforWindows
# nvm install 24.15.0 ; nvm use 24.15.0

# 3. Ollama — native install, not Docker (Docker on Windows adds WSL overhead for nothing)
winget install --id Ollama.Ollama -e
# After install: Ollama runs as a service automatically on http://localhost:11434

# 4. Python 3 — needed by one OpenWhispr build script
winget install --id Python.Python.3.12 -e

# 5. Visual Studio Build Tools — needed for native node-gyp modules (better-sqlite3, etc.)
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
# During install, tick "Desktop development with C++"

# 6. (Optional) Windows Terminal for a decent shell experience
winget install --id Microsoft.WindowsTerminal -e
```

Verify:

```bash
# In Git Bash (right-click in any folder → "Open Git Bash Here"):
node --version      # should print v24.15.0
npm --version
ollama list         # should print empty models list (no error)
python --version    # 3.12.x
git --version
```

If `node` doesn't match v24, close and reopen Git Bash, then `which node` to find which one got picked up.

---

## 3. Clone + bootstrap

```bash
# Pick a home directory (NOT one with spaces — OpenWhispr's scripts hate spaces in paths)
mkdir -p ~/dev && cd ~/dev

# Option A: clone from Saleh's private GitLab (needs access)
git clone https://gitlab.com/MoSaleh-AKB/talktype.git
cd talktype

# Option B: build from scratch — follow the "Patches to re-apply" section below
```

Bootstrap:

```bash
# This clones OpenWhispr at the pinned SHA into app/, installs all deps,
# runs the native-binary download scripts, and pulls Ollama models.
./scripts/bootstrap.sh
```

Expect the bootstrap to take 10–20 min on first run. It downloads:
- Whisper large-v3-turbo (~1.5 GB)
- aya-expanse:32b via Ollama (~19 GB)
- whisper-server binary + qdrant binary + embedding model (all small)
- ~1.3k npm packages

If bootstrap fails on Windows with "cannot find Python", make sure Python is on PATH and run `npm config set python python3`.

---

## 4. The five custom patches (what we did on top of OpenWhispr)

All live in `patches/*.patch` and are applied automatically by `bootstrap.sh`. Here's what each one does, so Ali knows what he's inheriting.

### Patch 01 — Ollama preset in Self-Hosted

**File:** `src/components/SelfHostedPanel.tsx`
**What:** Settings → LLMs → Dictation Cleanup → Self-Hosted now has a "🦙 Use local Ollama" button that auto-fills `http://localhost:11434/v1`, probes the server, and shows detected models as chips (e.g. `aya-expanse:32b`). Tells Ali if Ollama isn't running.

### Patch 02 — Play button on History

**File:** `src/components/ui/TranscriptionItem.tsx`
**What:** Each past dictation gets a ▶ Play/Pause button. Click to re-listen to the raw audio without opening Finder / File Explorer. Uses the existing `get-audio-buffer` IPC, serves it as a Blob URL into a hidden `<audio>` element.

### Patch 03 — "Never delete" audio retention

**Files:** `src/components/SettingsPage.tsx` + `src/helpers/audioStorage.js`
**What:** Privacy & Data → retention dropdown gets a "Never delete (keep forever)" option at the top. Shortcuts the cleanup sweep when `retentionDays < 0`.

### Patch 04 — Panic dump on crash

**File:** `main.js`
**What:** On uncaughtException / unhandledRejection, writes a structured JSON dump to:
- macOS: `~/Library/Logs/talktype/panic/panic-<ts>.json`
- **Windows: `%APPDATA%\talktype\panic\panic-<ts>.json`** (Ali — we'll patch the hardcoded path below)

Contains error, stack, Node + Electron versions, platform, arch, argv, pid. Useful for post-mortem debugging.

**Windows adjustment needed:** the patch hardcodes `os.homedir() + /Library/Logs/...` — adapt to Windows with `process.platform === "win32" ? path.join(os.homedir(), "AppData", "Roaming", "talktype", "panic") : ...`. See [Patch adjustments for Windows](#6-patch-adjustments-for-windows).

### Patch 05 — Voice-action triggers (the big win)

**Files:** `src/helpers/ipcHandlers.js` + `preload.js` + `src/helpers/audioManager.js`
**What:** Dictate a sentence ending with a trigger phrase and talktype not only transcribes but also presses a key after paste. Makes "dictate + send" a single motion.

Trigger phrases shipped:

| Action | English | Persian |
|---|---|---|
| **Enter** | send it · send this · send message · press enter · hit enter · submit · submit it · post it · post this · go ahead · do it · send go | بفرستش · بفرستیدش · ارسالش کن · ارسال کن · بفرست · اوکی کن · تایید کن · انجام بده · اجرا کن · اجراش کن · به فرستش |
| **Tab** | press tab · hit tab · next field · tab over | تب بزن · فیلد بعدی · برو بعدی |
| **Escape** | press escape · hit escape · cancel this/it · close this/it/dialog | کنسل کن · ببندش · لغوش کن · بی خیال |

Implementation:
1. New IPC `simulate-key-press` (macOS: `osascript -e 'tell application "System Events" to key code 36'`; **Windows: needs PowerShell `SendKeys` or nircmd — see below**).
2. Preload exposes `window.electronAPI.simulateKeyPress(key)`.
3. `audioManager.safePaste()` runs `_detectVoiceAction(text)` before paste. On match: strip the trigger, paste cleaned text, wait 300 ms, fire the mapped key.

**Windows adjustment needed:** the IPC handler uses `osascript` which doesn't exist on Windows. Ali will swap it for PowerShell:

```js
// In src/helpers/ipcHandlers.js — replace the darwin-only branch:
if (process.platform === "win32") {
  const vkMap = { return: "{ENTER}", enter: "{ENTER}", tab: "{TAB}", escape: "{ESC}" };
  const keystroke = vkMap[normalized];
  if (!keystroke) return { success: false, error: `unsupported key ${keyName}` };
  const { spawn } = require("child_process");
  await new Promise((resolve, reject) => {
    const proc = spawn("powershell", [
      "-NoProfile",
      "-Command",
      `[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.SendKeys]::SendWait('${keystroke}')`,
    ]);
    proc.on("error", reject);
    proc.on("close", (code) => (code === 0 ? resolve() : reject(new Error(`powershell exit ${code}`))));
  });
  return { success: true };
}
```

---

## 5. The `ttype` CLI and monitoring

Our bash CLI ships as `./talktype`. On Windows via Git Bash it works directly. Subcommands:

```
./talktype start              # start backend (native Ollama) + launch Electron app
./talktype start --watch      # auto-restart Electron on crash
./talktype stop               # stops app + kills stale Vite/Electron
./talktype restart            # clean stop + fresh start
./talktype status             # live dashboard: ollama, app, loki, grafana, network, disk
./talktype logs [N]           # tail last N log lines, pretty-printed
./talktype errors             # today's errors only
./talktype doctor             # full health diagnostic
./talktype doctor --full      # also probes each configured cloud provider with latency
./talktype test               # wrapper unit tests (13 vitest cases)
./talktype bootstrap          # re-run setup (idempotent)
./talktype sync               # rebase our patches on latest OpenWhispr main
./talktype observability      # start Loki + Grafana (optional)
./talktype install-alias      # add 'ttype' to ~/.bashrc + Ollama speed env vars
```

**Windows note:** `install-alias` writes to `~/.zshrc` on macOS. On Windows Git Bash it needs to write to `~/.bashrc` instead. Small edit — change the `case "${SHELL##*/}"` branch to include Git Bash.

---

## 6. Patch adjustments for Windows

Before `./scripts/bootstrap.sh` applies patches, Ali should open these patch files and tweak:

### `patches/04-panic-dump-on-crash.patch`

Replace the hardcoded `~/Library/Logs/talktype` path with cross-platform:

```js
const panicDir = pathMod.join(
  os.homedir(),
  process.platform === "darwin" ? "Library/Logs/talktype/panic"
    : process.platform === "win32" ? "AppData/Roaming/talktype/panic"
    : ".local/share/talktype/panic",
  ""
);
```

### `patches/05-voice-action-triggers.patch`

Replace the macOS osascript branch with the PowerShell SendKeys branch shown in [Patch 05](#patch-05--voice-action-triggers-the-big-win).

### `talktype` CLI

Two things:
1. `cmd_stop`'s `pkill -f` doesn't exist on Windows. Add a branch that uses `taskkill /F /IM Electron.exe /IM node.exe` when `[[ "$OSTYPE" == "msys" ]]`.
2. `cmd_install_alias` case statement needs a `msys|cygwin)` branch that writes to `~/.bashrc`.

---

## 7. Launchers — `.bat` files for Windows (we only shipped `.command` for macOS)

Create these four files in `launchers/windows/`:

**`start talktype.bat`:**
```bat
@echo off
cd /d "%~dp0\..\.."
start /min "" bash -c "./talktype start" > "%APPDATA%\talktype\launcher.log" 2>&1
exit
```

**`stop talktype.bat`:**
```bat
@echo off
cd /d "%~dp0\..\.."
bash -c "./talktype stop"
pause
```

**`restart talktype.bat`:**
```bat
@echo off
cd /d "%~dp0\..\.."
bash -c "./talktype stop && ./talktype start" &
exit
```

**`status talktype.bat`:**
```bat
@echo off
cd /d "%~dp0\..\.."
bash -c "./talktype status"
pause
```

Drag these to Desktop / pin to Start Menu. Right-click → Properties → pick a custom icon if you want.

---

## 8. Cloud LLM providers — one-time setup in app Settings

Once the app is running (`./talktype start`):

1. Open app → Settings → LLMs → Dictation Cleanup → **Providers**.
2. For each of the four tabs:
   - **Google Gemini** (free, ⭐): paste key from https://aistudio.google.com/app/apikey, model `gemini-3-flash-preview`, save
   - **Groq** (free, ⭐): paste key from https://console.groq.com/keys, model `llama-3.3-70b-versatile`, save
   - **Anthropic** (paid, best quality): key from https://console.anthropic.com, model `claude-haiku-4-5`, save
   - **OpenAI** (paid, cheapest): key from https://platform.openai.com/api-keys, model `gpt-5-nano`, save
3. Enable the top-level "Enable text cleanup" toggle.
4. Pick one provider as active; switch per session as desired.

### Ordering recommendation for Persian + English daily use
1. Default: **Gemini** (free, best quality for Persian of the free tier)
2. Fallback: **Groq** (also free, much faster but weaker Persian)
3. Paid upgrade: **Anthropic Haiku 4.5** (best Persian, ~$0.50/mo typical)

---

## 9. How to re-apply our patches from scratch (Option B path)

If Ali can't clone our GitLab, here's how to build equivalent from upstream:

```bash
mkdir -p ~/dev/talktype && cd ~/dev/talktype
git init -b main

# Clone OpenWhispr at the pinned SHA
git clone --no-checkout https://github.com/OpenWhispr/openwhispr.git app
git -C app checkout dbe1b6ac239bed7a64a5d36ccdfbb865adeda556

# Install deps + download bundled binaries
cd app
npm install
npm run download:whisper-cpp
npm run download:llama-server
npm run download:sherpa-onnx
cd ..
```

Then apply each patch by reading the .patch files and porting the changes (or ask the coding assistant to reproduce them given the file paths + behavior described in Section 4 above).

For each patch, the assistant should:
1. Read the target file in `app/src/...`
2. Make the edit exactly as described in Section 4 (with Windows adjustments from Section 6)
3. Save the diff as `patches/NN-name.patch`
4. Verify with `./talktype test` (wrapper tests) and manual smoke test in the app

---

## 10. What Ali needs to do, step-by-step

```bash
# 1. Install prereqs (Section 2) — PowerShell as admin once
# 2. Clone + bootstrap (Section 3) — Git Bash
git clone https://gitlab.com/MoSaleh-AKB/talktype.git ~/dev/talktype
cd ~/dev/talktype
./scripts/bootstrap.sh

# 3. Patch for Windows (Section 6) — tweak patches/04 and patches/05 before first run
# 4. Start the app
./talktype start

# 5. Grant permissions when Windows asks (mic). No "accessibility" concept on Windows —
#    SendKeys works out of the box.

# 6. Configure providers (Section 8) — in the app UI, paste API keys

# 7. Test:
#    - Press hotkey (default: Ctrl+Space or Win+Space — configurable in Settings)
#    - Say: "hey how are you send it"
#    - Expected: "Hey, how are you" pastes + Enter fires (your iMessage-equivalent sends)
```

---

## 11. Repository state at handoff time

- GitLab: https://gitlab.com/MoSaleh-AKB/talktype (private)
- Branch: `main`
- Commit count at handoff: 13+
- Wrapper tests: 13/13 green
- Patches applied: 5 (01-05)
- CI: wrapper tests run on every GitLab push

---

## 12. Known gotchas Ali will hit

1. **Node version**: npm install dies on Node < 24 with `EBADENGINE`. If `node --version` shows anything older, `nvm use 24` (or reinstall via winget).
2. **OpenWhispr preload exposes `window.electronAPI`**, NOT `window.api`. Any custom renderer code must use the full namespace — we hit this bug once.
3. **Port 5183 stuck after crash**: `./talktype stop` now handles this with `pkill` patterns; on Windows the CLI stop needs a `taskkill` branch (Section 6).
4. **`concurrently` forks several children** — stopping via PID only kills the wrapper shell, leaving Vite/Electron/whisper-server alive. Our patch handles this.
5. **Ollama port 11434** conflicts if Docker Ollama runs too. On Windows, native is easier — no Docker.
6. **API keys in source**: never commit them. They go in `chrome.storage.local` via the Settings UI (OpenWhispr writes them to its own `.env` in `%APPDATA%\OpenWhispr-development\.env`).

---

## 13. What's explicitly deferred (not built yet, and that's fine)

- Notes↔audio linkage + Play button on Notes view (patch 02 already ships Play on **History** which covers the main use case)
- "Export audio with markdown" toggle in note-files mirror
- Wrapper hooks wired into the app (ESM/CJS interop cost too high; existing Pipeline-timing log already carries the provider info)
- Deepgram Nova-3 Persian streaming STT (paid, would replace Whisper for real-time)
- Custom dictionary UI extension (OpenWhispr has it, Ali can add Persian names himself)
- Per-app cleanup prompts (Slack chatty vs Gmail formal)

If Ali wants any of these, they're well-scoped — each can be a follow-up PR.

---

## 14. When you (the coding assistant) are done

Print a final checklist Ali can verify:

```
[ ] node --version → v24.x
[ ] ollama list → shows aya-expanse:32b
[ ] ./talktype status → ollama ● up, app ● up, network ● up
[ ] ./talktype test → 13/13 green
[ ] Settings → Providers → Gemini key saved + "Enable text cleanup" ON
[ ] Dictate "testing 123 send it" in any text field → pastes "testing 123" + presses Enter
[ ] History → hover any past item → ▶ button plays the recording
[ ] launchers/windows/*.bat double-clickable from Desktop
```

Don't ask Ali for design decisions — this doc has made them. If you hit something genuinely novel (a Windows path we didn't anticipate, a new Whisper crash), solve it locally and note it in a new commit.

End of prompt.
