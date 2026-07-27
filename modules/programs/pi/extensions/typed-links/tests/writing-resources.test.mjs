import assert from "node:assert/strict";
import test from "node:test";

import { compileGlobalRegistry } from "../registry.mjs";

const sharedSkills = process.env.TEST_SHARED_SKILLS;
const claudeSkills = process.env.TEST_CLAUDE_SKILLS;
const piSkills = process.env.TEST_PI_SKILLS;
const piCommands = process.env.TEST_PI_COMMANDS;

test("compiles the Pi policy graph", async () => {
  assert.ok(sharedSkills);
  assert.ok(claudeSkills);
  assert.ok(piSkills);
  assert.ok(piCommands);

  const registry = await compileGlobalRegistry({
    skillRoots: [sharedSkills, piSkills],
    commandRoots: [piCommands],
  });
  const ids = new Set(registry.entries.map((entry) => entry.id));
  const claudeRegistry = await compileGlobalRegistry({
    skillRoots: [claudeSkills],
    commandRoots: [],
  });

  for (const entry of claudeRegistry.entries) {
    assert.equal(ids.has(entry.id), false, `Claude-only resource leaked into Pi: ${entry.id}`);
  }

  for (const id of [
    "global:skill:writing",
    "global:skill:writing-substance",
    "global:skill:controlled-writing",
    "global:skill:documentation",
    "global:skill:diataxis",
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

  const documentation = registry.entries.find(
    (entry) => entry.id === "global:skill:documentation",
  );
  assert.deepEqual(
    documentation.links.map((link) => link.targetId),
    ["global:skill:diataxis"],
  );
});
