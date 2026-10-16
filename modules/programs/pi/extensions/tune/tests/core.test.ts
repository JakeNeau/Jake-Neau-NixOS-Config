import assert from "node:assert/strict";
import test from "node:test";

import { registerTune, TuneState, type TuneApi, type TuneContext, type TuneTool } from "../core.ts";

const INSTRUCTIONS = "Tune the next draft.";

type Run = (propose: (prompt: string) => Promise<unknown>) => void | Promise<void>;

interface Scenario {
  leaf?: string | null;
  mode?: string;
  idle?: boolean;
  pending?: boolean;
  editorText?: string;
  runs?: Run[];
  choices?: Array<string | undefined>;
  edits?: Array<string | undefined>;
  inputs?: Array<string | undefined>;
  cancelNavigation?: boolean;
  waitError?: Error;
}

interface Entry {
  parentId: string | null;
  content: string;
}

function load() {
  let command: ((args: string, ctx: TuneContext) => Promise<void>) | undefined;
  let tool: TuneTool | undefined;
  const handlers = new Map<string, () => void>();
  const log: unknown[] = [];
  let session: { send(message: { customType: string; content: string; display: boolean }, trigger: boolean): void } | undefined;

  const pi: TuneApi = {
    registerCommand(name, definition) {
      assert.equal(name, "tune");
      command = definition.handler;
    },
    registerTool(definition) {
      tool = definition;
    },
    sendMessage(message, options) {
      log.push({ sendMessage: message.customType, display: message.display, triggerTurn: options?.triggerTurn ?? false });
      session?.send(message, options?.triggerTurn ?? false);
    },
    sendUserMessage(content) {
      log.push({ sendUserMessage: content });
    },
    on(event, handler) {
      handlers.set(event, handler);
    },
  };
  registerTune(pi, { loadInstructions: async () => INSTRUCTIONS, parameters: {} });

  const propose = (prompt: string) => tool!.execute("call", { prompt });

  function context(scenario: Scenario = {}) {
    let leaf = scenario.leaf === undefined ? "root" : scenario.leaf;
    let nextId = 0;
    let editorText = scenario.editorText ?? "";
    const entries = new Map<string, Entry>();
    const runs = [...(scenario.runs ?? [])];
    const choices = [...(scenario.choices ?? [])];
    const edits = [...(scenario.edits ?? [])];
    const inputs = [...(scenario.inputs ?? [])];
    const titles: string[] = [];

    session = {
      send(message) {
        const id = `entry-${++nextId}`;
        entries.set(id, { parentId: leaf, content: message.content });
        leaf = id;
      },
    };

    const ctx: TuneContext = {
      mode: scenario.mode ?? "tui",
      isIdle: () => scenario.idle ?? true,
      hasPendingMessages: () => scenario.pending ?? false,
      sessionManager: {
        getLeafId: () => leaf,
        getEntry: (id) => entries.get(id),
      },
      async waitForIdle() {
        if (scenario.waitError) throw scenario.waitError;
        await runs.shift()?.(propose);
      },
      async navigateTree(targetId, options) {
        log.push({ navigateTree: targetId, summarize: options.summarize });
        if (scenario.cancelNavigation) return { cancelled: true };
        const target = entries.get(targetId)!;
        leaf = target.parentId;
        if (!editorText.trim()) editorText = target.content;
        return { cancelled: false };
      },
      ui: {
        notify: (message, level) => log.push({ notify: message, level }),
        async select(title, options) {
          assert.deepEqual(options, ["Accept", "Edit", "Keep tuning", "Cancel"]);
          titles.push(title);
          return choices.shift();
        },
        editor: async () => edits.shift(),
        input: async () => inputs.shift(),
        getEditorText: () => editorText,
        setEditorText(text) {
          editorText = text;
          log.push({ setEditorText: text });
        },
      },
    };

    return {
      ctx,
      entries,
      titles,
      leaf: () => leaf,
      run: (args: string) => command!(args, ctx),
    };
  }

  return { context, handlers, log, propose, tool: () => tool! };
}

const proposing =
  (prompt: string): Run =>
  async (propose) => {
    await propose(prompt);
  };

test("each preflight failure only notifies", async () => {
  const cases: Array<[string, Scenario, string, string]> = [
    ["   ", {}, "Usage: /tune <draft prompt>", "warning"],
    ["draft", { mode: "rpc" }, "/tune requires interactive mode.", "error"],
    ["draft", { idle: false }, "/tune cannot start while the agent is busy.", "error"],
    ["draft", { pending: true }, "/tune cannot start while the agent is busy.", "error"],
  ];
  for (const [args, scenario, message, level] of cases) {
    const { context, log } = load();
    const session = context(scenario);
    await session.run(args);
    assert.deepEqual(log, [{ notify: message, level }]);
    assert.equal(session.leaf(), "root");
  }
});

test("a second /tune during an active run only notifies", async () => {
  const { context, log } = load();
  const outer = context({
    runs: [
      async () => {
        const inner = context();
        const before = log.length;
        await inner.run("other draft");
        assert.deepEqual(log.slice(before), [{ notify: "/tune is already running.", level: "error" }]);
      },
    ],
  });
  await outer.run("draft");
});

test("propose_prompt fails outside a run and the last proposal wins inside one", async () => {
  const { context, log, propose, tool } = load();
  await assert.rejects(propose("early"), { message: "propose_prompt is available only during a /tune run." });
  assert.equal(tool().promptSnippet, "Propose the tuned prompt during /tune");

  const results: unknown[] = [];
  const session = context({
    runs: [
      async (propose) => {
        results.push(await propose("first"));
        results.push(await propose("  second  "));
      },
    ],
    choices: ["Accept"],
  });
  await session.run("draft");

  assert.ok(results.every((result) => (result as { terminate?: boolean }).terminate === true));
  assert.deepEqual(log.at(-1), { sendUserMessage: "second" });
  await assert.rejects(propose("late"), { message: "propose_prompt is available only during a /tune run." });
});

