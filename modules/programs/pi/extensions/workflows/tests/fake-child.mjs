// A scripted stand-in for a child Pi in RPC mode. argv[2] holds the scenario:
// { attempts: Step[][], onAbort?: Step[] }, where each prompt plays the next attempt.
import { createInterface } from "node:readline";

const scenario = JSON.parse(process.argv[2]);
let attempt = 0;
let replied;

const emit = (record) => process.stdout.write(`${JSON.stringify(record)}\n`);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function play(steps) {
  for (const step of steps) {
    if (step.delay !== undefined) await sleep(step.delay);
    else if (step.exit !== undefined) process.exit(step.exit);
    else if (step.awaitReply) await new Promise((resolve) => { replied = resolve; });
    else emit(step);
  }
}

emit({ type: "fake_argv", args: process.argv.slice(3) });

createInterface({ input: process.stdin }).on("line", (line) => {
  const record = JSON.parse(line);
  emit({ type: "fake_received", record });
  if (record.type === "extension_ui_response") replied?.();
  if (record.type === "prompt") void play(scenario.attempts[attempt++] ?? []);
  if (record.type === "abort") void play(scenario.onAbort ?? [{ exit: 0 }]);
});
