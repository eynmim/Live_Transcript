import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname } from "node:path";
import { homedir } from "node:os";
import { join } from "node:path";
import { configSchema } from "./schema.js";
import type { TalktypeConfig } from "../types.js";
import { WrapperError } from "../reliability/errors.js";

export const DEFAULT_CONFIG_PATH = join(
  homedir(),
  "Library",
  "Application Support",
  "talktype",
  "config.json",
);

const DEFAULT_LOG_DIR = join(homedir(), "Library", "Logs", "talktype");
const DEFAULT_PANIC_DIR = join(DEFAULT_LOG_DIR, "panic");

function platformDefaults(): Pick<TalktypeConfig, "panic" | "logs"> {
  return {
    panic: {
      enabled: true,
      audioBufferSeconds: 60,
      dumpDir: DEFAULT_PANIC_DIR,
    },
    logs: {
      dir: DEFAULT_LOG_DIR,
      level: "info",
    },
  };
}

export async function loadConfig(
  path: string = DEFAULT_CONFIG_PATH,
): Promise<TalktypeConfig> {
  let raw: unknown;
  try {
    const text = await readFile(path, "utf-8");
    raw = JSON.parse(text);
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") {
      const defaults = configSchema.parse(platformDefaults());
      await saveConfig(defaults, path);
      return defaults;
    }
    throw new WrapperError("CONFIG_UNREADABLE", {
      userMessage: "talktype could not read its config file.",
      cause: err,
      fallback: "abort",
      details: { path },
    });
  }

  const parsed = configSchema.safeParse({
    ...platformDefaults(),
    ...(raw as object),
  });
  if (!parsed.success) {
    throw new WrapperError("CONFIG_INVALID", {
      userMessage:
        "talktype config is invalid. See the issue path printed above and fix it, or delete the file to regenerate defaults.",
      fallback: "abort",
      details: { issues: parsed.error.issues, path },
    });
  }
  return parsed.data;
}

export async function saveConfig(
  config: TalktypeConfig,
  path: string = DEFAULT_CONFIG_PATH,
): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, JSON.stringify(config, null, 2), "utf-8");
}
