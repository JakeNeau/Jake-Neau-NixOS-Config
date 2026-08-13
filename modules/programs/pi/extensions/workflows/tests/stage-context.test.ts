import assert from "node:assert/strict";
import { test } from "node:test";

import type { WorkflowArtifact } from "../artifacts.ts";
import {
  fitEvidenceStageContext,
  MAX_STAGE_CONTEXT_BYTES,
  serializeStageContext,
} from "../stage-context.ts";

function evidence(lens: string, index: number): WorkflowArtifact {
  return {
    schemaVersion: 1,
    runId: "run-1",
    artifactId: `artifact-${index}`,
    workflow: "refine-spec",
    stageType: "investigate",
    stageInvocationId: `stage-${index}`,
    parentArtifactIds: ["context", "focus"],
    createdAt: "2026-08-13T00:00:00.000Z",
    artifactKind: "evidence",
    outcome: "ready",
    summary: `${lens} evidence`,
    payload: {
      lens,
      findings: Array.from({ length: 16 }, (_, finding) => ({
        claim: `Claim ${finding} ${"c".repeat(300)}`,
        path: `docs/${lens}-${finding}.md`,
        excerpt: `Excerpt ${finding} ${"e".repeat(600)}`,
        meaning: `Meaning ${finding} ${"m".repeat(300)}`,
      })),
      constraints: Array.from({ length: 12 }, (_, constraint) => `Constraint ${constraint} ${"c".repeat(300)}`),
      openQuestions: Array.from({ length: 12 }, (_, question) => `Question ${question} ${"q".repeat(300)}`),
    },
  };
}

test("serializes stage context as compact JSON", () => {
  const serialized = serializeStageContext({ iteration: "focus" }, [evidence("specification", 1)]);

  assert.equal(serialized.includes("\n"), false);
  assert.equal(serialized, JSON.stringify(JSON.parse(serialized)));
});

test("compacts oversized synthesis evidence without changing stored artifacts", () => {
  const artifacts = [
    evidence("specification", 1),
    evidence("documentation", 2),
    evidence("implementation", 3),
    evidence("verification", 4),
  ];
  const originalExcerpt = ((artifacts[0].payload as any).findings[0] as any).excerpt;
  assert.ok(Buffer.byteLength(serializeStageContext({}, artifacts)) > MAX_STAGE_CONTEXT_BYTES);

  const fitted = fitEvidenceStageContext({}, artifacts);

  assert.equal(fitted.compacted, true);
  assert.ok(Buffer.byteLength(fitted.serialized) <= MAX_STAGE_CONTEXT_BYTES);
  assert.equal(((artifacts[0].payload as any).findings[0] as any).excerpt, originalExcerpt);
  const compactFinding = ((fitted.artifacts[0].payload as any).findings[0] as any);
  assert.equal(compactFinding.excerpt, undefined);
  assert.match(compactFinding.claim, /^Claim 0/);
  assert.equal(compactFinding.path, "docs/specification-0.md");
  assert.match(compactFinding.meaning, /^Meaning 0/);
});
