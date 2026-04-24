import type { CleanupRequest, TargetApp } from "../types.js";

const BASE_SYSTEM = `You are a dictation cleanup model. Rewrite the user's raw spoken transcription as polished written text.

Rules:
- Remove filler words: um, uh, like, you know, sort of, kind of.
- Fix backtracking: "meet Tuesday wait Wednesday" → "meet Wednesday".
- Add correct punctuation and capitalization.
- Keep the user's meaning and voice. Do not add new content.
- Do not add salutations, sign-offs, or explanations.
- Output only the cleaned text, no preamble, no markdown fences.`;

const STYLE_HINTS: Record<TargetApp, string> = {
  slack: "Target app: Slack. Tone: casual, short sentences, contractions OK.",
  gmail: "Target app: Gmail. Tone: professional but natural. No filler.",
  vscode:
    "Target app: VS Code. This may be a code comment, a variable name description, or prose. If the dictation describes code symbols, keep them verbatim. Minimal punctuation inside fenced code.",
  notion: "Target app: Notion. Tone: clear, structured. Use bullet points only if the user explicitly dictates a list.",
  messages: "Target app: Messages/iMessage. Tone: conversational, brief.",
  default: "Target app: generic. Tone: clear written prose.",
};

export function buildCleanupPrompt(req: CleanupRequest): {
  system: string;
  user: string;
} {
  const styleHint = STYLE_HINTS[req.targetApp] ?? STYLE_HINTS.default;
  return {
    system: `${BASE_SYSTEM}\n\n${styleHint}`,
    user: req.text,
  };
}
