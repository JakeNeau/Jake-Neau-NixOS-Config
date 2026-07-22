import assert from "node:assert/strict";
import {
  cp,
  mkdir,
  mkdtemp,
  readFile,
  rename,
  symlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { compileGlobalRegistry } from "../registry.mjs";
import { createLinkRuntime } from "../runtime.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const fixtures = join(here, "fixtures");

async function projectFixture(name = "project") {
  const root = await mkdtemp(join(tmpdir(), "pi-link-runtime-project-"));
  await cp(join(fixtures, name), root, { recursive: true });
  return root;
}

async function globalManifest(root) {
  const registry = await compileGlobalRegistry({
    skillRoots: [join(fixtures, "global", "skills")],
    commandRoots: [join(fixtures, "global", "commands")],
  });
  const path = join(root, "global.json");
  await writeFile(path, `${JSON.stringify(registry)}\n`, "utf8");
  return path;
}

test("scans a trusted project from the nearest git ancestor", async () => {
  const root = await projectFixture();
  await writeFile(join(root, ".git"), "gitdir: elsewhere\n", "utf8");
  const nested = join(root, "src", "nested");
  await mkdir(nested, { recursive: true });
  const manifest = await globalManifest(root);

  const runtime = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: nested,
    projectTrusted: true,
    configDirName: ".pi",
  });

  assert.equal(runtime.projectRegistry.projectRoot, root);
  assert.equal(runtime.summary().project, 7);
  assert.equal(runtime.summary().global, 3);
});

test("uses cwd outside git and skips project scanning when untrusted", async () => {
  const root = await projectFixture();
  const manifest = await globalManifest(root);
  const trusted = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: root,
    projectTrusted: true,
    configDirName: ".pi",
  });
  const untrusted = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: root,
    projectTrusted: false,
    configDirName: ".pi",
  });

  assert.equal(trusted.projectRegistry.projectRoot, root);
  assert.equal(untrusted.projectRegistry, null);
  assert.equal(untrusted.summary().project, 0);
});

test("isolates missing, malformed, and incompatible global manifests", async () => {
  const root = await projectFixture();
  const malformed = join(root, "malformed.json");
  const incompatible = join(root, "incompatible.json");
  await writeFile(malformed, "not json", "utf8");
  await writeFile(incompatible, JSON.stringify({ version: 999 }), "utf8");

  for (const path of [join(root, "missing.json"), malformed, incompatible]) {
    const runtime = await createLinkRuntime({
      globalRegistryPath: path,
      cwd: root,
      projectTrusted: true,
      configDirName: ".pi",
    });
    assert.equal(runtime.globalRegistry, null);
    assert.equal(runtime.summary().project, 7);
    assert.equal(runtime.summary().diagnostics > 0, true);
  }
});

test("reports ambiguity and refreshes changed project content", async () => {
  const root = await projectFixture();
  const manifest = await globalManifest(root);
  await mkdir(join(root, ".agents", "skills", "comments"), { recursive: true });
  await writeFile(
    join(root, ".agents", "skills", "comments", "SKILL.md"),
    "---\nname: comments\ndescription: Project comments\n---\n# Project comments\n",
    "utf8",
  );
  const runtime = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: root,
    projectTrusted: true,
    configDirName: ".pi",
  });

  assert.equal(runtime.inspect("skill:comments").status, "ambiguous");
  const path = join(root, "docs", "reference", "pi.md");
  await writeFile(path, "# Updated reference\n", "utf8");
  const result = await runtime.follow("project:doc:reference/pi");
  assert.equal(result.details.status, "resolved");
  assert.match(result.text, /Updated reference/);
});

test("revalidates project containment immediately before loading", async () => {
  const root = await projectFixture();
  const manifest = await globalManifest(root);
  const runtime = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: root,
    projectTrusted: true,
    configDirName: ".pi",
  });
  const outside = await mkdtemp(join(tmpdir(), "pi-link-runtime-outside-"));
  const outsideFile = join(outside, "pi.md");
  await writeFile(outsideFile, "# Outside\n", "utf8");
  const target = join(root, "docs", "reference", "pi.md");
  await rename(target, `${target}.original`);
  await symlink(outsideFile, target);

  const result = await runtime.follow("project:doc:reference/pi");
  assert.equal(result.details.status, "outside-root");
  assert.doesNotMatch(result.text, /# Outside/);
});

test("keeps valid project resources available beside diagnostics", async () => {
  const root = await projectFixture("project-duplicate");
  await mkdir(join(root, "docs"), { recursive: true });
  await writeFile(join(root, "docs", "valid.md"), "# Valid\n", "utf8");
  const manifest = await globalManifest(root);
  const runtime = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: root,
    projectTrusted: true,
    configDirName: ".pi",
  });

  assert.equal(runtime.summary().diagnostics > 0, true);
  assert.equal((await runtime.follow("doc:valid")).details.status, "resolved");
});

test("decorates ordinary reads using their origin layer exactly once", async () => {
  const root = await projectFixture();
  const manifest = await globalManifest(root);
  const runtime = await createLinkRuntime({
    globalRegistryPath: manifest,
    cwd: root,
    projectTrusted: true,
    configDirName: ".pi",
  });
  const projectPath = join(root, "notes.md");
  const projectText = "Read [[doc:reference/pi]] and ignore [[agent:writer]].";
  await writeFile(projectPath, projectText, "utf8");
  const globalPath = join(fixtures, "global", "skills", "comments", "SKILL.md");
  const globalText = await readFile(globalPath, "utf8");

  const projectDecorated = await runtime.decorateRead(projectPath, projectText);
  assert.match(projectDecorated, /project:doc:reference\/pi/);
  assert.doesNotMatch(projectDecorated, /\[\[agent:writer\]\] →/);
  assert.equal(
    (projectDecorated.match(/\[pi-typed-links\]/g) ?? []).length,
    1,
  );
  assert.match(await runtime.decorateRead(globalPath, globalText), /global:skill:diataxis/);
});
