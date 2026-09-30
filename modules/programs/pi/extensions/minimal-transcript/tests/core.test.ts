import assert from "node:assert/strict";
import test from "node:test";

import { countPatchChanges, diffSummary, progressLineFromMessage } from "../core.ts";

test("counts changes inside unified patch hunks", () => {
  const patch = [
    "--- notes.txt",
    "+++ notes.txt",
    "@@ -1,2 +1,3 @@",
    "-old",
    "+new",
    " unchanged",
    "+added",
  ].join("\n");

  assert.deepEqual(countPatchChanges(patch), { additions: 2, deletions: 1 });
});

test("formats a collapsed summary", () => {
  assert.equal(
    diffSummary({
      path: "src/main.ts",
      patch: "",
      additions: 3,
      deletions: 1,
      action: "updated",
    }),
    "updated src/main.ts +3 −1",
  );
});

test("accepts one trimmed assistant progress line", () => {
  const message = {
    role: "assistant",
    content: [
      { type: "thinking", thinking: "private reasoning" },
      { type: "text", text: "  Tracing spinner behavior…  " },
      { type: "toolCall", id: "call", name: "read", arguments: {} },
    ],
  };

  assert.equal(progressLineFromMessage(message, (text) => text.length), "Tracing spinner behavior…");
});

test("rejects absent, multiple, multiline, and control-bearing progress text", () => {
  const measure = (text: string) => text.length;
  assert.equal(progressLineFromMessage({ role: "assistant", content: [] }, measure), undefined);
  assert.equal(
    progressLineFromMessage({ role: "assistant", content: [{ type: "text", text: "   " }] }, measure),
    undefined,
  );
  assert.equal(
    progressLineFromMessage(
      {
        role: "assistant",
        content: [
          { type: "text", text: "First activity" },
          { type: "text", text: "Second activity" },
        ],
      },
      measure,
    ),
    undefined,
  );
  assert.equal(
    progressLineFromMessage({ role: "assistant", content: [{ type: "text", text: "First\nSecond" }] }, measure),
    undefined,
  );
  assert.equal(
    progressLineFromMessage({ role: "assistant", content: [{ type: "text", text: "Unsafe\u001b[31m" }] }, measure),
    undefined,
  );
  assert.equal(
    progressLineFromMessage({ role: "user", content: [{ type: "text", text: "Not assistant text" }] }, measure),
    undefined,
  );
});

test("accepts 48 columns and rejects wider terminal text", () => {
  const measureWideText = (text: string) => text.length * 2;
  assert.equal(
    progressLineFromMessage(
      { role: "assistant", content: [{ type: "text", text: "界".repeat(24) }] },
      measureWideText,
    ),
    "界".repeat(24),
  );
  assert.equal(
    progressLineFromMessage(
      { role: "assistant", content: [{ type: "text", text: "界".repeat(25) }] },
      measureWideText,
    ),
    undefined,
  );
});
