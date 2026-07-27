import assert from "node:assert/strict";
import { test } from "node:test";

import { runProcess } from "../process.ts";

test("runProcess preserves arguments and captures stdout and stderr", async () => {
  const result = await runProcess({
    executable: process.execPath,
    args: ["-e", "process.stdout.write(process.argv[1]); process.stderr.write('warning')", "value with spaces"],
    cwd: process.cwd(),
  });

  assert.equal(result.code, 0);
  assert.equal(result.stdout, "value with spaces");
  assert.equal(result.stderr, "warning");
  assert.equal(result.timedOut, false);
  assert.equal(result.aborted, false);
});

test("runProcess terminates a timed out process", async () => {
  const started = Date.now();
  const result = await runProcess({
    executable: process.execPath,
    args: ["-e", "setInterval(() => {}, 1000)"],
    cwd: process.cwd(),
    timeoutMs: 100,
  });

  assert.equal(result.timedOut, true);
  assert.equal(result.aborted, false);
  assert.ok(Date.now() - started < 3000);
});

test("runProcess force-kills a process that ignores termination", async () => {
  const started = Date.now();
  const result = await runProcess({
    executable: process.execPath,
    args: ["-e", "process.on('SIGTERM', () => {}); setInterval(() => {}, 1000)"],
    cwd: process.cwd(),
    timeoutMs: 100,
  });

  assert.equal(result.timedOut, true);
  assert.ok(Date.now() - started < 3000);
});

test("runProcess terminates when aborted", async () => {
  const controller = new AbortController();
  setTimeout(() => controller.abort(), 100);

  const result = await runProcess({
    executable: process.execPath,
    args: ["-e", "setInterval(() => {}, 1000)"],
    cwd: process.cwd(),
    signal: controller.signal,
  });

  assert.equal(result.aborted, true);
  assert.equal(result.timedOut, false);
});
