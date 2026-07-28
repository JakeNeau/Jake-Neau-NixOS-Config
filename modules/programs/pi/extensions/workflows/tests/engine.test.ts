import assert from "node:assert/strict";
import { test } from "node:test";

import {
  InvocationGraph,
  joinIsReady,
  resolveSuccessorSet,
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
