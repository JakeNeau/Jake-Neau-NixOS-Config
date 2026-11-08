import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile, realpath } from "node:fs/promises";
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
  "global:skill:brainstorming",
  "global:skill:diataxis",
  "global:skill:neovim",
  "global:skill:nix-config",
  "global:skill:pi-config",
  "global:skill:reading-documentation",
  "global:skill:system-config",
  "global:skill:writing",
  "global:skill:writing-code",
  "global:skill:writing-comments",
  "global:skill:writing-documentation",
  "global:skill:writing-pi-agents",
  "global:skill:writing-pi-extensions",
  "global:skill:writing-tests",
];

function isUnder(root, target) {
  const rel = relative(root, target);
  return rel !== "" && rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel);
}

function isStrictYamlFrontmatter(source) {
  const frontmatter = source.match(/^---\n([\s\S]*?)\n---\n/)?.[1] ?? "";
  try {
    execFileSync("yq", ["."], { input: frontmatter, stdio: ["pipe", "ignore", "ignore"] });
    return true;
  } catch {
    return false;
  }
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

  const linksOf = (id) => registry.entries
    .find((entry) => entry.id === id)
    .links.map((link) => link.targetId);
  assert.deepEqual(linksOf("global:skill:writing"), [
    "global:skill:writing-comments",
    "global:skill:writing-documentation",
  ]);
  assert.deepEqual(linksOf("global:skill:reading-documentation"), [
    "global:skill:diataxis",
    "global:skill:writing-documentation",
  ]);
  assert.deepEqual(linksOf("global:skill:writing-documentation"), [
    "global:skill:diataxis",
    "global:skill:reading-documentation",
    "global:skill:writing",
  ]);
});

// The registry parses frontmatter leniently, but Pi parses it as strict YAML
// and drops a resource it rejects, such as a plain scalar containing ": ".
test("Pi global resources have strict YAML frontmatter", async () => {
  const registry = await compileGlobalRegistry({
    skillRoots: [piSkills],
    commandRoots: [piCommands],
  });

  const sources = await Promise.all(registry.entries.map(async (entry) => (
    { id: entry.id, source: await readFile(entry.path, "utf8") }
  )));

  assert.deepEqual(
    sources.filter(({ source }) => !isStrictYamlFrontmatter(source)).map(({ id }) => id),
    [],
    "Pi rejects this frontmatter; use a folded (>) scalar for prose with colons",
  );
});
