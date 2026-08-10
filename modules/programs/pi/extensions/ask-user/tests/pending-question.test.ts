import assert from "node:assert/strict";
import { test } from "node:test";

import { PendingQuestion } from "../pending-question.ts";

const question = {
  question: "Which database?",
  options: [{ label: "PostgreSQL" }, { label: "SQLite" }],
};

test("clarification records a question for automatic reopening", () => {
  const pending = new PendingQuestion();
  pending.finishToolCall(question, "clarification");
  assert.deepEqual(pending.beginReopen(), question);
  assert.equal(pending.beginReopen(), undefined);
});

test("a voluntary tool call prevents an automatic duplicate", () => {
  const pending = new PendingQuestion();
  pending.finishToolCall(question, "clarification");
  pending.beginToolCall();
  assert.equal(pending.beginReopen(), undefined);
});

test("another clarification keeps the question pending", () => {
  const pending = new PendingQuestion();
  pending.finishToolCall(question, "clarification");
  assert.deepEqual(pending.beginReopen(), question);
  pending.finishReopen("clarification");
  assert.deepEqual(pending.beginReopen(), question);
});

test("an answer or cancellation clears the pending question", () => {
  for (const status of ["answered", "cancelled"] as const) {
    const pending = new PendingQuestion();
    pending.finishToolCall(question, "clarification");
    pending.beginReopen();
    pending.finishReopen(status);
    assert.equal(pending.beginReopen(), undefined);
  }
});

test("reset clears pending and reopening state", () => {
  const pending = new PendingQuestion();
  pending.finishToolCall(question, "clarification");
  pending.beginReopen();
  pending.reset();
  assert.equal(pending.beginReopen(), undefined);
});
