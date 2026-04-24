import type { CleanupRequest, LlmProvider, TalktypeConfig } from "../types.js";
import { buildCleanupPrompt } from "../prompts/index.js";
import { WrapperError } from "../reliability/errors.js";

export function createOllamaProvider(
  config: Pick<TalktypeConfig, "ollama">,
): LlmProvider {
  const { host, model } = config.ollama;

  return {
    name: "ollama",

    async isAvailable() {
      try {
        const res = await fetch(`${host}/api/tags`, {
          signal: AbortSignal.timeout(1500),
        });
        return res.ok;
      } catch {
        return false;
      }
    },

    async clean(req: CleanupRequest) {
      const { system, user } = buildCleanupPrompt(req);
      let res: Response;
      try {
        res = await fetch(`${host}/api/chat`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          signal: AbortSignal.timeout(15_000),
          body: JSON.stringify({
            model,
            stream: false,
            messages: [
              { role: "system", content: system },
              { role: "user", content: user },
            ],
            options: { temperature: 0.2 },
          }),
        });
      } catch (e) {
        throw new WrapperError("OLLAMA_UNREACHABLE", {
          userMessage: `Ollama at ${host} did not respond.`,
          cause: e,
          fallback: "fallback_raw",
        });
      }

      if (!res.ok) {
        if (res.status === 404) {
          throw new WrapperError("OLLAMA_MODEL_MISSING", {
            userMessage: `Ollama model '${model}' is not pulled. Run: ollama pull ${model}`,
            fallback: "notify_user",
          });
        }
        throw new WrapperError("OLLAMA_UNREACHABLE", {
          userMessage: `Ollama returned HTTP ${res.status}.`,
          fallback: "fallback_raw",
        });
      }

      const data = (await res.json()) as { message?: { content?: string } };
      const text = data.message?.content?.trim();
      if (!text) {
        throw new WrapperError("OLLAMA_UNREACHABLE", {
          userMessage: "Ollama returned empty content.",
          fallback: "fallback_raw",
        });
      }
      return text;
    },
  };
}
