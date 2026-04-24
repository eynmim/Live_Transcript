import { writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import type {
  CleanupRequest,
  HealthReport,
  Mode,
  TalktypeConfig,
  TargetApp,
  WrapperHooks,
} from "./types.js";
import { createRouter } from "./llm/router.js";
import { runHealthProbes } from "./reliability/health.js";
import { createLogger } from "./telemetry/logger.js";
import { runPostTranscript } from "./hooks/post-transcript.js";

export function createWrapper(config: TalktypeConfig): WrapperHooks {
  const logger = createLogger({
    dir: config.logs.dir,
    level: config.logs.level,
    alsoConsole: process.env.NODE_ENV !== "production",
  });
  const router = createRouter(config, logger);

  return {
    async onStartup() {
      logger.info("wrapper.startup", { mode: config.mode });
      const report = await runHealthProbes(config);
      for (const c of report.checks) {
        logger[c.ok ? "info" : c.severity === "error" ? "error" : "warn"](
          `health.${c.name}`,
          { ok: c.ok, message: c.message },
        );
      }
      return report;
    },

    async onHotkey() {
      return runHealthProbes(config);
    },

    async onCleanup(req: CleanupRequest) {
      const result = await router.clean({ text: req.text, targetApp: req.targetApp });
      logger.info("cleanup.done", {
        provider: result.providerUsed,
        latencyMs: result.latencyMs,
        targetApp: req.targetApp,
      });
      await runPostTranscript({
        targetApp: req.targetApp,
        timestamp: new Date().toISOString(),
        result,
      });
      return result;
    },

    setMode(mode: Mode, targetApp?: TargetApp) {
      router.setMode(mode, targetApp);
      logger.info("mode.changed", { mode, targetApp: targetApp ?? "global" });
    },

    getMode(targetApp: TargetApp) {
      return router.getMode(targetApp);
    },

    async panicDumpAudio(pcmBuffer: Buffer) {
      if (!config.panic.enabled) return "";
      await mkdir(config.panic.dumpDir, { recursive: true });
      const path = join(
        config.panic.dumpDir,
        `panic-${new Date().toISOString().replace(/[:.]/g, "-")}.pcm`,
      );
      await writeFile(path, pcmBuffer);
      logger.error("panic.audio_dumped", { path, bytes: pcmBuffer.length });
      return path;
    },

    async shutdown() {
      logger.info("wrapper.shutdown");
      logger.close();
    },
  };

  // satisfy unused-report warning if onStartup never touched
  void ((): HealthReport | null => null)();
}
