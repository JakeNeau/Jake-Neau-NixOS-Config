import assert from "node:assert/strict";
import { mkdtemp, readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

import {
  StrictJsonlDecoder,
  buildChildArguments,
  contextBudgetWarning,
  mutationBlockReason,
  runStage,
  type StageRunOptions,
} from "../runner.ts";

const FAKE_CHILD = fileURLToPath(new URL("./fake-child.mjs", import.meta.url));
const SCHEMA = {
  type: "object",
  required: ["artifactKind", "outcome", "summary", "payload"],
  properties: {
    artifactKind: { enum: ["note"] },
    outcome: { enum: ["done"] },
    summary: { type: "string" },
    payload: { type: "object" },
  },
};
const ARTIFACT = { artifactKind: "note", outcome: "done", summary: "Done.", payload: {} };

const started = { type: "response", command: "prompt", success: true, data: { disposition: "started" } };
const settled = { type: "agent_settled" };
const output = (artifact: unknown = ARTIFACT) => ({
  type: "tool_execution_end",
  toolName: "workflow_output",
  result: { details: { artifact } },
});
const assistant = (message: Record<string, unknown> = {}) => ({
  type: "message_end",
  message: { role: "assistant", stopReason: "stop", ...message },
});

function run(scenario: unknown, overrides: Partial<StageRunOptions> = {}) {
  const events: any[] = [];
  const result = runStage({
    cwd: process.cwd(),
    prompt: "Run the stage.",
    schema: SCHEMA,
    provider: "test",
    model: "model",
    thinking: "off",
    tools: ["read"],
    trusted: false,
    readOnly: true,
    artifacts: [],
    catalog: [],
    timeoutMs: 2_000,
    invocation: (args) => ({ command: process.execPath, args: [FAKE_CHILD, JSON.stringify(scenario), ...args] }),
    onEvent: (event) => events.push(event),
    ...overrides,
  });
  return { result, events };
}

function received(events: any[], type: string): any[] {
  return events.filter((event) => event.type === "fake_received" && event.record.type === type).map((event) => event.record);
}

test("decodes fragmented LF-delimited RPC records without treating Unicode separators as framing", () => {
  const decoder = new StrictJsonlDecoder();
  assert.deepEqual(decoder.push(Buffer.from('{"type":"one","text":"a\u2028b"}\n{"type":')), [
    { type: "one", text: "a b" },
  ]);
  assert.deepEqual(decoder.push(Buffer.from('"two"}\r\n')), [{ type: "two" }]);
  assert.deepEqual(decoder.finish(), []);
});

test("builds a child invocation that inherits model and thinking", () => {
  assert.deepEqual(buildChildArguments({
    provider: "openai-codex",
    model: "gpt-5.6",
    thinking: "high",
    tools: ["read", "workflow_output"],
    trusted: true,
  }), [
    "--mode", "rpc", "--no-session", "--model", "openai-codex/gpt-5.6",
    "--thinking", "high", "--tools", "read,workflow_output", "--approve",
  ]);
});

test("returns a valid artifact without a correction", async () => {
  const { result, events } = run({ attempts: [[started, output(), assistant(), settled]] });
  const stage = await result;
  assert.deepEqual(stage.artifact, ARTIFACT);
  assert.equal(stage.repaired, false);
  assert.equal(received(events, "prompt").length, 1);
});

test("passes every tool to the child as the single pattern *", () => {
  assert.deepEqual(buildChildArguments({
    provider: "openai-codex",
    model: "gpt-5.6",
    thinking: "high",
    tools: "*",
    trusted: false,
  }), [
    "--mode", "rpc", "--no-session", "--model", "openai-codex/gpt-5.6",
    "--thinking", "high", "--tools", "*", "--no-approve",
  ]);
});

test("limits edits to approved paths in mutation stages only", () => {
  const approved = new Set(["/repo/specs/plan.md"]);
  assert.equal(mutationBlockReason(true, new Set(), "/repo/README.md"), undefined);
  assert.equal(mutationBlockReason(false, approved, "/repo/specs/plan.md"), undefined);
  assert.equal(
    mutationBlockReason(false, approved, "/repo/README.md"),
    "Workflow mutation path is not approved: /repo/README.md",
  );
  assert.equal(mutationBlockReason(false, approved, undefined), "Workflow mutation has no path");
});

test("adds the workflow tools to a tool list and passes * alone", async () => {
  const scenario = { attempts: [[started, output(), assistant(), settled]] };
  const listed = run(scenario, { tools: ["read", "read"] });
  await listed.result;
  const star = run(scenario, { tools: "*" });
  await star.result;
  const toolsArgument = (events: any[]) => {
    const args: string[] = events.find((event) => event.type === "fake_argv").args;
    return args[args.indexOf("--tools") + 1];
  };
  assert.equal(toolsArgument(listed.events), "read,workflow_output,request_workflow_artifacts");
  assert.equal(toolsArgument(star.events), "*");
});

test("fails at once when the child rejects the prompt", async () => {
  const { result } = run({
    attempts: [[{ type: "response", command: "prompt", success: false, error: "No API key for provider: test" }]],
  });
  await assert.rejects(result, /No API key for provider: test/);
});

test("fails at once when an extension handles the prompt without a run", async () => {
  const { result } = run({
    attempts: [[{ type: "response", command: "prompt", success: true, data: { disposition: "handled" } }]],
  });
  await assert.rejects(result, /handled the stage prompt/);
});

test("fails with the provider error and sends no correction", async () => {
  const { result, events } = run({
    attempts: [[started, assistant({ stopReason: "error", errorMessage: "529 overloaded" }), settled]],
  });
  await assert.rejects(result, /529 overloaded/);
  assert.equal(received(events, "prompt").length, 1);
});

test("keeps a valid artifact even when the last message reports a provider error", async () => {
  const { result, events } = run({
    attempts: [[started, output(), assistant({ stopReason: "error", errorMessage: "529 overloaded" }), settled]],
  });
  assert.equal((await result).repaired, false);
  assert.equal(received(events, "prompt").length, 1);
});

test("fails at once when the child exits after its first settle", async () => {
  const { result } = run({ attempts: [[started, assistant(), settled, { exit: 3 }]] });
  await assert.rejects(result, /exited before settling with 3/);
});

test("cancels a child dialog and leaves a notification unanswered", async () => {
  const { result, events } = run({
    attempts: [[
      started,
      { type: "extension_ui_request", id: "notice", method: "notify", message: "Loaded." },
      { type: "extension_ui_request", id: "confirm", method: "confirm", title: "Overwrite?" },
      { awaitReply: true },
      output(),
      assistant(),
      settled,
    ]],
  });
  await result;
  assert.deepEqual(received(events, "extension_ui_response"), [
    { type: "extension_ui_response", id: "confirm", cancelled: true },
  ]);
});

test("gives the correction its own timeout", async () => {
  const { result } = run({
    attempts: [
      [started, { delay: 700 }, assistant(), settled],
      [started, { delay: 700 }, output(), assistant(), settled],
    ],
  }, { timeoutMs: 1_200 });
  assert.equal((await result).repaired, true);
});

test("stops without a correction when aborted during a stage", async () => {
  const controller = new AbortController();
  const events: any[] = [];
  const { result } = run({ attempts: [[started, { delay: 5_000 }]], onAbort: [settled] }, {
    signal: controller.signal,
    onEvent: (event: any) => {
      events.push(event);
      if (event.type === "fake_received" && event.record.type === "prompt") controller.abort();
    },
  });
  await assert.rejects(result, { name: "AbortError" });
  assert.equal(received(events, "prompt").length, 1);
});

test("spawns nothing and leaves no stage directory when the signal is already aborted", async () => {
  const controller = new AbortController();
  controller.abort();
  let spawned = false;
  // tmpdir() reads TMPDIR on each call, so the stage directory lands in a fresh root.
  const root = await mkdtemp(join(tmpdir(), "pi-workflow-test-"));
  const previous = process.env.TMPDIR;
  process.env.TMPDIR = root;
  try {
    const { result } = run({ attempts: [] }, {
      signal: controller.signal,
      invocation: () => {
        spawned = true;
        return { command: process.execPath, args: ["-e", ""] };
      },
    });
    await assert.rejects(result, { name: "AbortError" });
  } finally {
    if (previous === undefined) delete process.env.TMPDIR;
    else process.env.TMPDIR = previous;
  }
  assert.equal(spawned, false);
  assert.deepEqual(await readdir(root), []);
});

test("corrects a check error exactly once", async () => {
  const { result, events } = run({
    attempts: [
      [started, output(), assistant(), settled],
      [started, output(), assistant(), settled],
    ],
  }, { check: () => ["Outcome done has no route. Allowed outcomes: ready"] });
  await assert.rejects(result, /has no route/);
  const prompts = received(events, "prompt");
  assert.equal(prompts.length, 2);
  assert.match(prompts[1].message, /Outcome done has no route/);
});

test("runs the check only on an artifact that passes the schema", async () => {
  const checked: unknown[] = [];
  const { result } = run({
    attempts: [
      [started, output({ artifactKind: "note" }), assistant(), settled],
      [started, output(), assistant(), settled],
    ],
  }, {
    check: (artifact) => {
      checked.push(artifact);
      return [];
    },
  });
  assert.equal((await result).repaired, true);
  assert.deepEqual(checked, [ARTIFACT]);
});

test("records the peak request size of the stage", async () => {
  const usage = (input: number, totalTokens: number, cache = 0) =>
    ({ input, output: 20, cacheRead: cache, cacheWrite: cache, totalTokens });
  const { result } = run({
    attempts: [[
      started,
      assistant({ stopReason: "toolUse", usage: usage(1_500, 0, 500) }),
      output(),
      assistant({ usage: usage(3_000, 2_000) }),
      settled,
    ]],
  });
  assert.equal((await result).peakContextTokens, 2_520);
});

test("warns only above 20% of a known context window", () => {
  assert.equal(
    contextBudgetWarning("refine", 54_000, 200_000),
    "refine used 27% of the context window, above the 20% budget",
  );
  assert.equal(contextBudgetWarning("refine", 40_000, 200_000), undefined);
  assert.equal(
    contextBudgetWarning("refine", 40_800, 200_000),
    "refine used 21% of the context window, above the 20% budget",
  );
  assert.equal(
    contextBudgetWarning("refine", 110_000, 200_000),
    "refine used 55% of the context window, above the 20% budget",
  );
  assert.equal(contextBudgetWarning("refine", 54_000, undefined), undefined);
  assert.equal(contextBudgetWarning("refine", 54_000, 0), undefined);
});
