import assert from "node:assert/strict";
import { access, cp, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  buildDebugTarget,
  collectCargoDiagnostics,
  discoverRustProject,
  listDebugTargets,
  searchProjectDocs,
} from "../project.ts";

const fixture = join(dirname(fileURLToPath(import.meta.url)), "fixtures", "workspace");
const cargoPath = process.env.TEST_CARGO ?? "cargo";
const rustcPath = process.env.TEST_RUSTC ?? "rustc";

function runtime() {
  return { cargoPath, rustcPath, timeoutMs: 120_000 };
}

test("discovers an ancestor workspace and its documented targets", async () => {
  const project = await discoverRustProject({
    cwd: join(fixture, "crates", "demo", "src"),
    runtime: runtime(),
  });

  assert.equal(project.root, fixture);
  assert.equal(project.packages.map((item) => item.name).includes("demo"), true);
  assert.equal(project.documents.some((item) => item.path.endsWith("docs/debugging.md")), true);
  assert.equal(project.documents.some((item) => item.text.includes("forbidden-marker")), true);
  await assert.rejects(access(join(fixture, "forbidden-marker")));

  const targets = listDebugTargets(project);
  assert.equal(targets.some((item) => item.package === "demo" && item.name === "demo" && item.kind === "bin"), true);
  assert.equal(targets.some((item) => item.package === "demo" && item.name === "regression" && item.kind === "test"), true);
});

test("prepends the declarative tool path to Cargo execution", async () => {
  const project = await discoverRustProject({
    cwd: fixture,
    runtime: { ...runtime(), toolPath: "/declarative/bin" },
  });
  assert.match(project.cargo.env.PATH ?? "", /^\/declarative\/bin:/);
});

test("lets a documented Nix development shell provide the Rust toolchain", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-nix-cargo-"));
  await cp(fixture, root, { recursive: true });
  await writeFile(join(root, "README.md"), "Run `nix develop .#rust --command cargo test`.\n");
  const project = await discoverRustProject({
    cwd: root,
    runtime: { ...runtime(), nixPath: "/nix/store/nix/bin/nix" },
  });
  assert.equal(project.cargo.executable, "/nix/store/nix/bin/nix");
  assert.deepEqual(project.cargo.argsPrefix, ["develop", ".#rust", "--command", "cargo"]);
  assert.notEqual(project.cargo.env.RUSTC, rustcPath);
});

test("invalidates cached documentation when a file changes", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-doc-cache-"));
  await cp(fixture, root, { recursive: true });
  const path = join(root, "docs", "debugging.md");
  const first = await discoverRustProject({ cwd: root, runtime: runtime() });
  assert.ok(searchProjectDocs(first, "decisive", { maxResults: 2, maxBytes: 2000 }).length > 0);
  await new Promise((resolve) => setTimeout(resolve, 10));
  await writeFile(path, "# Different guidance\n\nInspect the sentinel branch.\n");
  const second = await discoverRustProject({ cwd: root, runtime: runtime() });
  const excerpts = searchProjectDocs(second, "sentinel", { maxResults: 2, maxBytes: 2000 });
  assert.equal(excerpts[0].heading, "Different guidance");
});

test("ranks task-specific documentation by heading and prose", async () => {
  const project = await discoverRustProject({ cwd: fixture, runtime: runtime() });
  const excerpts = searchProjectDocs(project, "debug regression decisive value", {
    maxResults: 3,
    maxBytes: 4000,
  });

  assert.ok(excerpts.length > 0);
  assert.match(excerpts[0].path, /docs\/debugging\.md$/);
  assert.match(excerpts[0].text, /breakpoint in `debug_value`/);
});

test("builds and selects a Cargo binary artifact", async () => {
  const project = await discoverRustProject({ cwd: fixture, runtime: runtime() });
  const built = await buildDebugTarget(project, {
    package: "demo",
    target: "demo",
    kind: "bin",
  }, runtime());

  assert.equal(built.target.kind, "bin");
  await access(built.executable);
});

test("collects structured Cargo diagnostics", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-rust-project-"));
  await cp(fixture, root, { recursive: true });
  const source = join(root, "crates", "demo", "src", "lib.rs");
  const original = await readFile(source, "utf8");
  await writeFile(source, `${original}\npub fn broken() { let value: i32 = "wrong"; }\n`);

  const project = await discoverRustProject({ cwd: root, runtime: runtime() });
  const diagnostics = await collectCargoDiagnostics(project, runtime());

  assert.equal(diagnostics.some((item) => item.level === "error" && item.message.includes("mismatched types")), true);
  assert.equal(diagnostics.some((item) => item.path.endsWith("src/lib.rs") && item.line !== undefined), true);
});

test("rejects directories outside a Cargo workspace", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-no-cargo-"));
  await assert.rejects(
    discoverRustProject({ cwd: root, runtime: runtime() }),
    /Cargo workspace/,
  );
});
