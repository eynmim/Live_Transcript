import { createWriteStream, existsSync, mkdirSync, type WriteStream } from "node:fs";
import { join } from "node:path";

export type Level = "debug" | "info" | "warn" | "error";

const LEVEL_RANK: Record<Level, number> = { debug: 0, info: 1, warn: 2, error: 3 };

export interface Logger {
  debug(msg: string, meta?: Record<string, unknown>): void;
  info(msg: string, meta?: Record<string, unknown>): void;
  warn(msg: string, meta?: Record<string, unknown>): void;
  error(msg: string, meta?: Record<string, unknown>): void;
  close(): void;
}

function dateStamp(): string {
  return new Date().toISOString().slice(0, 10);
}

export function createLogger(opts: {
  dir: string;
  level: Level;
  alsoConsole?: boolean;
}): Logger {
  if (!existsSync(opts.dir)) mkdirSync(opts.dir, { recursive: true });
  const path = join(opts.dir, `talktype-${dateStamp()}.log.jsonl`);
  const stream: WriteStream = createWriteStream(path, { flags: "a" });
  const threshold = LEVEL_RANK[opts.level];

  function write(level: Level, msg: string, meta?: Record<string, unknown>): void {
    if (LEVEL_RANK[level] < threshold) return;
    const line =
      JSON.stringify({
        ts: new Date().toISOString(),
        level,
        msg,
        ...(meta ?? {}),
      }) + "\n";
    stream.write(line);
    if (opts.alsoConsole) {
      const fn = level === "error" ? console.error : level === "warn" ? console.warn : console.log;
      fn(`[${level}] ${msg}`, meta ?? "");
    }
  }

  return {
    debug: (m, meta) => write("debug", m, meta),
    info: (m, meta) => write("info", m, meta),
    warn: (m, meta) => write("warn", m, meta),
    error: (m, meta) => write("error", m, meta),
    close: () => stream.end(),
  };
}
