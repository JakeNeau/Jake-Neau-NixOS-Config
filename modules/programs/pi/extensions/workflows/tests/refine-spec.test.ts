import assert from "node:assert/strict";
import { test } from "node:test";

import {
  chooseSpecificationLocation,
  fingerprintIssue,
  suppressSkippedIssues,
} from "../refine-spec.ts";

test("prefers documented specification authority and warns about split locations", () => {
  const result = chooseSpecificationLocation([
    { path: "specs", evidence: "docs/README.md names this directory", documented: true, fileCount: 2 },
    { path: "design", evidence: "directory name heuristic", documented: false, fileCount: 10 },
  ]);

  assert.equal(result.path, "specs");
  assert.match(result.warning ?? "", /several specification locations/);
});

test("requires a user decision when no location has adequate evidence", () => {
  const result = chooseSpecificationLocation([
    { path: "notes", evidence: "one markdown file", documented: false, fileCount: 1 },
    { path: "ideas", evidence: "one markdown file", documented: false, fileCount: 1 },
  ]);

  assert.equal(result.path, undefined);
  assert.equal(result.needsUser, true);
});

test("suppresses an unchanged skipped issue but restores it when evidence changes", () => {
  const issue = {
    title: "Undefined workflow stop behavior",
    claim: "The specification does not define stop behavior.",
    evidence: [{ path: "specs/pi-workflows.md", excerpt: "workflow stop" }],
  };
  const skipped = new Set([fingerprintIssue(issue)]);

  assert.deepEqual(suppressSkippedIssues([issue], skipped), []);
  assert.equal(suppressSkippedIssues([
    { ...issue, evidence: [{ path: "specs/pi-workflows.md", excerpt: "different evidence" }] },
  ], skipped).length, 1);
});
