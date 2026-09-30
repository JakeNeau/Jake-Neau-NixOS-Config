import assert from "node:assert/strict";
import test from "node:test";

import { registerTranscriptControls } from "../core.ts";

interface FakeContext {
  mode: "tui" | "rpc";
  hasUI: boolean;
  ui: {
    notify(message: string, type?: string): void;
    setMinimalTranscript?: (enabled: boolean) => void;
    setToolsExpanded(enabled: boolean): void;
    setWorkingMessage(message?: string): void;
  };
}

function loadExtension(measureWidth: (text: string) => number = (text) => text.length) {
  const shortcuts = new Map<string, { handler(ctx: FakeContext): void | Promise<void> }>();
  const handlers = new Map<string, Array<(event: unknown, ctx: FakeContext) => void | Promise<void>>>();
  const pi = {
    registerEntryRenderer() {},
    registerShortcut(key: string, definition: { handler(ctx: FakeContext): void | Promise<void> }) {
      shortcuts.set(key, definition);
    },
    on(event: string, handler: (event: unknown, ctx: FakeContext) => void | Promise<void>) {
      const registered = handlers.get(event) ?? [];
      registered.push(handler);
      handlers.set(event, registered);
    },
  };

  const previous = process.env.PI_MINIMAL_TRANSCRIPT;
  process.env.PI_MINIMAL_TRANSCRIPT = "1";
  try {
    registerTranscriptControls(pi, measureWidth);
  } finally {
    if (previous === undefined) delete process.env.PI_MINIMAL_TRANSCRIPT;
    else process.env.PI_MINIMAL_TRANSCRIPT = previous;
  }

  return { handlers, shortcuts };
}

function context(mode: "tui" | "rpc" = "tui") {
  const modes: boolean[] = [];
  const notifications: Array<{ message: string; type?: string }> = [];
  const expansions: boolean[] = [];
  const workingMessages: Array<string | undefined> = [];
  const ctx: FakeContext = {
    mode,
    hasUI: true,
    ui: {
      notify: (message, type) => notifications.push({ message, type }),
      setMinimalTranscript: (enabled) => modes.push(enabled),
      setToolsExpanded: (enabled) => expansions.push(enabled),
      setWorkingMessage: (message) => workingMessages.push(message),
    },
  };
  return { ctx, expansions, modes, notifications, workingMessages };
}

function assistantMessage(text?: string) {
  return {
    role: "assistant",
    content: [
      ...(text === undefined ? [] : [{ type: "text", text }]),
      { type: "toolCall", id: "call", name: "read", arguments: {} },
    ],
  };
}

test("registers Alt+T without the old collapse shortcut", () => {
  const { shortcuts } = loadExtension();
  assert.deepEqual([...shortcuts.keys()], ["alt+t"]);
});

test("toggles transcript modes and reports each selected mode", async () => {
  const { handlers, shortcuts } = loadExtension();
  const state = context();

  await handlers.get("session_start")![0]!({}, state.ctx);
  assert.deepEqual(state.modes, [true]);
  assert.deepEqual(state.expansions, [true]);

  await shortcuts.get("alt+t")!.handler(state.ctx);
  await shortcuts.get("alt+t")!.handler(state.ctx);

  assert.deepEqual(state.modes, [true, false, true]);
  assert.deepEqual(state.notifications, [
    { message: "Full transcript", type: "info" },
    { message: "Minimal transcript", type: "info" },
  ]);
});

test("resets resumed sessions to minimal mode", async () => {
  const { handlers, shortcuts } = loadExtension();
  const first = context();
  await handlers.get("session_start")![0]!({}, first.ctx);
  await shortcuts.get("alt+t")!.handler(first.ctx);

  const resumed = context();
  await handlers.get("session_start")![0]!({}, resumed.ctx);
  await shortcuts.get("alt+t")!.handler(resumed.ctx);

  assert.deepEqual(resumed.modes, [true, false]);
});

test("moves from thinking to writing and then uses the tool-batch progress line", async () => {
  const { handlers } = loadExtension();
  const state = context();

  await handlers.get("session_start")![0]!({}, state.ctx);
  await handlers.get("turn_start")![0]!({}, state.ctx);
  await handlers.get("message_update")![0]!({ message: { role: "assistant", content: [] } }, state.ctx);
  await handlers.get("message_update")![0]!({ message: assistantMessage("Tracing spinner behavior…") }, state.ctx);
  await handlers.get("tool_execution_start")![0]!({ toolCallId: "call", toolName: "read", args: {} }, state.ctx);

  assert.deepEqual(state.workingMessages, [undefined, "Thinking…", "Writing response…", "Tracing spinner behavior…"]);
});

