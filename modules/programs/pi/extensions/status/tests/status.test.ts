import assert from "node:assert/strict";
import test from "node:test";

import registerStatus from "../index.ts";

function loadExtension() {
  const commands = new Map<string, { handler(args: string, ctx: unknown): Promise<void> }>();
  const sent: Array<{ content: string; options?: { expandPromptTemplates?: boolean } }> = [];
  const pi = {
    registerCommand(name: string, definition: { handler(args: string, ctx: unknown): Promise<void> }) {
      commands.set(name, definition);
    },
    sendUserMessage(content: string, options?: { expandPromptTemplates?: boolean }) {
      sent.push({ content, options });
    },
  };
  registerStatus(pi as never);
  return { commands, sent };
}

test("/status asks a fresh BTW thread about the current run", async () => {
  const { commands, sent } = loadExtension();

  await commands.get("status")!.handler("", {});

  assert.equal(sent.length, 1);
  assert.match(sent[0].content, /^\/btw:new \S/);
  assert.deepEqual(sent[0].options, { expandPromptTemplates: true });
});

test("the status question anchors on the last ask_user answer", async () => {
  const { commands, sent } = loadExtension();

  await commands.get("status")!.handler("", {});

  assert.match(sent[0].content, /ask_user/);
});
