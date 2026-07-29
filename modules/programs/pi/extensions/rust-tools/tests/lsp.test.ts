import assert from "node:assert/strict";
import { cp, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { test } from "node:test";

import { RustAnalyzerSession } from "../lsp.ts";

const here = dirname(fileURLToPath(import.meta.url));
const source = join(here, "fixtures", "workspace", "crates", "demo", "src", "lib.rs");
const server = join(here, "fixtures", "fake-lsp.mjs");

async function start(timeoutMs = 500) {
  return RustAnalyzerSession.start({
    executable: process.execPath,
    args: [server],
    cwd: join(here, "fixtures", "workspace"),
    env: { ...process.env, FAKE_SOURCE_URI: pathToFileURL(source).href },
    timeoutMs,
    // A generous startup budget keeps a tiny timeoutMs scoped to the request under test.
    readyTimeoutMs: 30_000,
  });
}

test("performs structural LSP queries and preserves source ranges", async (context) => {
  const session = await start();
  context.after(() => session.close());
  const symbols = await session.symbols("debug_value");
  assert.equal(symbols.length, 2);
  assert.equal(symbols[0].path, source);
  assert.equal(symbols[0].range.start.line, 5);

  const point = { path: source, line: 5, column: 8 };
  const definitions = await session.definition(point);
  assert.equal(definitions[0].range.start.line, 5);
  assert.match((await session.hover(point))?.text ?? "", /fn debug_value/);
  assert.equal((await session.references(point)).length, 2);

  const calls = await session.callers(point);
  assert.equal(calls.incoming[0].name, "compute");
  assert.equal(calls.outgoing[0].name, "add");
  await session.close();
  await session.close();
});

test("synchronizes source changes after a document is opened", async (context) => {
  const root = await mkdtemp(join(tmpdir(), "pi-lsp-change-"));
  const changedSource = join(root, "lib.rs");
  await cp(source, changedSource);
  const session = await RustAnalyzerSession.start({
    executable: process.execPath,
    args: [server],
    cwd: root,
    env: { ...process.env, FAKE_SOURCE_URI: pathToFileURL(changedSource).href },
    timeoutMs: 500,
  });
  context.after(() => session.close());
  const point = { path: changedSource, line: 5, column: 8 };
  assert.match((await session.hover(point))?.text ?? "", /debug_value/);
  await writeFile(changedSource, `${await readFile(changedSource, "utf8")}\nfn changed_marker() -> i32 { 1 }\n`);
  assert.match((await session.hover(point))?.text ?? "", /changed_marker/);
});

test("captures asynchronous diagnostics", async (context) => {
  const session = await start();
  context.after(() => session.close());
  const deadline = Date.now() + 1000;
  while (session.diagnostics(source).length === 0 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  const diagnostics = session.diagnostics(source);
  assert.equal(diagnostics[0].message, "fake diagnostic");
  assert.equal(diagnostics[0].range.start.line, 6);
});

test("reports rust-analyzer spawn failures", async () => {
  await assert.rejects(
    RustAnalyzerSession.start({
      executable: "/definitely/missing/rust-analyzer",
      cwd: here,
      timeoutMs: 100,
    }),
    /ENOENT|no such file/i,
  );
});

test("times out unanswered language-server requests", async (context) => {
  const session = await start(30);
  context.after(() => session.close());
  await assert.rejects(session.symbols("timeout"), /timed out/);
});
