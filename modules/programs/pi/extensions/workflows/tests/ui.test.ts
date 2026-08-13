import assert from "node:assert/strict";
import { test } from "node:test";

import { workflowAutocompleteItems } from "../autocomplete.ts";
import { workflowAnswerForDialogEvent } from "../question.ts";

const labels = [
  "1. Keep both — Preserves both interfaces.",
  "2. Replace the old one — Leaves one interface.",
];

test("returns slash-command completion values without a leading slash", () => {
  assert.deepEqual(
    workflowAutocompleteItems(
      [
        { name: "refine-spec", description: "Refine a specification" },
        { name: "review", description: "Review a change" },
      ],
      "ref",
    ),
    [{ value: "refine-spec", label: "refine-spec", description: "Refine a specification" }],
  );
});

test("maps the shared question dialog events to workflow answers", () => {
  assert.deepEqual(
    workflowAnswerForDialogEvent(labels, { type: "selected", index: 1 }),
    { answer: labels[1], index: 2, status: "answered" },
  );
  assert.deepEqual(
    workflowAnswerForDialogEvent(labels, { type: "free-form", value: "Use an adapter." }),
    { answer: "Use an adapter.", status: "answered" },
  );
  assert.deepEqual(
    workflowAnswerForDialogEvent(labels, { type: "clarification", value: "Which is stable?" }),
    { answer: null, clarification: "Which is stable?", status: "clarification" },
  );
  assert.deepEqual(
    workflowAnswerForDialogEvent(labels, { type: "cancelled" }),
    { answer: null, status: "cancelled" },
  );
});
