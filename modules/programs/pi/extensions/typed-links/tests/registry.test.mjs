import assert from "node:assert/strict";
import { cp, mkdtemp, mkdir, readFile, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  REGISTRY_VERSION,
  compileGlobalRegistry,
  compileProjectRegistry,
  extractTypedLinks,
  parseFrontmatter,
  refreshProjectEntry,
  resolveReference,
} from "../registry.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixtures = join(here, "fixtures");

async function copyFixture(name) {
  const root = await mkdtemp(join(tmpdir(), "pi-typed-links-"));
  await cp(join(fixtures, name), root, { recursive: true });
  return root;
}

test("compiles stable global metadata without resource bodies", async () => {
  const registry = await compileGlobalRegistry({
    skillRoots: [join(fixtures, "global", "skills")],
    commandRoots: [join(fixtures, "global", "commands")],
  });
  const comments = registry.entries.find(
    (entry) => entry.id === "global:skill:comments",
  );

  assert.equal(registry.version, REGISTRY_VERSION);
  assert.equal(registry.layer, "global");
  assert.equal(registry.projectRoot, null);
  assert.deepEqual(comments, {
    id: "global:skill:comments",
    type: "skill",
    name: "comments",
    layer: "global",
    path: join(fixtures, "global", "skills", "comments", "SKILL.md"),
    description: "Comment style",
    metadata: { name: "comments", description: "Comment style" },
    adapter: "skill",
    links: [{
      raw: "[[skill:diataxis]]",
      type: "skill",
      name: "diataxis",
      status: "resolved",
      targetId: "global:skill:diataxis",
    }],
    mtimeMs: null,
  });
  assert.deepEqual(
    registry.entries.map((entry) => entry.id),
    [...registry.entries.map((entry) => entry.id)].sort(),
  );
  assert.equal(JSON.stringify(registry).includes("# Comment style"), false);
  assert.equal(JSON.stringify(registry).includes("comment-writer"), false);
});

test("rejects duplicate and malformed global skills", async () => {
  await assert.rejects(
    compileGlobalRegistry({
      skillRoots: [
        join(fixtures, "duplicate", "one"),
        join(fixtures, "duplicate", "two"),
      ],
      commandRoots: [],
    }),
    /duplicate.*global:skill:comments/i,
  );
  await assert.rejects(
    compileGlobalRegistry({
      skillRoots: [join(fixtures, "malformed")],
      commandRoots: [],
    }),
    /description|name/i,
  );
});

test("scans all project roots and resolves only within the project layer", async () => {
  const root = await copyFixture("project");
  const registry = await compileProjectRegistry(root, { configDirName: ".pi" });

  assert.deepEqual(
    registry.entries.map((entry) => entry.id),
    [
      "project:command:check",
      "project:doc:cycles/a",
      "project:doc:cycles/b",
      "project:doc:reference/pi",
      "project:skill:pi-skill",
      "project:skill:project-skill",
      "project:spec:nested/design",
    ],
  );
  const doc = registry.entries.find(
    (entry) => entry.id === "project:doc:reference/pi",
  );
  assert.equal(doc.description, "Pi reference");
  assert.deepEqual(doc.links, [
    {
      raw: "[[spec:nested/design]]",
      type: "spec",
      name: "nested/design",
      status: "resolved",
      targetId: "project:spec:nested/design",
    },
    {
      raw: "[[doc:not-present]]",
      type: "doc",
      name: "not-present",
      status: "missing-target",
      targetId: undefined,
    },
  ]);
});

test("withholds every duplicate project entry", async () => {
  const root = await copyFixture("project-duplicate");
  const registry = await compileProjectRegistry(root, { configDirName: ".pi" });

  assert.equal(
    registry.entries.some((entry) => entry.id === "project:skill:collision"),
    false,
  );
  assert.equal(
    registry.diagnostics.some((diagnostic) => diagnostic.code === "duplicate-id"),
    true,
  );
});

