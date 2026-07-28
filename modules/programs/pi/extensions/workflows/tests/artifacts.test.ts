import assert from "node:assert/strict";
import { test } from "node:test";

import { ArtifactStore, validateSchemaValue } from "../artifacts.ts";

const schema = {
  type: "object",
  additionalProperties: false,
  required: ["artifactKind", "outcome", "summary", "payload"],
  properties: {
    artifactKind: { enum: ["evidence"] },
    outcome: { enum: ["ready"] },
    summary: { type: "string", minLength: 1, maxLength: 200 },
    payload: {
      type: "object",
      additionalProperties: false,
      required: ["paths"],
      properties: { paths: { type: "array", items: { type: "string" }, maxItems: 3 } },
    },
  },
};

test("validates the portable workflow schema subset", () => {
  assert.deepEqual(validateSchemaValue(schema, {
    artifactKind: "evidence",
    outcome: "ready",
    summary: "Relevant evidence",
    payload: { paths: ["specs/design.md"] },
  }), []);

  assert.match(
    validateSchemaValue(schema, {
      artifactKind: "evidence",
      outcome: "wrong",
      summary: "",
      payload: { paths: ["a", "b", "c", "d"], extra: true },
    }).join("\n"),
    /outcome|summary|maxItems|extra/,
  );
});

test("assigns artifact identity and only accepts earlier parents", () => {
  const store = new ArtifactStore("run-1", "refine-spec", () => "2026-07-28T00:00:00.000Z");
  const first = store.append("discover", "stage-1", [], {
    artifactKind: "evidence",
    outcome: "ready",
    summary: "Found the specification",
    payload: { paths: ["specs/design.md"] },
  });
  const second = store.append("synthesize", "stage-2", [first.artifactId], {
    artifactKind: "evidence",
    outcome: "ready",
    summary: "Combined evidence",
    payload: { paths: ["specs/design.md"] },
  });

  assert.equal(first.artifactId, "run-1:1");
  assert.deepEqual(second.parentArtifactIds, [first.artifactId]);
  assert.throws(() => store.append("bad", "stage-3", ["missing"], {
    artifactKind: "evidence",
    outcome: "ready",
    summary: "Bad parent",
    payload: {},
  }), /Unknown parent artifact/);
  assert.throws(() => store.append("again", "stage-2", [], {
    artifactKind: "evidence",
    outcome: "ready",
    summary: "Duplicate invocation",
    payload: {},
  }), /already produced/);
});

test("builds a bounded catalog without artifact payloads", () => {
  const store = new ArtifactStore("run-2", "refine-spec");
  const artifact = store.append("audit", "stage-1", [], {
    artifactKind: "issue-queue",
    outcome: "issues",
    summary: "One design issue",
    payload: { secret: "large payload" },
  });

  assert.deepEqual(store.catalog(), [{
    artifactId: artifact.artifactId,
    artifactKind: "issue-queue",
    stageType: "audit",
    summary: "One design issue",
    parentArtifactIds: [],
  }]);
});
