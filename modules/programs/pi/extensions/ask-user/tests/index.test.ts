import assert from "node:assert/strict";
import { test } from "node:test";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import type { BranchEntry } from "../branch.ts";
import { CLARIFICATION_CHOICE } from "../core.ts";
import askUser from "../index.ts";
import {
  answered,
  answerMessage,
  askUserEntry,
  assistant,
  assistantText,
  clarification,
  question,
  toolResult,
  user,
} from "./entries.ts";

function load(branch: BranchEntry[], selections: string[] = [], inputs: string[] = []) {
  const handlers = new Map<string, (event: unknown, ctx: unknown) => unknown>();
  const renderers = new Map<string, (...args: any[]) => any>();
  const tools: any[] = [];
  const sent: unknown[] = [];
  const dialogs: string[] = [];
  const editor = { text: "" };
  // Entries stay reachable by ID after a test cuts them off the branch, as in Pi.
  const entries = [...branch];

  const pi = {
    registerTool: (tool: unknown) => tools.push(tool),
    registerMessageRenderer: (type: string, renderer: (...args: any[]) => any) => renderers.set(type, renderer),
    on: (event: string, handler: (event: unknown, ctx: unknown) => unknown) => handlers.set(event, handler),
    sendMessage: (message: unknown, options: unknown) => sent.push({ message, options }),
    sendUserMessage: (content: unknown) => sent.push({ sendUserMessage: content }),
    // As in Pi, an appended entry joins the current branch.
    appendEntry: (customType: string, data: unknown) =>
      branch.push({ type: "custom", id: `entry-${branch.length}`, customType, data }),
  } as unknown as ExtensionAPI;
  askUser(pi);

  const ctx = {
    mode: "rpc",
    hasUI: true,
    idle: true,
    isIdle: () => ctx.idle,
    sessionManager: {
      getBranch: () => branch,
      getEntry: (id: string) => entries.find((entry) => entry.id === id),
    },
    ui: {
      select: async (prompt: string) => {
        dialogs.push(prompt);
        return selections.shift();
      },
      input: async () => inputs.shift(),
      getEditorText: () => editor.text,
      setEditorText: (text: string) => {
        editor.text = text;
      },
    },
  };

  return {
    tool: tools[0],
    ctx,
    renderer: renderers.get("ask-user-answer")!,
    sent,
    dialogs,
    editor,
    settle: (aborted = false) => handlers.get("agent_settled")!({ type: "agent_settled", aborted }, ctx),
    emit: (event: string, payload: unknown) => handlers.get(event)?.(payload, ctx),
    // The caller sets the branch to Pi's new leaf first. Resolves after the deferred reopen.
    tree: async (targetId: string) => {
      await handlers.get("session_before_tree")!({ type: "session_before_tree", preparation: { targetId } }, ctx);
      await handlers.get("session_tree")!({ type: "session_tree", newLeafId: branch.at(-1)?.id }, ctx);
      await new Promise((resolve) => setTimeout(resolve, 0));
    },
  };
}

test("sends a reopened answer as a triggered custom message", async () => {
  const pi = load([toolResult("t1", clarification), assistant("a1")], ["2. SQLite"]);
  await pi.settle();

  assert.deepEqual(pi.sent, [{
    message: {
      customType: "ask-user-answer",
      content: 'Answer to the pending question "Which database should this service use?": SQLite',
      display: true,
      details: answered,
    },
    options: { triggerTurn: true },
  }]);
});

test("a legacy answer leaves nothing pending", async () => {
  const pi = load([
    toolResult("t1", clarification),
    assistant("a1"),
    user("u1", 'My answer to the pending question "Which database should this service use?": SQLite'),
    assistant("a2"),
  ]);
  await pi.settle();
  assert.deepEqual(pi.dialogs, []);
});

test("after /tree to an entry before a clarification, nothing is pending", async () => {
  const branch: BranchEntry[] = [user("u1", "Pick a database."), assistant("a1")];
  const pi = load(branch, [CLARIFICATION_CHOICE, "2. SQLite"], [clarification.clarification]);
  await pi.tool.execute("call-1", question, undefined, undefined, pi.ctx);
  branch.push(toolResult("t1", clarification), assistant("a2"));
  await pi.settle();
  branch.splice(2);
  await pi.tree("a1");
  await pi.settle();
  assert.equal(pi.dialogs.length, 2);
  assert.equal(pi.sent.length, 1);
  assert.equal(branch.length, 2);
});

test("reopens once until the answer is saved, and again right after /tree returns to the clarification", async () => {
  const branch: BranchEntry[] = [toolResult("t1", clarification), assistant("a1")];
  const pi = load(branch, ["2. SQLite", "1. PostgreSQL"]);
  await pi.settle();
  await pi.settle();
  assert.equal(pi.dialogs.length, 1);
  assert.equal(pi.sent.length, 1);

  branch.push(answerMessage("m1", answered), assistant("a2"));
  await pi.settle();
  branch.splice(2);
  await pi.tree("a1");
  await pi.settle();
  assert.equal(pi.dialogs.length, 2);
  assert.equal(pi.sent.length, 2);
});

