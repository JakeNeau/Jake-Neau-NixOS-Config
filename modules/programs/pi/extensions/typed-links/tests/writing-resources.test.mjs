import assert from "node:assert/strict";
import { realpath } from "node:fs/promises";
import { isAbsolute, relative, sep } from "node:path";
import test from "node:test";

import { compileGlobalRegistry } from "../registry.mjs";

const piSkills = process.env.TEST_PI_SKILLS;
const piCommands = process.env.TEST_PI_COMMANDS;

// Pi's complete global surface. Kept exhaustive on purpose: a foreign resource
// dropped into one of Pi's own roots sits at a legitimate path, so the path
// check below cannot see it and only this list will fail.
const EXPECTED_IDS = [
  "global:command:comment-review",
  "global:command:writing-review",
  "global:skill:comment-api-contracts",
  "global:skill:comment-disabled-code",
  "global:skill:comment-functional-directives",
  "global:skill:comment-intent-rationale",
  "global:skill:comment-invariants",
  "global:skill:comment-provenance",
  "global:skill:comment-redundant-narration",
  "global:skill:comment-structural-markers",
  "global:skill:comment-task-markers",
  "global:skill:comment-workarounds",
  "global:skill:comments",
  "global:skill:controlled-writing",
  "global:skill:diataxis",
  "global:skill:documentation",
  "global:skill:ui-system-initializer",
  "global:skill:writing",
  "global:skill:writing-pi-extensions",
  "global:skill:writing-substance",
];

function isUnder(root, target) {
  const rel = relative(root, target);
  return rel !== "" && rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel);
}

test("compiles the Pi policy graph", async () => {
  assert.ok(piSkills);
  assert.ok(piCommands);

  const registry = await compileGlobalRegistry({
    skillRoots: [piSkills],
    commandRoots: [piCommands],
  });

  // The scanner reports an unreadable resource as a diagnostic and then skips
  // it, so without this the checks below pass over a silently dropped file.
  assert.deepEqual(registry.diagnostics, []);

  assert.deepEqual(
    registry.entries.map((entry) => entry.id),
    EXPECTED_IDS,
    "Pi's global surface changed. Add the intended id, or remove the intruder.",
  );

  // Every entry must also live inside a declared root. This catches a resource
  // reached through a root but stored elsewhere, through a symlink for example,
  // because registry.mjs records the realpath. Resolve the roots the same way
  // or every store path looks like an escape.
  const roots = await Promise.all(
    [piSkills, piCommands].map((root) => realpath(root)),
  );
  for (const entry of registry.entries) {
    assert.ok(
      roots.some((root) => isUnder(root, entry.path)),
      `resource outside Pi's own roots: ${entry.id} at ${entry.path}`,
    );
  }

  assert.deepEqual(
    registry.entries.flatMap((entry) => entry.links.filter((link) => (
      link.status !== "resolved"
    )).map((link) => `${entry.id}: ${link.raw}`)),
    [],
    "Pi global resources must not contain unresolved typed links",
  );

  const writing = registry.entries.find(
    (entry) => entry.id === "global:skill:writing",
  );
  assert.ok(writing.links.length >= 3);
  assert.ok(writing.links.every((link) => link.status === "resolved"));

  const documentation = registry.entries.find(
    (entry) => entry.id === "global:skill:documentation",
  );
  assert.deepEqual(
    documentation.links.map((link) => link.targetId),
    ["global:skill:diataxis"],
  );
});
