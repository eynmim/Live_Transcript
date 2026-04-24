# Reliability

This doc is the contract for what talktype promises under failure. Every failure mode listed here must have: a category, a user-facing message, and an automatic fallback action. No silent failures.

## Invariants (always true)

1. **Never lose audio.** On unhandled error, the last N seconds (default 60) of raw PCM is written to `~/Library/Logs/talktype/panic/panic-<ts>.pcm`.
2. **Never block the user on a failing provider.** Cloud → local → raw ladder always resolves.
3. **Config fails loud, early.** Invalid config aborts launch with the zod error path printed.
4. **Health is re-checked on every hotkey press**, not only at startup.
5. **Privacy defaults are on**: no audio persisted after STT, no cloud by default, no telemetry by default.

## Error taxonomy

Defined in [`wrapper/src/reliability/errors.ts`](../wrapper/src/reliability/errors.ts).

| Category | User-facing message | Fallback |
|---|---|---|
| `CONFIG_UNREADABLE` | talktype could not read its config file. | abort |
| `CONFIG_INVALID` | talktype config is invalid. Fix or delete to regenerate. | abort |
| `OLLAMA_UNREACHABLE` | Ollama at {host} did not respond. | fallback_raw |
| `OLLAMA_MODEL_MISSING` | Model {m} missing — run `ollama pull {m}`. | notify_user |
| `ANTHROPIC_NO_KEY` | No Anthropic API key configured. | fallback_local |
| `ANTHROPIC_HTTP_ERROR` | Anthropic request failed. | fallback_local |
| `ANTHROPIC_RATE_LIMITED` | Anthropic rate-limited us — falling back to local. | fallback_local |
| `STT_FAILED` | whisper.cpp could not transcribe the audio. | notify_user |
| `MIC_PERMISSION_DENIED` | talktype needs microphone permission. | notify_user (deep-link Settings) |
| `ACCESSIBILITY_PERMISSION_DENIED` | talktype needs Accessibility permission to paste at cursor. | notify_user |
| `HOTKEY_REGISTRATION_FAILED` | Another app may be holding {hotkey}. | notify_user |
| `NETWORK_OFFLINE` | Offline — cloud mode unavailable. | fallback_local |
| `PANIC_DUMP_FAILED` | Emergency audio dump failed. | log and continue |
| `UNKNOWN` | Something went wrong. Check the logs. | notify_user |

## Fallback ladder

Implemented in [`wrapper/src/reliability/fallback.ts`](../wrapper/src/reliability/fallback.ts).

```
cloud mode:  anthropic → ollama → raw
local mode:  ollama → raw
raw mode:    raw
```

A provider is skipped if `isAvailable()` returns false, or if `clean()` throws. Every skip is logged. Final raw step *always* succeeds (it just returns the input).

## Health probes

Run at startup and on every hotkey press. Implemented in [`wrapper/src/reliability/health.ts`](../wrapper/src/reliability/health.ts).

- **ollama** — HTTP GET `/api/tags` with 2 s timeout
- **ollama-model** — checks the configured model is actually in `/api/tags`
- **anthropic-key** — presence + `sk-ant-` prefix check
- **network** — HEAD to `api.anthropic.com` with 2 s timeout
- **mic permission** — (Electron-side) checks `systemPreferences.getMediaAccessStatus('microphone')`
- **accessibility permission** — (Electron-side) checks `systemPreferences.isTrustedAccessibilityClient(false)` on macOS

If `ok=false && severity=error` → banner shown + auto-switch mode if possible.

## Logs

- Location: `~/Library/Logs/talktype/talktype-YYYY-MM-DD.log.jsonl`
- Format: newline-delimited JSON, one event per line
- Rotation: daily (new filename each day)
- Retention: user-managed (we don't auto-delete; it's their machine)
- Levels: debug / info / warn / error (configurable in `config.logs.level`)

Sensitive fields (audio bytes, full transcripts in cloud mode, API keys) are **never** written to logs.

## Observability (opt-in)

```bash
docker compose -f docker/docker-compose.yml --profile observability up -d
```

Starts Loki + Grafana locally. A log shipper (promtail or Vector) is configured to tail `~/Library/Logs/talktype/` and push to Loki. Grafana dashboard (shipped at `docker/grafana-data/provisioning/` — TODO) visualizes transcription latency, error rate by category, mode usage.

Anonymous on localhost only. No cloud.

## Panic audio

If any uncaught exception escapes the main process, a shutdown hook:

1. Flushes the rolling 60 s PCM ring buffer to `~/Library/Logs/talktype/panic/panic-<iso-ts>.pcm`.
2. Writes a sibling `panic-<iso-ts>.json` with the error + stack + app state snapshot.
3. Logs `panic.audio_dumped`.
4. Exits with code 1.

You can play back the PCM with `ffplay -f s16le -ar 16000 -ac 1 panic-*.pcm` (assuming whisper.cpp's 16 kHz mono). The goal is: if talktype dies mid-thought, your thought is still on disk.

## Testing reliability

- `wrapper/tests/fallback.test.ts` — ladder transitions including double-failure to raw.
- `wrapper/tests/router.test.ts` — per-app overrides and mode changes.
- `wrapper/tests/prompts.test.ts` — style hints reach the right target.
- Future: Playwright E2E in `app/` that kills Ollama mid-session and asserts the fallback banner appears.
