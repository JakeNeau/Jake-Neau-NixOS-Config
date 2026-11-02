import assert from "node:assert/strict";
import { test } from "node:test";

import {
  workflowArtifactDetail,
  workflowEntryType,
} from "../artifacts.ts";
import { workflowAutocompleteItems } from "../autocomplete.ts";
import { questionErrors, workflowAnswerForDialogEvent } from "../question.ts";

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

test("marks proposal checkpoints as visible review entries", () => {
  assert.equal(workflowEntryType("proposal"), "workflow-review");
  assert.equal(workflowEntryType("question"), "workflow-artifact");
  assert.equal(workflowEntryType(undefined), "workflow-artifact");
});

test("renders the complete proposal in a review entry", () => {
  const artifact = {
    schemaVersion: 1 as const,
    runId: "run",
    artifactId: "run:1",
    workflow: "refine-plan",
    stageType: "refine",
    stageInvocationId: "run:refine:1",
    parentArtifactIds: [],
    createdAt: "2026-01-01T00:00:00.000Z",
    artifactKind: "refinement-proposal",
    outcome: "proposed",
    summary: "Plan ready for review.",
    payload: { design: "1. Change the filter.\n2. Test the review entry." },
  };
  const detail = workflowArtifactDetail(artifact, false, true);

  assert.equal(detail?.dim, false);
  assert.match(detail?.text ?? "", /1\. Change the filter\./);
  assert.match(detail?.text ?? "", /2\. Test the review entry\./);
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

const questionArtifact = (question: unknown) => ({
  artifactKind: "question",
  outcome: "asked",
  summary: "One decision is open.",
  payload: { question },
});

test("accepts a question payload that the question dialog can read", () => {
  const question = {
    text: "Keep the old interface?",
    why: "Both callers depend on it.",
    options: [{ id: "keep", label: "Keep both", consequence: "Preserves both interfaces." }],
    recommendation: null,
  };
  assert.deepEqual(questionErrors(questionArtifact(question)), []);
  assert.deepEqual(questionErrors(questionArtifact({ ...question, recommendation: "keep" })), []);
  assert.deepEqual(questionErrors({ ...questionArtifact(undefined), artifactKind: "decision-record" }), []);
});

test("reports each missing question field", () => {
  assert.deepEqual(questionErrors(questionArtifact(undefined)), ["payload.question must be an object"]);
  assert.deepEqual(questionErrors(questionArtifact("Keep both?")), ["payload.question must be an object"]);
  assert.deepEqual(questionErrors(questionArtifact(["Keep both?"])), ["payload.question must be an object"]);
  assert.deepEqual(questionErrors(questionArtifact({ options: [] })), [
    "payload.question.text must be a string",
    "payload.question.why must be a string",
    "payload.question.options must be a non-empty array",
  ]);
  assert.deepEqual(questionErrors(questionArtifact({ text: "Keep?", why: "Callers.", options: [{ label: "Keep" }, null], recommendation: 3 })), [
    "payload.question.options[0].consequence must be a string",
    "payload.question.options[1].label must be a string",
    "payload.question.options[1].consequence must be a string",
    "payload.question.recommendation must be a string or null",
  ]);
});
