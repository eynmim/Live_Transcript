import { z } from "zod";

export const modeSchema = z.enum(["local", "cloud", "raw"]);

export const targetAppSchema = z.enum([
  "slack",
  "gmail",
  "vscode",
  "notion",
  "messages",
  "default",
]);

export const configSchema = z.object({
  mode: modeSchema.default("local"),
  hotkey: z.string().min(1).default("Alt+Space"),
  ollama: z.object({
    host: z.string().url().default("http://localhost:11434"),
    model: z.string().min(1).default("qwen2.5:3b"),
  }),
  anthropic: z.object({
    apiKey: z.string().nullable().default(null),
    model: z.string().min(1).default("claude-haiku-4-5-20251001"),
  }),
  perApp: z.record(targetAppSchema, modeSchema).default({}),
  panic: z.object({
    enabled: z.boolean().default(true),
    audioBufferSeconds: z.number().int().positive().max(300).default(60),
    dumpDir: z.string().min(1),
  }),
  logs: z.object({
    dir: z.string().min(1),
    level: z.enum(["debug", "info", "warn", "error"]).default("info"),
  }),
  telemetry: z.object({
    optIn: z.boolean().default(false),
  }),
});

export type ConfigInput = z.input<typeof configSchema>;
