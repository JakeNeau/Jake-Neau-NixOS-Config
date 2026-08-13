import assert from "node:assert/strict";
import { mkdtemp, mkdir, realpath, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import { approvedTargets } from "../paths.ts";

test("accepts approved files inside the canonical specification root", async () => {
  const root = await mkdtemp(join(tmpdir(), "workflow-paths-"));
  await mkdir(join(root, "specs"));
  assert.deepEqual(
    approvedTargets(root, "specs", ["specs/design.md"]),
    [join(await realpath(root), "specs", "design.md")],
  );
});

test("rejects lexical and symlink escapes from the specification root", async () => {
  const root = await mkdtemp(join(tmpdir(), "workflow-paths-"));
  await mkdir(join(root, "specs"));
  await mkdir(join(root, "outside"));
  await symlink(join(root, "outside"), join(root, "specs", "escape"));

  assert.throws(() => approvedTargets(root, "specs", ["outside/design.md"]), /outside/);
  assert.throws(() => approvedTargets(root, "specs", ["specs/escape/design.md"]), /outside/);
});
