import assert from "node:assert/strict";
import test from "node:test";

import { countPatchChanges, diffSummary } from "../core.ts";

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
