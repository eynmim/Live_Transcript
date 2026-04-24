export type ErrorCategory =
  | "CONFIG_UNREADABLE"
  | "CONFIG_INVALID"
  | "OLLAMA_UNREACHABLE"
  | "OLLAMA_MODEL_MISSING"
  | "ANTHROPIC_NO_KEY"
  | "ANTHROPIC_HTTP_ERROR"
  | "ANTHROPIC_RATE_LIMITED"
  | "STT_FAILED"
  | "MIC_PERMISSION_DENIED"
  | "ACCESSIBILITY_PERMISSION_DENIED"
  | "HOTKEY_REGISTRATION_FAILED"
  | "NETWORK_OFFLINE"
  | "PANIC_DUMP_FAILED"
  | "UNKNOWN";

export type FallbackAction =
  | "abort"           // nothing we can do, refuse to start / surface to user
  | "fallback_local"  // cloud → local LLM
  | "fallback_raw"    // LLM → raw transcription
  | "retry"           // transient, worth a retry
  | "notify_user";    // permission / config issue, user must act

export interface WrapperErrorOptions {
  userMessage: string;
  fallback: FallbackAction;
  cause?: unknown;
  details?: Record<string, unknown>;
}

export class WrapperError extends Error {
  public readonly category: ErrorCategory;
  public readonly userMessage: string;
  public readonly fallback: FallbackAction;
  public readonly details: Record<string, unknown>;
  public readonly cause?: unknown;

  constructor(category: ErrorCategory, opts: WrapperErrorOptions) {
    super(`[${category}] ${opts.userMessage}`);
    this.name = "WrapperError";
    this.category = category;
    this.userMessage = opts.userMessage;
    this.fallback = opts.fallback;
    this.details = opts.details ?? {};
    this.cause = opts.cause;
  }
}

export function isWrapperError(e: unknown): e is WrapperError {
  return e instanceof WrapperError;
}
