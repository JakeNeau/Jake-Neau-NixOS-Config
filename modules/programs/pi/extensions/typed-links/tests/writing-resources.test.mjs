import assert from "node:assert/strict";
import test from "node:test";

import { compileGlobalRegistry } from "../registry.mjs";

const sharedSkills = process.env.TEST_SHARED_SKILLS;
const piSkills = process.env.TEST_PI_SKILLS;
const piCommands = process.env.TEST_PI_COMMANDS;

test("compiles the writing policy graph", async () => {
  assert.ok(sharedSkills);
  assert.ok(piSkills);
  assert.ok(piCommands);

  const registry = await compileGlobalRegistry({
    skillRoots: [sharedSkills, piSkills],
    commandRoots: [piCommands],
  });
  const ids = new Set(registry.entries.map((entry) => entry.id));

  for (const id of [
    "global:skill:writing",
    "global:skill:writing-substance",
    "global:skill:controlled-writing",
    "global:command:writing-review",
  ]) {
    assert.ok(ids.has(id), `missing ${id}`);
  }

  const writing = registry.entries.find(
    (entry) => entry.id === "global:skill:writing",
  );
  assert.ok(writing.links.length >= 3);
  assert.ok(writing.links.every((link) => link.status === "resolved"));
  assert.ok(
    writing.links.every((link) => link.targetId?.startsWith("global:")),
  );
});
