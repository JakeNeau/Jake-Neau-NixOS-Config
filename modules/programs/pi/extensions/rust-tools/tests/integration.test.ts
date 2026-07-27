import assert from "node:assert/strict";
import { access, cp, mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { CodeLldbSession } from "../dap.ts";
import { createRustDebugger } from "../debugger.ts";
import { createRustIntelligence } from "../intelligence.ts";
import { RustAnalyzerSession } from "../lsp.ts";
import { buildDebugTarget, discoverRustProject } from "../project.ts";

const fixture = join(dirname(fileURLToPath(import.meta.url)), "fixtures", "workspace");
const source = join(fixture, "crates", "demo", "src", "lib.rs");

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required for live Rust integration tests`);
  return value;
}

function runtime() {
  return {
    cargoPath: required("TEST_CARGO"),
    rustcPath: required("TEST_RUSTC"),
    nixPath: process.env.TEST_NIX,
    timeoutMs: 180_000,
  };
}

function fakePi() {
  const tools: Array<Record<string, any>> = [];
  const handlers = new Map<string, Array<(event: any, ctx: any) => unknown>>();
  return {
    tools,
    handlers,
    api: {
      registerTool(tool: Record<string, any>) { tools.push(tool); },
      on(name: string, handler: (event: any, ctx: any) => unknown) {
        handlers.set(name, [...(handlers.get(name) ?? []), handler]);
      },
    },
  };
}

function resultText(result: any): string {
  return result.content.find((item: any) => item.type === "text")?.text ?? "";
}

test("real rust-analyzer resolves Rust structure and diagnostics", { timeout: 180_000 }, async (context) => {
  const root = await mkdtemp(join(tmpdir(), "pi-rust-analyzer-"));
  await cp(fixture, root, { recursive: true });
  const copiedSource = join(root, "crates", "demo", "src", "lib.rs");
  const original = await readFile(copiedSource, "utf8");
  await writeFile(copiedSource, `${original}\npub fn broken() { let value: i32 = "wrong"; }\n`);
  const analyzer = await RustAnalyzerSession.start({
    executable: required("TEST_RUST_ANALYZER"),
    cwd: root,
    env: { ...process.env, RUSTC: required("TEST_RUSTC") },
    timeoutMs: 60_000,
  });
  context.after(() => analyzer.close());

  const symbols = await analyzer.symbols("debug_value");
  const symbol = symbols.find((item) => item.name === "debug_value");
  assert.ok(symbol);
  const callPoint = { path: copiedSource, line: 2, column: 5 };
  assert.equal((await analyzer.definition(callPoint)).some((item) => item.path === copiedSource), true);
  assert.match((await analyzer.hover(callPoint))?.text ?? "", /fn debug_value/);
  assert.ok((await analyzer.references(callPoint)).length >= 2);
  const definitionPoint = {
    path: symbol.path,
    line: symbol.range.start.line,
    column: symbol.range.start.column,
  };
  assert.ok((await analyzer.callers(definitionPoint)).incoming.some((item) => item.name === "compute"));

  await analyzer.hover({ path: copiedSource, line: 10, column: 8 });
  const deadline = Date.now() + 60_000;
  while (!analyzer.diagnostics(copiedSource).some((item) => item.message.includes("mismatched types")) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.equal(analyzer.diagnostics(copiedSource).some((item) => item.message.includes("mismatched types")), true);
});

test("real CodeLLDB stops in a Cargo test and reads the decisive value", { timeout: 180_000 }, async (context) => {
  const project = await discoverRustProject({ cwd: fixture, runtime: runtime() });
  const built = await buildDebugTarget(project, {
    package: "demo",
    target: "regression",
    kind: "test",
    testFilter: "computes_the_decisive_value",
  }, runtime());
  await access(built.executable);

  const debuggerSession = await CodeLldbSession.start({
    executable: required("TEST_CODELLDB"),
    cwd: fixture,
    env: process.env,
    timeoutMs: 30_000,
  });
  context.after(() => debuggerSession.close());
  const stopped = await debuggerSession.launch({
    program: built.executable,
    cwd: fixture,
    args: built.args,
    env: {},
    breakpoints: [{ path: source, line: 6 }],
  });
  assert.equal(stopped.reason, "breakpoint");
  assert.ok(stopped.threadId);
  const stepped = await debuggerSession.next(stopped.threadId!);
  assert.equal(stepped.reason, "step");
  assert.ok(stepped.threadId);

  const stack = await debuggerSession.stackTrace(stepped.threadId!);
  assert.equal(stack.frames.some((item) => item.name.includes("debug_value")), true);
  const frame = stack.frames.find((item) => item.name.includes("debug_value"))!;
  const scopes = await debuggerSession.scopes(frame.id);
  const locals = scopes.find((item) => item.name.toLowerCase().includes("local")) ?? scopes[0];
  const variables = await debuggerSession.variables(locals.variablesReference);
  const decisive = variables.find((item) => item.name === "decisive");
  assert.ok(decisive);
  assert.match(decisive.value, /42/);
  const resumed = await debuggerSession.continue(stepped.threadId!);
  assert.equal(resumed.terminated, true);
});

test("real extension factories provide focused context and autonomous debugging", { timeout: 240_000 }, async (context) => {
  const pi = fakePi();
  createRustIntelligence({
    rustAnalyzerPath: required("TEST_RUST_ANALYZER"),
    cargoPath: required("TEST_CARGO"),
    rustcPath: required("TEST_RUSTC"),
    nixPath: process.env.TEST_NIX,
    timeoutMs: 60_000,
    maxBytes: 12_000,
  })(pi.api as any);
  createRustDebugger({
    codeLldbPath: required("TEST_CODELLDB"),
    cargoPath: required("TEST_CARGO"),
    rustcPath: required("TEST_RUSTC"),
    nixPath: process.env.TEST_NIX,
    timeoutMs: 60_000,
  })(pi.api as any);
  context.after(async () => {
    for (const handler of pi.handlers.get("session_shutdown") ?? []) await handler({}, {});
  });

  const rustCode = pi.tools.find((item) => item.name === "rust_code")!;
  const codeContext = await rustCode.execute("code", {
    action: "context",
    query: "debug regression debug_value decisive",
  }, undefined, undefined, { cwd: fixture, isProjectTrusted: () => true });
  assert.match(resultText(codeContext), /Debugging the regression/);
  assert.equal(codeContext.details.symbols.some((item: any) => item.name === "debug_value"), true);

  const debugStart = pi.tools.find((item) => item.name === "rust_debug_start")!;
  const toolContext = { cwd: fixture, isProjectTrusted: () => true };
  const started = await debugStart.execute("start", {
    goal: "debug the documented regression and inspect decisive",
    package: "demo",
    target: "regression",
    targetKind: "test",
    testFilter: "computes_the_decisive_value",
  }, undefined, undefined, toolContext);
  assert.equal(started.details.status, "stopped");
  assert.equal(started.details.documents.some((item: any) => item.path === "docs/debugging.md"), true);

  const debug = pi.tools.find((item) => item.name === "rust_debug")!;
  await debug.execute("break", { action: "breakpoint", path: "@crates/demo/src/lib.rs", line: 6 }, undefined, undefined, toolContext);
  const stopped = await debug.execute("continue", { action: "continue" }, undefined, undefined, toolContext);
  assert.equal(stopped.details.value.reason, "breakpoint");
  const stepped = await debug.execute("step", { action: "step_over" }, undefined, undefined, toolContext);
  assert.equal(stepped.details.value.reason, "step");
  const stack = await debug.execute("stack", { action: "stack" }, undefined, undefined, toolContext);
  const frame = stack.details.value.frames.find((item: any) => item.name.includes("debug_value"));
  assert.ok(frame);
  const scopes = await debug.execute("scopes", { action: "scopes", frameId: frame.id }, undefined, undefined, toolContext);
  const locals = scopes.details.value.find((item: any) => item.name.toLowerCase().includes("local"));
  const variables = await debug.execute("variables", {
    action: "variables",
    variablesReference: locals.variablesReference,
  }, undefined, undefined, toolContext);
  const decisive = variables.details.value.find((item: any) => item.name === "decisive");
  assert.ok(decisive, JSON.stringify(variables.details.value));
  assert.match(decisive.value, /42/);
  await debug.execute("stop", { action: "stop" }, undefined, undefined, toolContext);
});
