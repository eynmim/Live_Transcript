import type { CleanupResult } from "../types.js";

export interface PostTranscriptContext {
  targetApp: string;
  timestamp: string;
  result: CleanupResult;
}

export type PostTranscriptHandler = (ctx: PostTranscriptContext) => Promise<void>;

const handlers: PostTranscriptHandler[] = [];

export function registerPostTranscript(handler: PostTranscriptHandler): () => void {
  handlers.push(handler);
  return () => {
    const i = handlers.indexOf(handler);
    if (i >= 0) handlers.splice(i, 1);
  };
}

export async function runPostTranscript(ctx: PostTranscriptContext): Promise<void> {
  await Promise.allSettled(handlers.map((h) => h(ctx)));
}
