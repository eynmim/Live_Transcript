import type { CleanupRequest, CleanupResult, LlmProvider, Mode } from "../types.js";
import { WrapperError } from "./errors.js";

export interface FallbackDeps {
  providers: {
    anthropic: LlmProvider;
    ollama: LlmProvider;
  };
  logger: {
    warn(msg: string, meta?: Record<string, unknown>): void;
    info(msg: string, meta?: Record<string, unknown>): void;
  };
}

function ladderFor(mode: Mode): Array<"anthropic" | "ollama" | "raw"> {
  switch (mode) {
    case "cloud":
      return ["anthropic", "ollama", "raw"];
    case "local":
      return ["ollama", "raw"];
    case "raw":
      return ["raw"];
  }
}

export async function cleanupWithFallback(
  req: CleanupRequest,
  deps: FallbackDeps,
): Promise<CleanupResult> {
  const ladder = ladderFor(req.mode);
  const started = Date.now();
  let lastError: unknown;

  for (const step of ladder) {
    if (step === "raw") {
      deps.logger.info("fallback.raw", { targetApp: req.targetApp });
      return {
        text: req.text,
        providerUsed: "raw",
        latencyMs: Date.now() - started,
      };
    }

    const provider = deps.providers[step];
    try {
      if (!(await provider.isAvailable())) {
        deps.logger.warn("fallback.provider_unavailable", { provider: step });
        continue;
      }
      const cleaned = await provider.clean(req);
      return {
        text: cleaned,
        providerUsed: step,
        latencyMs: Date.now() - started,
      };
    } catch (e) {
      lastError = e;
      deps.logger.warn("fallback.provider_errored", {
        provider: step,
        error: e instanceof Error ? e.message : String(e),
      });
      continue;
    }
  }

  throw new WrapperError("UNKNOWN", {
    userMessage: "All cleanup paths failed. Raw transcription was also unavailable.",
    fallback: "notify_user",
    cause: lastError,
  });
}