test("reports escaping symlinks and terminates in-root symlink cycles", async () => {
  const root = await copyFixture("project");
  const outside = await mkdtemp(join(tmpdir(), "pi-typed-links-outside-"));
  await writeFile(join(outside, "outside.md"), "# Outside\n", "utf8");
  await symlink(outside, join(root, "docs", "outside"), "dir");
  await symlink(join(root, "docs"), join(root, "docs", "loop"), "dir");

  const registry = await compileProjectRegistry(root, { configDirName: ".pi" });

  assert.equal(
    registry.entries.some((entry) => entry.name.includes("outside")),
    false,
  );
  assert.equal(
    registry.diagnostics.some((diagnostic) => diagnostic.code === "outside-root"),
    true,
  );
  assert.equal(registry.entries.length, 7);
});

test("refreshes changed entries and rejects deleted targets", async () => {
  const root = await copyFixture("project");
  let registry = await compileProjectRegistry(root, { configDirName: ".pi" });
  const id = "project:doc:reference/pi";
  const path = join(root, "docs", "reference", "pi.md");
  await writeFile(path, "# Updated Pi reference\n\nSee [[doc:cycles/a]].\n", "utf8");

  const refreshed = await refreshProjectEntry(registry, id);
  assert.equal(refreshed.description, "Updated Pi reference");
  assert.equal(refreshed.links[0].targetId, "project:doc:cycles/a");

  registry = { ...registry, entries: registry.entries.filter((entry) => entry.id !== id) };
  await assert.rejects(refreshProjectEntry(registry, id), /not found/i);
});

test("resolves bracketed, short, canonical, ambiguous, and foreign references", async () => {
  const globalRegistry = await compileGlobalRegistry({
    skillRoots: [join(fixtures, "global", "skills")],
    commandRoots: [],
  });
  const projectRoot = await copyFixture("project");
  await mkdir(join(projectRoot, ".agents", "skills", "comments"), { recursive: true });
  await writeFile(
    join(projectRoot, ".agents", "skills", "comments", "SKILL.md"),
    "---\nname: comments\ndescription: Project comments\n---\n# Project comments\n",
    "utf8",
  );
  const projectRegistry = await compileProjectRegistry(projectRoot, {
    configDirName: ".pi",
  });

  assert.equal(resolveReference({ globalRegistry, projectRegistry, reference: "global:skill:comments" }).status, "resolved");
  assert.equal(resolveReference({ globalRegistry, projectRegistry, reference: "[[skill:diataxis]]" }).status, "resolved");
  assert.equal(resolveReference({ globalRegistry, projectRegistry, reference: "skill:comments" }).status, "ambiguous");
  assert.equal(resolveReference({ globalRegistry, projectRegistry, reference: "[[agent:writer]]" }).status, "foreign-type");
  assert.equal(resolveReference({ globalRegistry, projectRegistry, reference: "not a link" }).status, "malformed");
});

test("ignores typed-link examples inside Markdown code", () => {
  assert.deepEqual(
    extractTypedLinks("`[[skill:example]]`\n```text\n[[doc:example]]\n```\n[[skill:comments]]"),
    [{
      raw: "[[skill:comments]]",
      type: "skill",
      name: "comments",
      status: "pending",
      targetId: undefined,
    }],
  );
});

test("deduplicates repeated outgoing typed links", () => {
  assert.deepEqual(
    extractTypedLinks("See [[skill:comments]] and [[skill:comments]]."),
    [{
      raw: "[[skill:comments]]",
      type: "skill",
      name: "comments",
      status: "pending",
      targetId: undefined,
    }],
  );
});

test("parses plain, quoted, and block scalar frontmatter", () => {
  assert.deepEqual(
    parseFrontmatter("---\nname: sample\ndescription: >\n  first line\n  second line\nquoted: \"value\"\n---\n# Body\n"),
    {
      metadata: {
        name: "sample",
        description: "first line second line",
        quoted: "value",
      },
      body: "# Body\n",
    },
  );
});
