import type {
  CleanupRequest,
  CleanupResult,
  Mode,
  TalktypeConfig,
  TargetApp,
} from "../types.js";
import { cleanupWithFallback, type FallbackDeps } from "../reliability/fallback.js";
import { createOllamaProvider } from "./ollama.js";
import { createAnthropicProvider } from "./anthropic.js";

export interface Router {
  clean(req: Omit<CleanupRequest, "mode">): Promise<CleanupResult>;
  setMode(mode: Mode, targetApp?: TargetApp): void;
  getMode(targetApp: TargetApp): Mode;
}

export function createRouter(
  config: TalktypeConfig,
  logger: FallbackDeps["logger"],
): Router {
  const providers = {
    ollama: createOllamaProvider(config),
    anthropic: createAnthropicProvider(config),
  };

  const perApp = new Map<TargetApp, Mode>(
    Object.entries(config.perApp) as Array<[TargetApp, Mode]>,
  );
  let globalMode: Mode = config.mode;

  return {
    async clean(req) {
      const mode = perApp.get(req.targetApp) ?? globalMode;
      return cleanupWithFallback({ ...req, mode }, { providers, logger });
    },
    setMode(mode, targetApp) {
      if (targetApp) perApp.set(targetApp, mode);
      else globalMode = mode;
    },
    getMode(targetApp) {
      return perApp.get(targetApp) ?? globalMode;
    },
  };
}
