export type Mode = "local" | "cloud" | "raw";

export type TargetApp =
  | "slack"
  | "gmail"
  | "vscode"
  | "notion"
  | "messages"
  | "default";

export interface CleanupRequest {
  text: string;
  targetApp: TargetApp;
  mode: Mode;
}

export interface CleanupResult {
  text: string;
  providerUsed: "ollama" | "anthropic" | "raw";
  latencyMs: number;
}

export interface LlmProvider {
  readonly name: "ollama" | "anthropic";
  isAvailable(): Promise<boolean>;
  clean(req: CleanupRequest): Promise<string>;
}

export interface TalktypeConfig {
  mode: Mode;
  hotkey: string;
  ollama: {
    host: string;
    model: string;
  };
  anthropic: {
    apiKey: string | null;
    model: string;
  };
  perApp: Partial<Record<TargetApp, Mode>>;
  panic: {
    enabled: boolean;
    audioBufferSeconds: number;
    dumpDir: string;
  };
  logs: {
    dir: string;
    level: "debug" | "info" | "warn" | "error";
  };
  telemetry: {
    optIn: boolean;
  };
}

export interface HealthReport {
  ok: boolean;
  checks: Array<{
    name: string;
    ok: boolean;
    message: string;
    severity: "info" | "warn" | "error";
  }>;
}

export interface WrapperHooks {
  onCleanup(req: CleanupRequest): Promise<CleanupResult>;
  onStartup(): Promise<HealthReport>;
  onHotkey(): Promise<HealthReport>;
  setMode(mode: Mode, targetApp?: TargetApp): void;
  getMode(targetApp: TargetApp): Mode;
  panicDumpAudio(pcmBuffer: Buffer): Promise<string>;
  shutdown(): Promise<void>;
}
