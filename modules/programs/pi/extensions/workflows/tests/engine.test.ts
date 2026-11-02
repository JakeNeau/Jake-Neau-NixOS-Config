import assert from "node:assert/strict";
import { test } from "node:test";

import {
  InvocationGraph,
  joinIsReady,
  mapWithConcurrency,
  outcomeChoices,
  resolveSuccessorSet,
  routeErrors,
  routerSelectionErrors,
  validateRouterSelection,
} from "../engine.ts";

test("resolves one route directly and validates adaptive route sets", () => {
  const transitions = {
    ready: [["write"]],
    inspect: [["spec-scout", "code-scout"], ["full-audit"]],
  };

  assert.deepEqual(resolveSuccessorSet(transitions, "ready"), ["write"]);
  assert.equal(resolveSuccessorSet(transitions, "inspect"), undefined);
  assert.deepEqual(
    validateRouterSelection(transitions.inspect, ["code-scout", "spec-scout"]),
    ["spec-scout", "code-scout"],
  );
  assert.throws(
    () => validateRouterSelection(transitions.inspect, ["write"]),
    /not an allowed successor set/,
  );
});

test("schedules forked invocations and keeps concrete lineage acyclic", () => {
  const graph = new InvocationGraph("run-1");
  const root = graph.schedule("discover", []);
  const left = graph.schedule("spec-scout", [root.invocationId]);
  const right = graph.schedule("code-scout", [root.invocationId]);
  const joined = graph.schedule("synthesize", [left.invocationId, right.invocationId]);

  assert.equal(root.invocationId, "run-1/stage-1");
  assert.deepEqual(joined.parentInvocationIds, [left.invocationId, right.invocationId]);
  assert.throws(
    () => graph.schedule("cycle", ["run-1/stage-999"]),
    /Unknown parent invocation/,
  );
});

test("applies all and any join policies within one iteration", () => {
  const completed = [
    { stageType: "spec-scout", iteration: "issue-1" },
    { stageType: "code-scout", iteration: "issue-1" },
    { stageType: "test-scout", iteration: "issue-2" },
  ];

  assert.equal(joinIsReady({ mode: "all", stages: ["spec-scout", "code-scout"] }, completed, "issue-1"), true);
  assert.equal(joinIsReady({ mode: "all", stages: ["spec-scout", "test-scout"] }, completed, "issue-1"), false);
  assert.equal(joinIsReady({ mode: "any", stages: ["test-scout", "code-scout"] }, completed, "issue-1"), true);
});

test("returns route errors that list the allowed outcomes", () => {
  const transitions = { ready: [["write"]], done: [] };
  assert.deepEqual(routeErrors(transitions, "ready"), []);
  assert.deepEqual(routeErrors(transitions, "done"), []);
  assert.deepEqual(routeErrors(transitions, "blocked"), ["Outcome blocked has no route. Allowed outcomes: ready, done"]);
});

test("returns router selection errors that list the allowed sets", () => {
  const allowed = [["spec-scout", "code-scout"], ["full-audit"]];
  assert.deepEqual(routerSelectionErrors(allowed, ["code-scout", "spec-scout"]), []);
  assert.deepEqual(routerSelectionErrors(allowed, ["write"]), [
    'Router selection is not an allowed successor set: write. Allowed sets: [["spec-scout","code-scout"],["full-audit"]]',
  ]);
});

test("treats an inherited key such as constructor as an outcome without a route", () => {
  const transitions = { ready: [["write"]] };
  assert.equal(outcomeChoices(transitions, "constructor"), undefined);
  assert.throws(() => resolveSuccessorSet(transitions, "constructor"), /No transition for outcome: constructor/);
  assert.deepEqual(routeErrors(transitions, "constructor"), ["Outcome constructor has no route. Allowed outcomes: ready"]);
});

test("stops sibling branches and takes no new item after a branch fails", async () => {
  const started: number[] = [];
  const stopped: number[] = [];
  const result = mapWithConcurrency([0, 1, 2, 3], 2, async (value, _index, signal) => {
    started.push(value);
    if (value === 0) throw new Error("branch 0 failed");
    await new Promise((resolve) => signal.addEventListener("abort", resolve, { once: true }));
    stopped.push(value);
    return value;
  }, new AbortController().signal);
  await assert.rejects(result, /branch 0 failed/);
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(started, [0, 1]);
  assert.deepEqual(stopped, [1]);
});

test("passes the caller's abort to the branches and returns no partial results", async () => {
  const caller = new AbortController();
  const reason = new Error("stop");
  const seen: boolean[] = [];
  const result = mapWithConcurrency([0, 1, 2], 1, async (value, _index, signal) => {
    caller.abort(reason);
    seen.push(signal.aborted);
    return value;
  }, caller.signal);
  await assert.rejects(result, (error) => error === reason);
  assert.deepEqual(seen, [true]);
});
