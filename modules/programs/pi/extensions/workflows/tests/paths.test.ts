import assert from "node:assert/strict";
import { mkdtemp, mkdir, realpath, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import { approvedPlanTargets, approvedTargets, RefinementTargetError } from "../paths.ts";

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

  for (const path of ["outside/design.md", "specs/escape/design.md"]) {
    assert.throws(
      () => approvedTargets(root, "specs", [path]),
      (error) => {
        assert.ok(error instanceof RefinementTargetError);
        assert.match(error.message, /outside the specification location/);
        assert.match(error.correctiveAction, /only specification files under specs/);
        assert.match(error.correctiveAction, /design or integration text/);
        return true;
      },
    );
  }
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
    (error) => {
      assert.ok(error instanceof RefinementTargetError);
      assert.match(error.message, /same directory/);
      assert.match(error.correctiveAction, /beside its existing specification/);
      return true;
    },
  );
});