test("session events end an active run", async () => {
  const { context, handlers, propose } = load();
  const session = context({
    runs: [
      async () => {
        handlers.get("session_shutdown")!();
        await assert.rejects(propose("stale"));
      },
    ],
  });
  await session.run("draft");
  assert.ok(handlers.has("session_start"));
});

test("Accept rewinds to the recorded leaf before submitting the proposal", async () => {
  for (const leaf of ["root", null]) {
    const { context, log } = load();
    const session = context({ leaf, editorText: "", runs: [proposing("tuned")], choices: ["Accept"] });
    await session.run("draft text");

    const [anchorId, anchor] = [...session.entries][0]!;
    assert.equal(anchor.parentId, leaf);
    assert.equal(anchor.content, INSTRUCTIONS);
    assert.equal(session.leaf(), leaf);
    assert.deepEqual(log, [
      { sendMessage: "tune-instructions", display: false, triggerTurn: false },
      { sendMessage: "tune-draft", display: true, triggerTurn: true },
      { navigateTree: anchorId, summarize: false },
      { setEditorText: "" },
      { sendUserMessage: "tuned" },
    ]);
    assert.equal(session.titles[0], "Tuned prompt\n\ntuned");
    assert.equal([...session.entries.values()][1]!.content, "Draft prompt:\n\ndraft text");
  }
});

test("Cancel and Escape rewind and submit nothing", async () => {
  for (const choice of ["Cancel", undefined]) {
    const { context, log } = load();
    const session = context({ editorText: "kept", runs: [proposing("tuned")], choices: [choice] });
    await session.run("draft");

    assert.equal(session.leaf(), "root");
    assert.ok(log.some((call) => "navigateTree" in (call as object)));
    assert.deepEqual(log.at(-1), { setEditorText: "kept" });
    assert.ok(!log.some((call) => "sendUserMessage" in (call as object)));
  }
});

test("a run without a proposal rewinds, warns, and submits nothing", async () => {
  const scenarios: Scenario[] = [
    { runs: [() => {}] },
    { runs: [proposing("tuned"), () => {}], choices: ["Keep tuning"], inputs: ["shorter"] },
  ];
  for (const scenario of scenarios) {
    const { context, log } = load();
    const session = context(scenario);
    await session.run("draft");

    assert.equal(session.leaf(), "root");
    assert.deepEqual(log.at(-1), { notify: "The agent proposed no prompt.", level: "warning" });
    assert.ok(!log.some((call) => "sendUserMessage" in (call as object)));
  }
});

test("Edit shows the choices again with the edited proposal", async () => {
  const { context, log } = load();
  const session = context({
    runs: [proposing("tuned")],
    choices: ["Edit", "Edit", "Accept"],
    edits: ["  edited  ", "   "],
  });
  await session.run("draft");

  assert.deepEqual(session.titles, [
    "Tuned prompt\n\ntuned",
    "Tuned prompt\n\nedited",
    "Tuned prompt\n\nedited",
  ]);
  assert.deepEqual(log.at(-1), { sendUserMessage: "edited" });
});

test("Keep tuning sends feedback and shows the new proposal", async () => {
  const { context, log } = load();
  const session = context({
    runs: [proposing("first"), proposing("second")],
    choices: ["Keep tuning", "Keep tuning", "Accept"],
    inputs: ["   ", "be shorter"],
  });
  await session.run("draft");

  const feedback = log.filter((call) => (call as { sendMessage?: string }).sendMessage === "tune-feedback");
  assert.deepEqual(feedback, [{ sendMessage: "tune-feedback", display: true, triggerTurn: true }]);
  assert.match([...session.entries.values()].at(-1)!.content, /be shorter/);
  assert.deepEqual(session.titles, [
    "Tuned prompt\n\nfirst",
    "Tuned prompt\n\nfirst",
    "Tuned prompt\n\nsecond",
  ]);
  assert.deepEqual(log.at(-1), { sendUserMessage: "second" });
});

test("a cancelled rewind reports the error and Accept submits nothing", async () => {
  const { context, log, propose } = load();
  const session = context({ runs: [proposing("tuned")], choices: ["Accept"], cancelNavigation: true });
  await session.run("draft");

  assert.equal(log.filter((call) => "navigateTree" in (call as object)).length, 1);
  assert.deepEqual(log.at(-1), {
    notify: "Pi could not leave the tuning exchange. Open /tree to return.",
    level: "error",
  });
  assert.ok(!log.some((call) => "sendUserMessage" in (call as object)));
  await assert.rejects(propose("late"));
});

test("an error while waiting rewinds once and reports it", async () => {
  const { context, log, propose } = load();
  const session = context({ waitError: new Error("run failed") });
  await session.run("draft");

  assert.equal(session.leaf(), "root");
  assert.equal(log.filter((call) => "navigateTree" in (call as object)).length, 1);
  assert.deepEqual(log.at(-1), { notify: "run failed", level: "error" });
  await assert.rejects(propose("late"));
});

test("TuneState rejects a nested begin and resets on end", () => {
  const state = new TuneState();
  state.begin();
  assert.throws(() => state.begin());
  state.propose("  prompt  ");
  assert.equal(state.proposal, "prompt");
  state.end();
  assert.equal(state.active, false);
  assert.equal(state.proposal, undefined);
});
