import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { createRustDebugger, resolveCodeLldbStart } from "../debugger.ts";

const fixture = join(dirname(fileURLToPath(import.meta.url)), "fixtures", "workspace");

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
  let closes = 0;
  const breakpointPaths: string[] = [];
  return {
    get closes() { return closes; },
    breakpointPaths,
    async launch() { return { reason: "breakpoint", threadId: 7 }; },
    async setBreakpoint(path: string) { breakpointPaths.push(path); return { verified: true, line: 6 }; },
    async continue() { return { reason: "breakpoint", threadId: 7 }; },
    async next() { return { reason: "step", threadId: 7 }; },
    async stepIn() { return { reason: "step", threadId: 7 }; },
    async stepOut() { return { reason: "step", threadId: 7 }; },
    async threads() { return [{ id: 7, name: "main" }]; },
    async stackTrace() { return { frames: [{ id: 11, name: "debug_value", line: 6 }], totalFrames: 1 }; },
    async scopes() { return [{ name: "Locals", variablesReference: 13 }]; },
    async variables() { return [{ name: "decisive", value: "42", variablesReference: 0 }]; },
    async evaluate() { return { result: "42", variablesReference: 0 }; },
    async close() { closes += 1; },
  };
}

function context(trusted: boolean) {
  return { cwd: fixture, isProjectTrusted: () => trusted };
}

test("launches CodeLLDB inside a documented Nix development shell", () => {
  const start = resolveCodeLldbStart({
    root: fixture,
    cargo: {
      executable: "/nix/store/nix/bin/nix",
      argsPrefix: ["develop", ".#rust", "--command", "cargo"],
      env: { HOME: "/tmp/home" },
    },
  } as any, {
    codeLldbPath: "/nix/store/codelldb",
    cargoPath: "cargo",
    rustcPath: "rustc",
    nixPath: "/nix/store/nix/bin/nix",
  });
  assert.equal(start.executable, "/nix/store/nix/bin/nix");
  assert.deepEqual(start.adapterArgs, ["develop", ".#rust", "--command", "/nix/store/codelldb"]);
  assert.equal(start.env.RUSTC, undefined);
});

test("requires project trust before launching code", async () => {
  const pi = fakePi();
  createRustDebugger({
    codeLldbPath: "codelldb",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
  })(pi.api as any);
  const start = pi.tools.find((item) => item.name === "rust_debug_start")!;
  await assert.rejects(start.execute("id", { goal: "debug regression" }, undefined, undefined, context(false)), /trusted project/);
});

test("discovers, builds, and launches one autonomous session", async () => {
  const pi = fakePi();
  const session = fakeSession();
  let builds = 0;
  let starts = 0;
  createRustDebugger({
    codeLldbPath: "codelldb",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
    buildTarget: async (_project, selection) => {
      builds += 1;
      return {
        target: { package: selection.package, packageId: "demo", name: selection.target, kind: selection.kind, sourcePath: "source" },
        executable: "/tmp/demo-test",
        args: [selection.testFilter ?? ""],
        buildStdout: "",
        buildStderr: "",
      };
    },
    startSession: async () => { starts += 1; return session; },
  })(pi.api as any);

  const start = pi.tools.find((item) => item.name === "rust_debug_start")!;
  const started = await start.execute("id", { goal: "inspect the decisive runtime value", testFilter: "computes" }, undefined, undefined, context(true));
  assert.equal(builds, 1);
  assert.equal(starts, 1);
  assert.equal(started.details.target.kind, "test");
  assert.equal(started.details.stopped.threadId, 7);
  await assert.rejects(start.execute("id2", { goal: "again" }, undefined, undefined, context(true)), /already active/);

  const control = pi.tools.find((item) => item.name === "rust_debug")!;
  const stack = await control.execute("id3", { action: "stack", threadId: 7 }, undefined, undefined, context(true));
  assert.equal(stack.details.value.frames[0].name, "debug_value");
  await control.execute("id4", { action: "breakpoint", path: "@crates/demo/src/lib.rs", line: 6 }, undefined, undefined, context(true));
  assert.equal(session.breakpointPaths.at(-1), join(fixture, "crates", "demo", "src", "lib.rs"));
  await assert.rejects(
    control.execute("outside", { action: "breakpoint", path: "/tmp/outside.rs", line: 1 }, undefined, undefined, context(true)),
    /outside the active Cargo workspace/,
  );
  await control.execute("id5", { action: "stop" }, undefined, undefined, context(true));
  assert.equal(session.closes, 1);
});

test("returns candidates instead of guessing an ambiguous target", async () => {
  const pi = fakePi();
  let starts = 0;
  createRustDebugger({
    codeLldbPath: "codelldb",
    cargoPath: process.env.TEST_CARGO ?? "cargo",
    rustcPath: process.env.TEST_RUSTC ?? "rustc",
    startSession: async () => { starts += 1; return fakeSession(); },
  })(pi.api as any);
  const start = pi.tools.find((item) => item.name === "rust_debug_start")!;
  const result = await start.execute("id", { goal: "run demo" }, undefined, undefined, context(true));
  assert.equal(result.details.status, "ambiguous");
  assert.ok(result.details.candidates.length > 1);
  assert.equal(starts, 0);
});
