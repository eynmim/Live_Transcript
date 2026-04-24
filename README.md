# talktype

Local-first AI voice dictation for macOS and Windows. Press a hotkey, speak, polished text appears at your cursor — in any app. Works fully offline.

Built as a reliability-hardened wrapper around [OpenWhispr](https://github.com/OpenWhispr/openwhispr) with optional cloud LLM cleanup (Claude Haiku 4.5) and a ready-to-deploy Docker backend for Ollama.

## Features

- **Local by default** — Whisper/Parakeet STT + Ollama LLM cleanup, zero cloud traffic
- **Cloud optional** — Claude Haiku 4.5 for higher-quality cleanup, toggle per session
- **Raw mode** — skip LLM cleanup entirely, paste raw transcription
- **Per-app prompt templates** — Slack chatty, Gmail formal, VS Code code-aware
- **Fallback ladder** — cloud → local → raw, you never lose a thought
- **Health doctor** — one-command diagnostic for mic/hotkey/Ollama/network
- **Privacy by design** — no audio persisted, no telemetry by default

## Requirements

- **Node 24+** (OpenWhispr pins this). Install via `brew install node@24` or `nvm install 24`. An `.nvmrc` is shipped, so `nvm use` auto-switches.
- **Native Ollama** (recommended, no Docker): `brew install ollama && brew services start ollama`. Auto-starts at boot, ~0 RAM idle.
- **Docker Desktop** (optional — only for home-server or remote-GPU deployment; not needed for daily use).
- macOS 14+ or Windows 10/11.

## What our fork adds on top of OpenWhispr

- **🦙 One-click Ollama preset** in Settings → LLMs → Dictation Cleanup → Self-Hosted. Fills the URL, probes the server, lists detected models. See [UPSTREAM.md](UPSTREAM.md) for the full patch list.
- **▶ Play button on every dictation** in History. Re-listen to any past recording inline — no Finder round-trip.
- **No Docker required.** `ttype start` detects native Ollama first, falls back to Docker only if needed.

## Quick start

Everything goes through the `./talktype` CLI:

```bash
./talktype bootstrap        # clone upstream, install deps, pull models (run once)
./talktype start            # start backend + app
./talktype status           # live dashboard
./talktype logs             # tail today's logs, pretty-printed
./talktype doctor           # full health diagnostic
./talktype stop             # stop everything
```

Want it even shorter? Run once:

```bash
./talktype install-alias    # adds 'ttype' to ~/.zshrc
```

Then from anywhere: `ttype status`, `ttype start`, `ttype logs`, etc.

Or skip the terminal entirely — double-click any of the `.command` files in `launchers/`:

- `start talktype.command` — launches backend + app
- `stop talktype.command` — stops everything
- `restart talktype.command` — clean restart (use after a crash)
- `status talktype.command` — live dashboard

Drag them to Desktop / Dock for one-click access. See [launchers/README.md](launchers/README.md) for icons, Gatekeeper notes, etc.

Default hotkey: **⌥+Space** (configurable in settings).

## Monitoring

- **Quick status:** `./talktype status` — one-line health for Ollama, app, Loki, Grafana, network, disk, upstream pin, today's event/error count, last dictation time.
- **Live logs:** `./talktype logs 200` — pretty JSON log tail.
- **Errors only:** `./talktype errors` — today's errors.
- **Full dashboard:** `./talktype observability` starts Loki+Grafana+Promtail. Then `./talktype open-grafana` opens the talktype dashboard (dictation count, fallback events, panic dumps, error timeline). Provisioned automatically — no config needed.

## Architecture

See [docs/architecture.md](docs/architecture.md). Short version:

```
Electron menubar app  →  wrapper/llm/router  →  Ollama (local) | Claude (cloud)
       ↑
   global hotkey + mic capture + whisper.cpp STT + paste at cursor
```

`app/` is a light fork of OpenWhispr pinned to a specific commit. All novel logic — mode routing, fallback, health probes, per-app prompts — lives in `wrapper/` and is imported via a single typed hook interface.

## Reliability

See [docs/reliability.md](docs/reliability.md) for the full error taxonomy and fallback ladder. Highlights:

- Every failure has a category, a user-facing message, and an automatic fallback
- Config is zod-validated — bad config fails at launch, never mid-dictation
- Last 60 s of audio is saved on crash so nothing is lost
- Structured JSON logs in `~/Library/Logs/talktype/` with daily rotation
- Optional Loki+Grafana observability stack: `docker compose --profile observability up`

## Docker

Docker is used **for backend services only** (Ollama, optional whisper-server, optional observability). The desktop app runs natively because containers can't reliably access the host microphone or inject keystrokes on macOS. See [docker/docker-compose.yml](docker/docker-compose.yml).

To run without Docker: `brew install ollama && ollama serve`. Both paths are supported.

## Project layout

```
talktype/
├── app/          # OpenWhispr fork (pinned)
├── wrapper/      # Our reliability + routing layer (tested)
├── docker/       # Optional backend stack
├── scripts/      # bootstrap / doctor / sync-upstream
├── docs/         # architecture, reliability, second-brain seam
└── .github/      # CI matrix (macOS + Windows)
```

## Upstream sync

`scripts/sync-upstream.sh` rebases our wrapper patches onto the latest OpenWhispr main. Current pin is tracked in [UPSTREAM.md](UPSTREAM.md).

## Remote

The repo lives on GitLab, private: **https://gitlab.com/MoSaleh-AKB/talktype**

Clone URLs:

```
https://gitlab.com/MoSaleh-AKB/talktype.git      # HTTPS (current)
git@gitlab.com:MoSaleh-AKB/talktype.git          # SSH (after adding a key)
```

First-time push (run once):

```bash
# Path A — via the glab CLI (if you have it installed + authenticated)
glab auth status
glab repo create MoSaleh-AKB/talktype --private --defaultBranch main
git remote add origin git@gitlab.com:MoSaleh-AKB/talktype.git
git push -u origin main

# Path B — manual (no CLI needed):
# 1. Open https://gitlab.com/projects/new → "Create blank project"
# 2. Name: talktype · Namespace: mosaleh · Visibility: Private
# 3. Uncheck "Initialize repository with a README"
# 4. Create
# 5. Then run:
git remote add origin git@gitlab.com:MoSaleh-AKB/talktype.git
git push -u origin main
```

Note: our `.github/workflows/ci.yml` won't auto-run on GitLab. A `.gitlab-ci.yml` equivalent is deferred.

## Cloud LLM providers (add all four for A/B testing)

OpenWhispr natively supports all four below. Paste keys in **Settings → LLMs → Dictation Cleanup → Providers → [provider tab] → API key → click "add"**. Then enable the top-level **"Enable text cleanup"** toggle.

| Provider | Best model for cleanup | Cost | How to get key |
|---|---|---|---|
| **Gemini** | `gemini-3-flash-preview` | **Free** — 15 RPM, ~1 M tokens/day | https://aistudio.google.com/app/apikey |
| **Groq** | `llama-3.3-70b-versatile` | **Free tier**, generous rate limit | https://console.groq.com/keys |
| **Anthropic** | `claude-haiku-4-5` | ~$0.25 in / $1.25 out per 1 M tokens (~$0.50/month at typical usage) | https://console.anthropic.com |
| **OpenAI** | `gpt-5-nano` or `gpt-5-mini` | ~$0.20/1 M in | https://platform.openai.com/api-keys |

### Quality ranking for bilingual English + Persian cleanup

1. **Claude Haiku 4.5** — best Persian nuance + instruction following
2. **Gemini 3 Flash** — close second, free
3. **GPT-5 nano** — very fast, slight drop in Persian nuance
4. **Groq llama-3.3-70b** — fastest tokens-per-second but Llama weaker on Persian

Use Gemini or Groq for high-volume / free everyday dictation. Switch to Haiku/GPT when quality matters most (important emails, long Persian notes).

### Local (fully offline)

- **Self-Hosted** → 🦙 Use local Ollama preset → picks up `aya:8b` (already installed) and `aya-expanse:32b` if you pull it.
- Pull Aya Expanse 32B when ready:
  ```bash
  df -h ~                             # confirm ≥20 GB free
  ollama pull aya-expanse:32b         # ~19 GB, one-time
  ```

## License

MIT — same as upstream OpenWhispr. See [LICENSE](LICENSE).