test("/tree to a clarification row reopens its question without waiting for a message", async () => {
  const branch: BranchEntry[] = [toolResult("t1", clarification), assistantText("a1", "Yes, it does.")];
  const pi = load(branch, ["1. PostgreSQL"]);
  branch.splice(1);

  await pi.tree("t1");

  assert.deepEqual(pi.sent, [{
    message: {
      customType: "ask-user-answer",
      content: 'Answer to the pending question "Which database should this service use?": PostgreSQL',
      display: true,
      details: { ...question, answer: "PostgreSQL", index: 1, source: "option", status: "answered" },
    },
    options: { triggerTurn: true },
  }]);
});

test("/tree to an answered row reopens its question and sends a revised answer", async () => {
  const pi = load([toolResult("t1", answered)], ["1. PostgreSQL"]);

  await pi.tree("t1");

  assert.deepEqual(pi.sent, [{
    message: {
      customType: "ask-user-answer",
      content: 'Revised answer to the question "Which database should this service use?": PostgreSQL',
      display: true,
      details: { ...question, answer: "PostgreSQL", index: 1, source: "option", status: "answered" },
    },
    options: { triggerTurn: true },
  }]);
});

test("escape on a revised question keeps the earlier answer", async () => {
  const branch: BranchEntry[] = [toolResult("t1", answered)];
  const pi = load(branch);

  await pi.tree("t1");

  assert.equal(pi.dialogs.length, 1);
  assert.deepEqual(pi.sent, []);
  assert.deepEqual(branch, [toolResult("t1", answered)]);
});

test("/tree to an entry after an answered question opens no dialog", async () => {
  const pi = load([toolResult("t1", answered), assistant("a1")], ["1. PostgreSQL"]);

  await pi.tree("a1");

  assert.deepEqual(pi.dialogs, []);
});

test("/tree opens no dialog while Pi is busy", async () => {
  const pi = load([toolResult("t1", answered)], ["1. PostgreSQL"]);
  pi.ctx.idle = false;

  await pi.tree("t1");

  assert.deepEqual(pi.dialogs, []);
});

test("/tree to a reopened answer clears that answer from the editor", async () => {
  const content = 'Answer to the pending question "Which database should this service use?": SQLite';
  const branch: BranchEntry[] = [
    toolResult("t1", clarification),
    assistantText("a1", "Yes, it does."),
    { type: "custom_message", id: "m1", customType: "ask-user-answer", content, details: answered },
  ];
  const pi = load(branch, ["1. PostgreSQL"]);
  branch.splice(2);
  pi.editor.text = content;

  await pi.tree("m1");

  assert.equal(pi.editor.text, "");
  assert.equal(pi.sent.length, 1);
});

test("/tree to a reopened answer keeps the user's own editor text", async () => {
  const content = 'Answer to the pending question "Which database should this service use?": SQLite';
  const branch: BranchEntry[] = [
    toolResult("t1", clarification),
    assistantText("a1", "Yes, it does."),
    { type: "custom_message", id: "m1", customType: "ask-user-answer", content, details: answered },
  ];
  const pi = load(branch, ["1. PostgreSQL"]);
  branch.splice(2);
  pi.editor.text = "my draft";

  await pi.tree("m1");

  assert.equal(pi.editor.text, "my draft");
});

test("refuses to repeat a question before the assistant replies to the clarification in visible text", async () => {
  const pi = load([toolResult("t1", clarification)], ["2. SQLite"]);

  await assert.rejects(
    pi.tool.execute("call-2", question, undefined, undefined, pi.ctx),
    /Reply to the user's clarifying question in visible text/,
  );
  assert.deepEqual(pi.dialogs, []);
});

test("asks a revised question after a visible reply to the clarification", async () => {
  const pi = load([toolResult("t1", clarification), assistantText("a1", "Yes, it does.")], ["2. SQLite"]);

  const result = await pi.tool.execute("call-2", question, undefined, undefined, pi.ctx);

  assert.deepEqual(result.content, [{ type: "text", text: "User selected option 2: SQLite" }]);
});

test("renders each kind of reopened answer as one line", () => {
  const theme = { fg: (_color: string, text: string) => text };
  const { renderer } = load([]);
  const render = (details: unknown) =>
    renderer({ customType: "ask-user-answer", details }, { expanded: false, outputPad: 1 }, theme)
      .render(60)
      .map((line: string) => line.trimEnd());
  const freeForm = { ...question, answer: "MySQL", source: "free-form", status: "answered" };

  assert.deepEqual([answered, freeForm, clarification].map(render), [
    [" User selected option 2: SQLite"],
    [" User wrote: MySQL"],
    [" User asked: Does it need concurrent writes?"],
  ]);
});

