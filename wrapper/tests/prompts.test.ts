import { describe, it, expect } from "vitest";
import { buildCleanupPrompt } from "../src/prompts/index.js";

describe("buildCleanupPrompt", () => {
  it("includes the Slack style hint for slack", () => {
    const { system } = buildCleanupPrompt({
      text: "hey",
      targetApp: "slack",
      mode: "local",
    });
    expect(system).toMatch(/Slack/);
    expect(system).toMatch(/casual/);
  });

  it("includes VS Code hint with code awareness", () => {
    const { system } = buildCleanupPrompt({
      text: "hey",
      targetApp: "vscode",
      mode: "local",
    });
    expect(system).toMatch(/VS Code/);
    expect(system).toMatch(/code/i);
  });

  it("falls through to default hint for unknown", () => {
    const { system } = buildCleanupPrompt({
      text: "hey",
      targetApp: "default",
      mode: "local",
    });
    expect(system).toMatch(/generic/);
  });

  it("passes raw text to user prompt verbatim", () => {
    const { user } = buildCleanupPrompt({
      text: "um so like i was thinking",
      targetApp: "default",
      mode: "local",
    });
    expect(user).toBe("um so like i was thinking");
  });
});
