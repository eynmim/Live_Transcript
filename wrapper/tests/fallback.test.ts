import { describe, it, expect, vi } from "vitest";
import { cleanupWithFallback } from "../src/reliability/fallback.js";
import type { LlmProvider } from "../src/types.js";

function mockProvider(
  name: "ollama" | "anthropic",
  opts: { available: boolean; result?: string; throws?: Error },
): LlmProvider {
  return {
    name,
    isAvailable: vi.fn(async () => opts.available),
    clean: vi.fn(async () => {
      if (opts.throws) throw opts.throws;
      return opts.result ?? "CLEANED";
    }),
  };
}

const silentLogger = { warn: vi.fn(), info: vi.fn() };

describe("cleanupWithFallback", () => {
  it("uses anthropic in cloud mode when available", async () => {
    const res = await cleanupWithFallback(
      { text: "hi", targetApp: "default", mode: "cloud" },
      {
        providers: {
          anthropic: mockProvider("anthropic", { available: true, result: "CLOUD" }),
          ollama: mockProvider("ollama", { available: true, result: "LOCAL" }),
        },
        logger: silentLogger,
      },
    );
    expect(res.providerUsed).toBe("anthropic");
    expect(res.text).toBe("CLOUD");
  });

  it("falls back cloud → local when anthropic unavailable", async () => {
    const res = await cleanupWithFallback(
      { text: "hi", targetApp: "default", mode: "cloud" },
      {
        providers: {
          anthropic: mockProvider("anthropic", { available: false }),
          ollama: mockProvider("ollama", { available: true, result: "LOCAL" }),
        },
        logger: silentLogger,
      },
    );
    expect(res.providerUsed).toBe("ollama");
    expect(res.text).toBe("LOCAL");
  });

  it("falls back cloud → local → raw when both fail", async () => {
    const res = await cleanupWithFallback(
      { text: "RAW_INPUT", targetApp: "default", mode: "cloud" },
      {
        providers: {
          anthropic: mockProvider("anthropic", { available: true, throws: new Error("boom") }),
          ollama: mockProvider("ollama", { available: true, throws: new Error("boom2") }),
        },
        logger: silentLogger,
      },
    );
    expect(res.providerUsed).toBe("raw");
    expect(res.text).toBe("RAW_INPUT");
  });

  it("in local mode, never reaches for anthropic", async () => {
    const anthropic = mockProvider("anthropic", { available: true, result: "CLOUD" });
    const res = await cleanupWithFallback(
      { text: "hi", targetApp: "default", mode: "local" },
      {
        providers: {
          anthropic,
          ollama: mockProvider("ollama", { available: true, result: "LOCAL" }),
        },
        logger: silentLogger,
      },
    );
    expect(res.providerUsed).toBe("ollama");
    expect(anthropic.clean).not.toHaveBeenCalled();
  });

  it("raw mode skips all providers", async () => {
    const anthropic = mockProvider("anthropic", { available: true, result: "CLOUD" });
    const ollama = mockProvider("ollama", { available: true, result: "LOCAL" });
    const res = await cleanupWithFallback(
      { text: "unchanged um text", targetApp: "default", mode: "raw" },
      { providers: { anthropic, ollama }, logger: silentLogger },
    );
    expect(res.providerUsed).toBe("raw");
    expect(res.text).toBe("unchanged um text");
    expect(anthropic.clean).not.toHaveBeenCalled();
    expect(ollama.clean).not.toHaveBeenCalled();
  });
});
