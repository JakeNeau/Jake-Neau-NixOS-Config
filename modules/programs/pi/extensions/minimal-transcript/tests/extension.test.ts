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
  };
}

function loadExtension() {
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
    registerTranscriptControls(pi);
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
  const ctx: FakeContext = {
    mode,
    hasUI: true,
    ui: {
      notify: (message, type) => notifications.push({ message, type }),
      setMinimalTranscript: (enabled) => modes.push(enabled),
      setToolsExpanded: (enabled) => expansions.push(enabled),
    },
  };
  return { ctx, expansions, modes, notifications };
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

test("leaves noninteractive modes unchanged", async () => {
  const { handlers } = loadExtension();
  const state = context("rpc");
  delete state.ctx.ui.setMinimalTranscript;

  await handlers.get("session_start")![0]!({}, state.ctx);
  assert.deepEqual(state.modes, []);
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
