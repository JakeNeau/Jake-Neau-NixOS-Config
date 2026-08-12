import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { CodeLldbSession } from "../dap.ts";

const here = dirname(fileURLToPath(import.meta.url));
const server = join(here, "fixtures", "fake-dap.mjs");
const source = join(here, "fixtures", "workspace", "crates", "demo", "src", "lib.rs");

async function start(terminateOnContinue = false, failOnContinue = false, stopBeforeResponse = false) {
  return CodeLldbSession.start({
    executable: process.execPath,
    adapterArgs: [server],
    cwd: join(here, "fixtures", "workspace"),
    env: {
      ...process.env,
      FAKE_SOURCE_PATH: source,
      FAKE_TERMINATE_ON_CONTINUE: terminateOnContinue ? "1" : "0",
      FAKE_FAIL_ON_CONTINUE: failOnContinue ? "1" : "0",
      FAKE_STOP_BEFORE_RESPONSE: stopBeforeResponse ? "1" : "0",
    },
    timeoutMs: 1000,
  });
}

test("launches through DAP and inspects stopped state", async (context) => {
  const session = await start();
  context.after(() => session.close());
  const stopped = await session.launch({
    program: "/tmp/demo",
    cwd: join(here, "fixtures", "workspace"),
    args: ["filter"],
    env: { RUST_LOG: "debug" },
    breakpoints: [{ path: source, line: 6 }],
  });
  assert.equal(stopped.threadId, 7);

  assert.equal((await session.threads())[0].name, "main");
  const stack = await session.stackTrace(7);
  assert.equal(stack.frames[0].name, "debug_value");
  const scopes = await session.scopes(stack.frames[0].id);
  const variables = await session.variables(scopes[0].variablesReference);
  assert.deepEqual(variables[0], { name: "decisive", value: "42", type: "i32", variablesReference: 0 });
  assert.equal((await session.evaluate("decisive", stack.frames[0].id)).result, "42");
});

test("does not leave stale event waiters after a stopped event wins", async (context) => {
  const session = await start(true);
  context.after(() => session.close());
  const stopped = await session.launch({ program: "/tmp/demo", cwd: "/tmp", args: [], env: {}, breakpoints: [] });
  const stepped = await session.next(stopped.threadId!);
  const terminated = await session.continue(stepped.threadId!);
  assert.equal(terminated.terminated, true);
});

test("recovers after a failed resume without leaving a stale stop waiter", async (context) => {
  const session = await start(false, true, true);
  context.after(() => session.close());
  await session.launch({ program: "/tmp/demo", cwd: "/tmp", args: [], env: {}, breakpoints: [] });
  await assert.rejects(session.continue(7), /continue failed: resume rejected/);
  assert.equal((await session.continue(7)).reason, "step");
  await session.close();
  await new Promise((resolve) => setImmediate(resolve));
});

test("reports CodeLLDB spawn failures", async () => {
  await assert.rejects(
    CodeLldbSession.start({
      executable: "/definitely/missing/codelldb",
      cwd: here,
      timeoutMs: 100,
    }),
    /ENOENT|no such file/i,
  );
});

test("sets breakpoints and performs each stepping operation", async (context) => {
  const session = await start();
  context.after(() => session.close());
  await session.launch({ program: "/tmp/demo", cwd: "/tmp", args: [], env: {}, breakpoints: [] });
  const breakpoint = await session.setBreakpoint(source, 6);
  assert.equal(breakpoint.verified, true);
  assert.equal((await session.continue(7)).reason, "step");
  assert.equal((await session.next(7)).threadId, 7);
  assert.equal((await session.stepIn(7)).threadId, 7);
  assert.equal((await session.stepOut(7)).threadId, 7);
  await session.close();
  await session.close();
});
