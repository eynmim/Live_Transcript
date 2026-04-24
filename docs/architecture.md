# Architecture

talktype is a thin reliability + routing layer on top of OpenWhispr. The layering is deliberate: we stay close to upstream so fixes flow in, and concentrate our novel logic in one testable package.

## High-level

```
┌─────────────────────────────────────────────────────────────┐
│  app/  —  Electron menubar app (OpenWhispr fork, pinned)    │
│                                                             │
│    ┌──────────────┐  mic  ┌────────────┐  text             │
│    │ global hotkey│──────▶│ whisper.cpp│──────▶            │
│    └──────────────┘       └────────────┘       │           │
│                                                ▼           │
│    ┌──────────────┐  paste ┌──────────────────────┐        │
│    │ robotjs /    │◀───────│  wrapper.onCleanup() │        │
│    │ nut.js       │        └────┬─────────────────┘        │
│    └──────────────┘             │                          │
└─────────────────────────────────┼──────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────┐
│  wrapper/  —  our reliability + routing layer               │
│                                                             │
│  llm/router  ──┬─▶ llm/anthropic ──▶ api.anthropic.com     │
│                │                                            │
│                └─▶ llm/ollama    ──▶ localhost:11434        │
│                                                             │
│  reliability/fallback  (cloud → local → raw ladder)         │
│  reliability/health    (mic / ollama / network probes)      │
│  reliability/errors    (typed WrapperError union)           │
│  telemetry/logger      (daily-rotated JSONL logs)           │
│  hooks/post-transcript (extension seam — Second Brain v2)   │
└─────────────────────────────────────────────────────────────┘
```

## Flow: hotkey press → text at cursor

1. User presses ⌥+Space. OpenWhispr's `globalShortcut` fires.
2. `wrapper.onHotkey()` runs health probes — if any fail, a banner is shown and mode may auto-switch (e.g. cloud → local when offline).
3. Mic capture begins. VAD decides when the user stopped talking.
4. PCM buffer → `whisper.cpp` → raw text.
5. `wrapper.onCleanup({ text, targetApp })` is called.
6. Router picks the effective mode (per-app override or global) and calls `cleanupWithFallback`.
7. Fallback ladder tries providers in order for the chosen mode; each provider is a `LlmProvider` with `isAvailable()` + `clean()`.
8. Cleaned text is returned to the app.
9. App pastes at cursor via robotjs/nut.js.
10. `runPostTranscript()` fires registered handlers (Second Brain capture hooks later).

## Why this split

- **app/ is the "what the user sees + OS glue"** — Electron, hotkeys, mic, paste. We don't want to own this; it's mature in OpenWhispr.
- **wrapper/ is the "what makes it reliable"** — routing, fallback, health, config, prompts. This is where bugs live and where tests pay off.
- **Single interface** — `WrapperHooks` in `wrapper/src/types.ts`. Everything the app touches goes through this type. Change it carefully.

## Extension points

- `hooks/post-transcript.ts` — register a handler to write transcripts into the Second Brain vault, Notion, a file, whatever.
- `llm/` — drop a new `LlmProvider` in (e.g. `gemini.ts`, `groq.ts`) and add it to the router.
- `prompts/` — add a new `TargetApp` or change style hints.

## What we deliberately don't own

- Global hotkey registration (OpenWhispr)
- Audio capture, VAD (OpenWhispr)
- whisper.cpp invocation (OpenWhispr)
- Paste-at-cursor (OpenWhispr)
- Menubar rendering (OpenWhispr, we only add menu items via a patch)
- Auto-update (electron-updater via upstream)

If upstream breaks one of these, we file an issue upstream before patching.