test("a new clarification reopens after an earlier reopen", async () => {
  const branch: BranchEntry[] = [toolResult("t1", clarification), assistant("a1")];
  const pi = load(branch, ["2. SQLite", "1. PostgreSQL"]);
  await pi.settle();
  branch.push(answerMessage("m1", answered), assistant("a2"), toolResult("t2", clarification), assistant("a3"));
  await pi.settle();
  assert.equal(pi.dialogs.length, 2);
});

test("drops the question when the answer run was aborted", async () => {
  const branch = [toolResult("t1", clarification), assistant("a1")];
  const pi = load(branch, ["2. SQLite"]);
  await pi.settle(true);

  assert.deepEqual(pi.dialogs, []);
  assert.deepEqual(branch.at(-1), askUserEntry("entry-2", { ...question, answer: null, status: "cancelled" }));
  await pi.settle();
  assert.deepEqual(pi.dialogs, []);
  assert.deepEqual(pi.sent, []);
});

test("drops the question when the answer run ended with a provider error", async () => {
  const pi = load([toolResult("t1", clarification), assistant("a1", "error")], ["2. SQLite"]);
  await pi.settle();
  assert.deepEqual(pi.dialogs, []);
});

test("drops the question only when an automatic compaction was cancelled", async () => {
  const threshold = load([toolResult("t1", clarification), assistant("a1")], ["2. SQLite"]);
  threshold.emit("session_compact_failed", { type: "session_compact_failed", reason: "threshold", aborted: true });
  await threshold.settle();
  assert.deepEqual(threshold.dialogs, []);

  const manual = load([toolResult("t1", clarification), assistant("a1")], ["2. SQLite"]);
  manual.emit("session_compact_failed", { type: "session_compact_failed", reason: "manual", aborted: true });
  await manual.settle();
  assert.equal(manual.dialogs.length, 1);
});

test("an aborted settle of a queued run neither drops nor reopens the reopened question", async () => {
  const branch: BranchEntry[] = [toolResult("t1", clarification), assistant("a1")];
  const pi = load(branch, ["2. SQLite"]);
  await pi.settle();
  await pi.settle(true);
  assert.equal(branch.length, 2);
  assert.equal(pi.dialogs.length, 1);
});

test("each settle clears the cancelled-compaction flag", async () => {
  const branch: BranchEntry[] = [user("u1", "Pick a database."), assistant("a1")];
  const pi = load(branch, ["2. SQLite"]);
  pi.emit("session_compact_failed", { type: "session_compact_failed", reason: "threshold", aborted: true });
  await pi.settle();
  branch.push(toolResult("t1", clarification), assistant("a2"));
  await pi.settle();
  assert.equal(pi.dialogs.length, 1);
});

test("registers the tool as model-only", () => {
  assert.equal(load([]).tool.exposure, "model-only");
});

test("normalizes carriage returns before schema validation", () => {
  assert.deepEqual(
    load([]).tool.prepareArguments({ question: "Which\r\ndatabase?", options: [{ label: "SQL\rite" }, { label: "None" }] }),
    { question: "Which\ndatabase?", options: [{ label: "SQLite" }, { label: "None" }] },
  );
});

test("sends another clarification from a reopen as a triggered custom message", async () => {
  const pi = load([toolResult("t1", clarification), assistant("a1")], [CLARIFICATION_CHOICE], ["Why?"]);
  await pi.settle();

  assert.deepEqual(pi.sent, [{
    message: {
      customType: "ask-user-answer",
      content: 'Clarifying question before answering "Which database should this service use?": Why?',
      display: true,
      details: { ...question, answer: null, clarification: "Why?", status: "clarification" },
    },
    options: { triggerTurn: true },
  }]);
});

test("records a cancelled reopen so /tree does not bring the question back", async () => {
  const branch: BranchEntry[] = [toolResult("t1", clarification), assistant("a1")];
  const pi = load(branch);
  await pi.settle();

  assert.deepEqual(branch.at(-1), askUserEntry("entry-2", { ...question, answer: null, status: "cancelled" }));
  assert.deepEqual(pi.sent, []);
  await pi.tree("entry-2");
  await pi.settle();
  assert.equal(pi.dialogs.length, 1);
});

test("records an unavailable reopen when there is no UI", async () => {
  const branch: BranchEntry[] = [toolResult("t1", clarification), assistant("a1")];
  const pi = load(branch);
  pi.ctx.hasUI = false;
  await pi.settle();

  assert.deepEqual(branch.at(-1), askUserEntry("entry-2", { ...question, answer: null, status: "unavailable" }));
  assert.deepEqual(pi.sent, []);
});
