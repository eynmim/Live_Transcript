import type { TalktypeConfig, HealthReport } from "../types.js";

async function probeOllama(host: string): Promise<HealthReport["checks"][number]> {
  try {
    const res = await fetch(`${host}/api/tags`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!res.ok) {
      return {
        name: "ollama",
        ok: false,
        message: `Ollama at ${host} responded ${res.status}.`,
        severity: "error",
      };
    }
    return { name: "ollama", ok: true, message: "reachable", severity: "info" };
  } catch (e) {
    return {
      name: "ollama",
      ok: false,
      message: `Ollama at ${host} unreachable — run 'ollama serve' or 'docker compose up -d ollama'.`,
      severity: "error",
    };
  }
}

async function probeOllamaModel(
  host: string,
  model: string,
): Promise<HealthReport["checks"][number]> {
  try {
    const res = await fetch(`${host}/api/tags`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!res.ok) {
      return { name: "ollama-model", ok: false, message: "tags endpoint failed", severity: "warn" };
    }
    const data = (await res.json()) as { models?: Array<{ name: string }> };
    const has = (data.models ?? []).some((m) => m.name === model || m.name.startsWith(`${model}:`));
    return {
      name: "ollama-model",
      ok: has,
      message: has ? `${model} installed` : `Model ${model} missing — run 'ollama pull ${model}'.`,
      severity: has ? "info" : "error",
    };
  } catch {
    return { name: "ollama-model", ok: false, message: "could not enumerate models", severity: "warn" };
  }
}

function probeAnthropicKey(apiKey: string | null): HealthReport["checks"][number] {
  if (!apiKey) {
    return {
      name: "anthropic-key",
      ok: false,
      message: "No Anthropic API key — cloud mode will fall back to local.",
      severity: "info",
    };
  }
  if (!apiKey.startsWith("sk-ant-")) {
    return {
      name: "anthropic-key",
      ok: false,
      message: "Anthropic key is present but malformed.",
      severity: "warn",
    };
  }
  return { name: "anthropic-key", ok: true, message: "present", severity: "info" };
}

async function probeNetwork(): Promise<HealthReport["checks"][number]> {
  try {
    await fetch("https://api.anthropic.com/v1/messages", {
      method: "HEAD",
      signal: AbortSignal.timeout(2000),
    });
    return { name: "network", ok: true, message: "online", severity: "info" };
  } catch {
    return {
      name: "network",
      ok: false,
      message: "Offline — cloud mode unavailable.",
      severity: "info",
    };
  }
}

export async function runHealthProbes(config: TalktypeConfig): Promise<HealthReport> {
  const checks = await Promise.all([
    probeOllama(config.ollama.host),
    probeOllamaModel(config.ollama.host, config.ollama.model),
    Promise.resolve(probeAnthropicKey(config.anthropic.apiKey)),
    probeNetwork(),
  ]);

  const hasError = checks.some((c) => !c.ok && c.severity === "error");
  return { ok: !hasError, checks };
}
