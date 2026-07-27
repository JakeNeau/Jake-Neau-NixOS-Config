import { spawn, type ChildProcess } from "node:child_process";

export interface ProcessRequest {
  executable: string;
  args?: string[];
  cwd: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface ProcessResult {
  code: number | null;
  signal: NodeJS.Signals | null;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  aborted: boolean;
}

const stopping = new WeakMap<ChildProcess, Promise<void>>();

function signalProcessTree(child: ChildProcess, signal: NodeJS.Signals): void {
  if (child.pid === undefined) return;
  try {
    process.kill(-child.pid, signal);
  } catch {
    try {
      child.kill(signal);
    } catch {
      return;
    }
  }
}

function waitForExit(child: ChildProcess, timeoutMs: number): Promise<void> {
  if (child.exitCode !== null || child.signalCode !== null) return Promise.resolve();
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      child.off("close", done);
      resolve();
    }, timeoutMs);
    const done = () => {
      clearTimeout(timer);
      resolve();
    };
    child.once("close", done);
  });
}

export function stopProcessTree(child: ChildProcess): Promise<void> {
  const active = stopping.get(child);
  if (active) return active;
  const operation = (async () => {
    if (child.exitCode !== null || child.signalCode !== null || child.pid === undefined) return;
    signalProcessTree(child, "SIGTERM");
    await waitForExit(child, 500);
    if (child.exitCode !== null || child.signalCode !== null) return;
    signalProcessTree(child, "SIGKILL");
    await waitForExit(child, 500);
  })();
  stopping.set(child, operation);
  return operation;
}

export function waitForSpawn(child: ChildProcess): Promise<void> {
  return new Promise((resolve, reject) => {
    const cleanup = () => {
      child.off("spawn", onSpawn);
      child.off("error", onError);
    };
    const onSpawn = () => {
      cleanup();
      resolve();
    };
    const onError = (error: Error) => {
      cleanup();
      reject(error);
    };
    child.once("spawn", onSpawn);
    child.once("error", onError);
  });
}

export async function runProcess(request: ProcessRequest): Promise<ProcessResult> {
  const child = spawn(request.executable, request.args ?? [], {
    cwd: request.cwd,
    env: request.env ?? process.env,
    detached: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  const stdout: Buffer[] = [];
  const stderr: Buffer[] = [];
  let timedOut = false;
  let aborted = request.signal?.aborted ?? false;

  child.stdout?.on("data", (chunk) => stdout.push(Buffer.from(chunk)));
  child.stderr?.on("data", (chunk) => stderr.push(Buffer.from(chunk)));

  const terminate = () => void stopProcessTree(child);
  const abort = () => {
    aborted = true;
    terminate();
  };
  request.signal?.addEventListener("abort", abort, { once: true });

  const timer = request.timeoutMs === undefined
    ? undefined
    : setTimeout(() => {
        timedOut = true;
        terminate();
      }, request.timeoutMs);

  if (aborted) terminate();

  const result = await new Promise<{ code: number | null; signal: NodeJS.Signals | null }>((resolve, reject) => {
    child.once("error", reject);
    child.once("close", (code, signal) => resolve({ code, signal }));
  }).finally(() => {
    if (timer) clearTimeout(timer);
    request.signal?.removeEventListener("abort", abort);
  });

  return {
    ...result,
    stdout: Buffer.concat(stdout).toString("utf8"),
    stderr: Buffer.concat(stderr).toString("utf8"),
    timedOut,
    aborted,
  };
}
