import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { createRustIntelligence, resolveRustAnalyzerStart } from "../intelligence.ts";

const fixture = join(dirname(fileURLToPath(import.meta.url)), "fixtures", "workspace");
const source = join(fixture, "crates", "demo", "src", "lib.rs");

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

function fakeSession() {
  let closed = 0;
  const symbolQueries: string[] = [];
  const hoverPoints: any[] = [];
  return {
    get closed() { return closed; },
    symbolQueries,
    hoverPoints,
    async symbols(query: string) {
      symbolQueries.push(query);
      return [{ name: "debug_value", kind: 12, path: source, range: { start: { line: 5, column: 1 }, end: { line: 8, column: 2 } } }];
    },
    async definition() { return []; },
    async hover(point: any) { hoverPoints.push(point); return { text: "fn debug_value(input: i32) -> i32" }; },
    async references() { return [{ path: source, range: { start: { line: 2, column: 5 }, end: { line: 2, column: 16 } } }]; },
    async callers() { return { incoming: [{ name: "compute", path: source }], outgoing: [] }; },
    diagnostics() { return [{ message: "fake issue", range: { start: { line: 3, column: 1 }, end: { line: 3, column: 5 } } }]; },
    async close() { closed += 1; },
  };
}

function text(result: any): string {
  return result.content.find((item: any) => item.type === "text")?.text ?? "";
}

test("launches rust-analyzer inside a documented Nix development shell", () => {
  const start = resolveRustAnalyzerStart({
    root: fixture,
    cargo: {
      executable: "/nix/store/nix/bin/nix",
      argsPrefix: ["develop", ".#rust", "--command", "cargo"],
      env: { HOME: "/tmp/home" },
    },
  } as any, {
    rustAnalyzerPath: "/nix/store/rust-analyzer/bin/rust-analyzer",
    cargoPath: "cargo",
    rustcPath: "rustc",
    nixPath: "/nix/store/nix/bin/nix",
    toolPath: "/nix/store/tools/bin",
  });
  assert.equal(start.executable, "/nix/store/nix/bin/nix");
  assert.deepEqual(start.args, ["develop", ".#rust", "--command", "/nix/store/rust-analyzer/bin/rust-analyzer"]);
  assert.equal(start.env.RUSTC, undefined);
});

test("registers rust_code and starts rust-analyzer lazily", async () => {
  const pi = fakePi();
  const session = fakeSession();
  let starts = 0;
  createRustIntelligence({
    rustAnalyzerPath: "rust-analyzer",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
    startAnalyzer: async () => { starts += 1; return session; },
  })(pi.api as any);

  assert.equal(pi.tools.map((tool) => tool.name).includes("rust_code"), true);
  assert.equal(starts, 0);
  const tool = pi.tools.find((item) => item.name === "rust_code")!;
  const result = await tool.execute("id", { action: "symbol", query: "debug_value" }, undefined, undefined, { cwd: fixture, isProjectTrusted: () => true });
  assert.equal(starts, 1);
  assert.match(text(result), /debug_value/);
  assert.match(text(result), /src\/lib.rs/);

  for (const handler of pi.handlers.get("session_shutdown") ?? []) await handler({}, {});
  assert.equal(session.closed, 1);
});

test("builds bounded context from documentation and symbols", async () => {
  const pi = fakePi();
  const session = fakeSession();
  createRustIntelligence({
    rustAnalyzerPath: "rust-analyzer",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
    maxBytes: 1000,
    startAnalyzer: async () => session,
  })(pi.api as any);

  const tool = pi.tools.find((item) => item.name === "rust_code")!;
  const result = await tool.execute("id", { action: "context", query: "debug regression decisive" }, undefined, undefined, { cwd: fixture, isProjectTrusted: () => true });
  assert.ok(Buffer.byteLength(text(result)) <= 1100);
  assert.match(text(result), /Debugging the regression/);
  assert.match(text(result), /fake issue/);
  assert.match(text(result), /compute/);
  assert.equal(result.details.truncated, true);
  assert.equal(session.symbolQueries.includes("debug"), true);
});

test("requires project trust before Cargo diagnostics execute build scripts", async () => {
  const pi = fakePi();
  createRustIntelligence({
    rustAnalyzerPath: "rust-analyzer",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
  })(pi.api as any);
  const tool = pi.tools.find((item) => item.name === "rust_code")!;
  const untrusted = { cwd: fixture, isProjectTrusted: () => false };
  await assert.rejects(
    tool.execute("id", { action: "diagnostics" }, undefined, undefined, untrusted),
    /trusted project/,
  );
  await assert.rejects(
    tool.execute("symbol", { action: "symbol", query: "debug_value" }, undefined, undefined, untrusted),
    /trusted project/,
  );
});

test("normalizes project-relative source paths", async () => {
  const pi = fakePi();
  const session = fakeSession();
  createRustIntelligence({
    rustAnalyzerPath: "rust-analyzer",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
    startAnalyzer: async () => session,
  })(pi.api as any);

  const tool = pi.tools.find((item) => item.name === "rust_code")!;
  await tool.execute("id", {
    action: "hover",
    path: "@crates/demo/src/lib.rs",
    line: 5,
    column: 1,
  }, undefined, undefined, { cwd: fixture, isProjectTrusted: () => true });
  assert.equal(session.hoverPoints.at(-1).path, source);
});
