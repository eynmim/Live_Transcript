import { describe, it, expect } from "vitest";
import { createRouter } from "../src/llm/router.js";
import type { TalktypeConfig } from "../src/types.js";

function baseConfig(): TalktypeConfig {
  return {
    mode: "local",
    hotkey: "Alt+Space",
    ollama: { host: "http://localhost:11434", model: "qwen2.5:3b" },
    anthropic: { apiKey: null, model: "claude-haiku-4-5-20251001" },
    perApp: {},
    panic: { enabled: false, audioBufferSeconds: 60, dumpDir: "/tmp/talktype" },
    logs: { dir: "/tmp/talktype-logs", level: "error" },
    telemetry: { optIn: false },
  };
}

const silentLogger = { warn: () => {}, info: () => {} };

describe("router mode selection", () => {
  it("uses global mode by default", () => {
    const r = createRouter(baseConfig(), silentLogger);
    expect(r.getMode("slack")).toBe("local");
  });

  it("respects per-app override", () => {
    const cfg = baseConfig();
    cfg.perApp = { vscode: "raw" };
    const r = createRouter(cfg, silentLogger);
    expect(r.getMode("vscode")).toBe("raw");
    expect(r.getMode("slack")).toBe("local");
  });

  it("setMode with no targetApp updates global", () => {
    const r = createRouter(baseConfig(), silentLogger);
    r.setMode("cloud");
    expect(r.getMode("slack")).toBe("cloud");
    expect(r.getMode("vscode")).toBe("cloud");
  });

  it("setMode with targetApp only updates that app", () => {
    const r = createRouter(baseConfig(), silentLogger);
    r.setMode("raw", "vscode");
    expect(r.getMode("vscode")).toBe("raw");
    expect(r.getMode("slack")).toBe("local");
  });
});