test("uses the fallback for missing or invalid progress lines", async () => {
  const { handlers } = loadExtension();
  const state = context();

  await handlers.get("session_start")![0]!({}, state.ctx);
  await handlers.get("turn_start")![0]!({}, state.ctx);
  await handlers.get("tool_execution_start")![0]!({ toolCallId: "missing", toolName: "read", args: {} }, state.ctx);
  await handlers.get("turn_start")![0]!({}, state.ctx);
  await handlers.get("message_update")![0]!({ message: assistantMessage("First line\nSecond line") }, state.ctx);
  await handlers.get("tool_execution_start")![0]!({ toolCallId: "invalid", toolName: "read", args: {} }, state.ctx);

  assert.deepEqual(state.workingMessages, [
    undefined,
    "Thinking…",
    "Working…",
    "Thinking…",
    "Writing response…",
    "Working…",
  ]);
});

test("nested tool starts preserve the parent batch label", async () => {
  const { handlers } = loadExtension();
  const state = context();

  await handlers.get("session_start")![0]!({}, state.ctx);
  await handlers.get("turn_start")![0]!({}, state.ctx);
  await handlers.get("message_update")![0]!({ message: assistantMessage("Inspecting project files…") }, state.ctx);
  await handlers.get("tool_execution_start")![0]!({ toolCallId: "call", toolName: "read", args: {} }, state.ctx);
  const beforeNested = [...state.workingMessages];
  await handlers.get("tool_execution_start")![0]!(
    { toolCallId: "call/1", toolName: "grep", args: {}, parentToolCallId: "call" },
    state.ctx,
  );

  assert.deepEqual(state.workingMessages, beforeNested);
});

test("settlement restores Pi's default working message", async () => {
  const { handlers } = loadExtension();
  const state = context();

  await handlers.get("session_start")![0]!({}, state.ctx);
  await handlers.get("turn_start")![0]!({}, state.ctx);
  await handlers.get("agent_settled")![0]!({}, state.ctx);

  assert.deepEqual(state.workingMessages, [undefined, "Thinking…", undefined]);
});

test("mode changes immediately switch between default and current phase labels", async () => {
  for (const phase of ["thinking", "writing", "tool"] as const) {
    const { handlers, shortcuts } = loadExtension();
    const state = context();
    await handlers.get("session_start")![0]!({}, state.ctx);
    await handlers.get("turn_start")![0]!({}, state.ctx);

    let expected = "Thinking…";
    if (phase !== "thinking") {
      await handlers.get("message_update")![0]!({ message: assistantMessage("Checking the Pi package…") }, state.ctx);
      expected = "Writing response…";
    }
    if (phase === "tool") {
      await handlers.get("tool_execution_start")![0]!({ toolCallId: "call", toolName: "read", args: {} }, state.ctx);
      expected = "Checking the Pi package…";
    }

    await shortcuts.get("alt+t")!.handler(state.ctx);
    await shortcuts.get("alt+t")!.handler(state.ctx);
    assert.deepEqual(state.workingMessages.slice(-2), [undefined, expected]);
  }
});

test("leaves noninteractive modes unchanged", async () => {
  const { handlers } = loadExtension();
  const state = context("rpc");
  delete state.ctx.ui.setMinimalTranscript;

  await handlers.get("session_start")![0]!({}, state.ctx);
  await handlers.get("turn_start")![0]!({}, state.ctx);
  await handlers.get("message_update")![0]!({ message: assistantMessage("Inspecting project files…") }, state.ctx);
  await handlers.get("tool_execution_start")![0]!({ toolCallId: "call", toolName: "read", args: {} }, state.ctx);
  await handlers.get("agent_settled")![0]!({}, state.ctx);

  assert.deepEqual(state.modes, []);
  assert.deepEqual(state.workingMessages, []);
});

test("reports a missing patched UI contract without changing mode", async () => {
  const { handlers, shortcuts } = loadExtension();
  const state = context();
  delete state.ctx.ui.setMinimalTranscript;

  assert.throws(
    () => handlers.get("session_start")![0]!({}, state.ctx),
    /patched Pi transcript UI is unavailable/,
  );
  await shortcuts.get("alt+t")!.handler(state.ctx);

  assert.deepEqual(state.modes, []);
  assert.deepEqual(state.notifications, [
    { message: "Transcript toggle failed: patched Pi transcript UI is unavailable", type: "error" },
    { message: "Transcript toggle failed: patched Pi transcript UI is unavailable", type: "error" },
  ]);
});
