import { describe, expect, it, vi } from "vitest";
import "./test-helpers/fast-core-tools.js";

const messageToolFactory = vi.hoisted(() => ({
  createMessageTool: vi.fn(() => ({
    label: "Message",
    name: "message",
    description: "mock",
    parameters: { type: "object", properties: {} },
    execute: vi.fn(async () => ({ content: [{ type: "text", text: "ok" }] })),
  })),
}));

vi.mock("./tools/message-tool.js", () => messageToolFactory);

import { createOpenClawTools } from "./openclaw-tools.js";

describe("openclaw-tools message target fallback", () => {
  it("passes agentTo as currentChannelId fallback to message tool", () => {
    createOpenClawTools({
      agentChannel: "telegram",
      agentTo: "telegram:496165509",
    });

    expect(messageToolFactory.createMessageTool).toHaveBeenCalledWith(
      expect.objectContaining({
        currentChannelId: "telegram:496165509",
        currentChannelProvider: "telegram",
      }),
    );
  });
});
