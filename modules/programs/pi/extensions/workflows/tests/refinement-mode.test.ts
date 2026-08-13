import assert from "node:assert/strict";
import { test } from "node:test";

import { parseRefinementInput } from "../refinement-mode.ts";

test("changes refinement modes for exact commands", () => {
  assert.deepEqual(parseRefinementInput("/clarify"), { action: "switch", mode: "clarify" });
  assert.deepEqual(parseRefinementInput(" /EXPLORE "), { action: "switch", mode: "explore" });
  assert.deepEqual(parseRefinementInput("/write"), { action: "write" });
  assert.deepEqual(parseRefinementInput("/stop"), { action: "stop" });
});

test("changes refinement modes for explicit natural-language instructions", () => {
  assert.deepEqual(parseRefinementInput("Switch to clarification mode."), { action: "switch", mode: "clarify" });
  assert.deepEqual(parseRefinementInput("Please enter explore mode"), { action: "switch", mode: "explore" });
  assert.deepEqual(parseRefinementInput("Could you switch to exploration mode?"), {
    action: "switch",
    mode: "explore",
  });
  assert.deepEqual(parseRefinementInput("Let’s start writing the specification."), { action: "write" });
  assert.deepEqual(parseRefinementInput("Stop the workflow."), { action: "stop" });
});

test("keeps discussion and unsupported slash input inside the current mode", () => {
  for (const text of [
    "Let us explore another approach.",
    "I think we can write this now.",
    "Should we switch to clarification mode?",
    "The next stage could be writing.",
    "/audit",
    "/write please",
  ]) {
    assert.deepEqual(parseRefinementInput(text), { action: "message", text });
  }
});
