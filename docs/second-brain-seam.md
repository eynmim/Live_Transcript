# Second Brain seam (Phase 2 preview)

This doc describes where the Second Brain capture integration plugs in — and what we deliberately haven't done yet. Goal: keep talktype standalone now, but leave a single clean extension point so Phase 2 is a small diff.

## The seam

[`wrapper/src/hooks/post-transcript.ts`](../wrapper/src/hooks/post-transcript.ts) exposes:

```ts
registerPostTranscript((ctx: PostTranscriptContext) => Promise<void>)
```

`runPostTranscript(ctx)` is called by the wrapper after every successful cleanup. All registered handlers run in parallel (`Promise.allSettled`) so one slow or failing handler can't block the paste step.

## Why a hook, not a direct import

- We don't want the Second Brain vault path, tag schema, or routing logic hard-coded into talktype. Those change.
- We don't want talktype to refuse to run when the Second Brain vault is missing.
- We *do* want talktype to work as a standalone dictation tool for anyone.

A hook registry lets us:

- Ship talktype with no Second Brain dependency in v1.
- Add `wrapper/src/hooks/capture-to-second-brain.ts` in Phase 2 without touching `app/` or the router.
- Unregister / swap handlers at runtime (useful for testing).

## What Phase 2 will likely do

Two candidate integrations (decision deferred):

### Option A — direct file write
Handler writes a timestamped markdown file into the 2Brain vault:

```
~/Downloads/mosaleh-2Brain/vault/inbox/2026-04-21T14-22-01-slack.md
```

With front-matter: timestamp, target app, provider used, mode. Body: cleaned text.

Pros: zero runtime dependency, offline, Git-friendly.
Cons: no categorization into the 4-layer architecture (Being/Having/Roles/Becoming).

### Option B — pipe through Claude Code / MCP
Handler POSTs the cleaned text to a local MCP endpoint (OpenWhispr already ships one). A Claude Code session subscribed to that endpoint classifies the note into the 4-layer architecture and writes it to the right vault subfolder with auto-tagging.

Pros: auto-categorization, aligns with QAF framework in memory.
Cons: requires Claude Code running, latency, cost.

Probably: **ship Option A always**, add Option B as an opt-in toggle.

## Invariants to preserve

Whichever option, these stay true:

1. Handler errors never block the paste step (handled by `Promise.allSettled`).
2. Handler gets the *cleaned* text, not the raw audio. Audio stays ephemeral.
3. Handler is opt-in — a fresh talktype install with no vault configured is a silent no-op.
4. Handler has a 5-second timeout enforced by the wrapper (TODO when Phase 2 lands).

## Out of scope for v1

- Any Second Brain vault path discovery or creation.
- Any tagging / categorization logic.
- Any MCP server code (OpenWhispr already has one; we'd subscribe, not host).
- Any vault-side UI.

## When Phase 2 starts

Checklist:

- [ ] Decide Option A vs A+B.
- [ ] Add `wrapper/src/hooks/capture-to-second-brain.ts` with the handler.
- [ ] Add `secondBrain: { enabled, vaultPath }` to the config schema.
- [ ] Register the handler in `wrapper.ts` when enabled.
- [ ] Add a menubar toggle "Capture to Second Brain".
- [ ] Add an E2E test that dictation → file exists in vault.
- [ ] Update this doc to reflect what shipped.
