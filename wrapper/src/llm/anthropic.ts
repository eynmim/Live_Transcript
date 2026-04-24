import Anthropic from "@anthropic-ai/sdk";
import type { CleanupRequest, LlmProvider, TalktypeConfig } from "../types.js";
import { buildCleanupPrompt } from "../prompts/index.js";
import { WrapperError } from "../reliability/errors.js";

export function createAnthropicProvider(
  config: Pick<TalktypeConfig, "anthropic">,
): LlmProvider {
  const { apiKey, model } = config.anthropic;
  const client = apiKey ? new Anthropic({ apiKey }) : null;

  return {
    name: "anthropic",

    async isAvailable() {
      return client !== null;
    },

    async clean(req: CleanupRequest) {
      if (!client) {
        throw new WrapperError("ANTHROPIC_NO_KEY", {
          userMessage: "No Anthropic API key configured.",
          fallback: "fallback_local",
        });
      }

      const { system, user } = buildCleanupPrompt(req);

      try {
        const res = await client.messages.create({
          model,
          max_tokens: 1024,
          system: [
            {
              type: "text",
              text: system,
              cache_control: { type: "ephemeral" },
            },
          ],
          messages: [{ role: "user", content: user }],
        });

        const block = res.content[0];
        if (!block || block.type !== "text") {
          throw new WrapperError("ANTHROPIC_HTTP_ERROR", {
            userMessage: "Anthropic returned a non-text block.",
            fallback: "fallback_local",
          });
        }
        return block.text.trim();
      } catch (e: unknown) {
        if (e instanceof WrapperError) throw e;
        const err = e as { status?: number; message?: string };
        if (err.status === 429) {
          throw new WrapperError("ANTHROPIC_RATE_LIMITED", {
            userMessage: "Anthropic rate-limited us — falling back to local.",
            cause: e,
            fallback: "fallback_local",
          });
        }
        throw new WrapperError("ANTHROPIC_HTTP_ERROR", {
          userMessage: err.message ?? "Anthropic request failed.",
          cause: e,
          fallback: "fallback_local",
        });
      }
    },
  };
}
