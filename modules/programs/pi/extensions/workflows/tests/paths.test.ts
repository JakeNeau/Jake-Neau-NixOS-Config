import assert from "node:assert/strict";
import { mkdtemp, mkdir, realpath, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import { approvedPlanTargets, approvedTargets } from "../paths.ts";

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

test("accepts a plan beside its specification at arbitrary depth", async () => {
  const root = await mkdtemp(join(tmpdir(), "workflow-paths-"));
  await mkdir(join(root, "specs", "services", "auth"), { recursive: true });
  await writeFile(join(root, "specs", "services", "auth", "session.md"), "# Session\n");

  assert.deepEqual(
    approvedPlanTargets(
      root,
      "specs",
      "specs/services/auth/session.md",
      ["specs/services/auth/session.plan.md"],
    ),
    [join(await realpath(root), "specs", "services", "auth", "session.plan.md")],
  );
});

test("rejects a plan without an existing specification", async () => {
  const root = await mkdtemp(join(tmpdir(), "workflow-paths-"));
  await mkdir(join(root, "specs"));

  assert.throws(
    () => approvedPlanTargets(root, "specs", "specs/missing.md", ["specs/missing.plan.md"]),
    /does not exist/,
  );
});

test("rejects a plan outside its specification directory", async () => {
  const root = await mkdtemp(join(tmpdir(), "workflow-paths-"));
  await mkdir(join(root, "specs", "services", "auth"), { recursive: true });
  await mkdir(join(root, "specs", "plans"), { recursive: true });
  await writeFile(join(root, "specs", "services", "auth", "session.md"), "# Session\n");

  assert.throws(
    () => approvedPlanTargets(
      root,
      "specs",
      "specs/services/auth/session.md",
      ["specs/plans/session.md"],
    ),
    /same directory/,
  );
});
