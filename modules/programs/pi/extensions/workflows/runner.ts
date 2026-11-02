import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { StringDecoder } from "node:string_decoder";

import { validateSchemaValue, type ArtifactCandidate, type WorkflowArtifact } from "./artifacts.ts";

export class StrictJsonlDecoder {
  private readonly decoder = new StringDecoder("utf8");
  private buffer = "";

  push(chunk: Buffer): unknown[] {
    this.buffer += this.decoder.write(chunk);
    return this.drain(false);
  }

  finish(): unknown[] {
    this.buffer += this.decoder.end();
    return this.drain(true);
  }

  private drain(final: boolean): unknown[] {
    const records: unknown[] = [];
    while (true) {
      const index = this.buffer.indexOf("\n");
      if (index < 0) break;
      let line = this.buffer.slice(0, index);
      this.buffer = this.buffer.slice(index + 1);
      if (line.endsWith("\r")) line = line.slice(0, -1);
      if (line.trim()) records.push(JSON.parse(line));
    }
    if (final && this.buffer.trim()) {
      let line = this.buffer;
      if (line.endsWith("\r")) line = line.slice(0, -1);
      records.push(JSON.parse(line));
      this.buffer = "";
    }
    return records;
  }
}

export function buildChildArguments(options: {
  provider: string;
  model: string;
  thinking: string;
  tools: string[] | "*";
  trusted: boolean;
}): string[] {
  return [
    "--mode", "rpc", "--no-session",
    "--model", `${options.provider}/${options.model}`,
    "--thinking", options.thinking,
    "--tools", options.tools === "*" ? "*" : [...new Set(options.tools)].join(","),
    options.trusted ? "--approve" : "--no-approve",
  ];
}

export function mutationBlockReason(
  readOnly: boolean,
  approvedPaths: ReadonlySet<string>,
  path: string | undefined,
): string | undefined {
  // Read-only is enforced by the stage prompt alone; the empty approved set would block every edit.
  if (readOnly) return undefined;
  if (path === undefined) return "Workflow mutation has no path";
  if (!approvedPaths.has(path)) return `Workflow mutation path is not approved: ${path}`;
  return undefined;
}

export interface StageRunOptions {
  cwd: string;
  prompt: string;
  schema: Record<string, unknown>;
  provider: string;
  model: string;
  thinking: string;
  tools: string[] | "*";
  trusted: boolean;
  readOnly: boolean;
  approvedPaths?: string[];
  artifacts: WorkflowArtifact[];
  catalog: unknown[];
  signal?: AbortSignal;
  timeoutMs?: number;
  onEvent?: (event: unknown) => void;
  // Builds the child command in place of the running Pi.
  invocation?: (args: string[]) => { command: string; args: string[] };
  check?: (artifact: ArtifactCandidate) => string[];
}

export interface StageRunResult {
  artifact: ArtifactCandidate;
  repaired: boolean;
  requestedArtifactIds: string[];
  usage: { input: number; output: number; cacheRead: number; cacheWrite: number; cost: number };
  peakContextTokens: number;
}

const DIALOG_METHODS = new Set(["select", "confirm", "input", "editor"]);

// Mirrors Pi's calculateContextTokens: the size of the request that produced one message.
function contextTokens(usage: Record<string, number | undefined>): number {
  return usage.totalTokens || (usage.input ?? 0) + (usage.output ?? 0) + (usage.cacheRead ?? 0) + (usage.cacheWrite ?? 0);
}

export function contextBudgetWarning(
  stageType: string,
  peakContextTokens: number,
  contextWindow: number | undefined,
): string | undefined {
  if (!contextWindow || contextWindow <= 0 || peakContextTokens <= 0.2 * contextWindow) return undefined;
  // Rounding up keeps any share above the budget from reading as 20%.
  const percent = Math.ceil((peakContextTokens * 100) / contextWindow);
  return `${stageType} used ${percent}% of the context window, above the 20% budget`;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const script = process.argv[1];
  const virtual = script?.startsWith("/$bunfs/root/");
  if (script && !virtual && existsSync(script)) return { command: process.execPath, args: [script, ...args] };
  const executable = basename(process.execPath).toLowerCase();
  if (!/^(node|bun)(\.exe)?$/.test(executable)) return { command: process.execPath, args };
  return { command: "pi", args };
}

async function waitForExit(child: ChildProcessWithoutNullStreams, timeoutMs: number): Promise<boolean> {
  if (child.exitCode !== null) return true;
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(false), timeoutMs);
    child.once("exit", () => {
      clearTimeout(timer);
      resolve(true);
    });
  });
}

async function stopProcess(child: ChildProcessWithoutNullStreams): Promise<void> {
  if (child.exitCode !== null) return;
  if (!child.stdin.destroyed) child.stdin.write(`${JSON.stringify({ type: "abort" })}\n`);
  if (await waitForExit(child, 200)) return;
  if (child.pid && process.platform !== "win32") {
    try {
      process.kill(-child.pid, "SIGTERM");
    } catch {
      child.kill("SIGTERM");
    }
  } else {
    child.kill("SIGTERM");
  }
  if (await waitForExit(child, 1000)) return;
  if (child.pid && process.platform !== "win32") {
    try {
      process.kill(-child.pid, "SIGKILL");
    } catch {
      child.kill("SIGKILL");
    }
  } else {
    child.kill("SIGKILL");
  }
  await waitForExit(child, 1000);
}

export async function runStage(options: StageRunOptions): Promise<StageRunResult> {
  const stageDir = await mkdtemp(join(tmpdir(), "pi-workflow-stage-"));
  const schemaPath = join(stageDir, "schema.json");
  const artifactRoot = join(stageDir, "artifacts");
  const manifestPath = join(stageDir, "manifest.json");
  await mkdir(artifactRoot, { mode: 0o700 });
  await writeFile(schemaPath, JSON.stringify(options.schema), { mode: 0o600 });
  const artifactManifest: Record<string, string> = {};
  for (const artifact of options.artifacts) {
    const path = join(artifactRoot, `${artifact.artifactId.replace(/[^a-zA-Z0-9_.-]/g, "_")}.json`);
    await writeFile(path, JSON.stringify(artifact), { mode: 0o600 });
    artifactManifest[artifact.artifactId] = path;
  }
  await writeFile(manifestPath, JSON.stringify({ catalog: options.catalog, artifacts: artifactManifest }), { mode: 0o600 });
  // The finally block below starts after the spawn, so this path cleans up itself.
  if (options.signal?.aborted) {
    await rm(stageDir, { recursive: true, force: true });
    options.signal.throwIfAborted();
  }

  const tools = options.tools === "*"
    ? "*"
    : [...new Set([...options.tools, "workflow_output", "request_workflow_artifacts"])];
  const args = buildChildArguments({
    provider: options.provider,
    model: options.model,
    thinking: options.thinking,
    tools,
    trusted: options.trusted,
  });
  const invocation = (options.invocation ?? getPiInvocation)(args);
  const child = spawn(invocation.command, invocation.args, {
    cwd: options.cwd,
    env: {
      ...process.env,
      PI_WORKFLOW_CHILD: "1",
      PI_WORKFLOW_SCHEMA: schemaPath,
      PI_WORKFLOW_ARTIFACT_MANIFEST: manifestPath,
      PI_WORKFLOW_READ_ONLY: options.readOnly ? "1" : "0",
      PI_WORKFLOW_APPROVED_PATHS: JSON.stringify(options.approvedPaths ?? []),
    },
    detached: process.platform !== "win32",
    stdio: ["pipe", "pipe", "pipe"],
  });

  const decoder = new StrictJsonlDecoder();
  const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
  let peakContextTokens = 0;
  let artifact: ArtifactCandidate | undefined;
  let lastAssistant: { stopReason?: string; errorMessage?: string } | undefined;
  const requestedArtifactIds = new Set<string>();
  let stderr = "";
  // A child killed by a signal has exitCode null, so the exit handler records the exit.
  let exited = false;
  let awaitingSettled = true;
  let settledResolve: (() => void) | undefined;
  let settledReject: ((error: Error) => void) | undefined;
  let settled = new Promise<void>((resolve, reject) => {
    settledResolve = resolve;
    settledReject = reject;
  });
  const startTimer = () => setTimeout(
    () => settledReject?.(new Error("Workflow stage timed out")),
    options.timeoutMs ?? 600_000,
  );
  let timeout = startTimer();

  const resetSettled = () => {
    awaitingSettled = true;
    settled = new Promise<void>((resolve, reject) => {
      settledResolve = resolve;
      settledReject = reject;
    });
    clearTimeout(timeout);
    timeout = startTimer();
    // The exit handler skips its reject between attempts, so a child that died then fails here.
    if (exited) settledReject?.(new Error(stderr || "Child Pi exited before the correction"));
  };
  const send = (record: unknown) => {
    if (!exited && !child.stdin.destroyed) child.stdin.write(`${JSON.stringify(record)}\n`);
  };
  const handle = (raw: unknown) => {
    options.onEvent?.(raw);
    if (!raw || typeof raw !== "object") return;
    const event = raw as Record<string, any>;
    // A rejected or handled prompt starts no run, so no agent_settled follows.
    if (event.type === "response" && event.command === "prompt") {
      if (!event.success) settledReject?.(new Error(event.error ?? "Child Pi rejected the stage prompt"));
      else if (event.data?.disposition === "handled") {
        settledReject?.(new Error("Child Pi handled the stage prompt without starting a run"));
      }
    }
    // Nobody can answer a dialog in the child, so it gets the protocol's cancel reply.
    if (event.type === "extension_ui_request" && DIALOG_METHODS.has(event.method)) {
      send({ type: "extension_ui_response", id: event.id, cancelled: true });
    }
    if (event.type === "tool_execution_end" && event.toolName === "workflow_output") {
      artifact = event.result?.details?.artifact as ArtifactCandidate | undefined;
    }
    if (event.type === "tool_execution_end" && event.toolName === "request_workflow_artifacts") {
      for (const artifactId of event.result?.details?.requestedArtifactIds ?? []) {
        if (typeof artifactId === "string") requestedArtifactIds.add(artifactId);
      }
    }
    if (event.type === "message_end" && event.message?.role === "assistant") {
      lastAssistant = event.message;
      const current = event.message.usage;
      if (current) {
        peakContextTokens = Math.max(peakContextTokens, contextTokens(current));
        usage.input += current.input ?? 0;
        usage.output += current.output ?? 0;
        usage.cacheRead += current.cacheRead ?? 0;
        usage.cacheWrite += current.cacheWrite ?? 0;
        usage.cost += current.cost?.total ?? 0;
      }
    }
    if (event.type === "agent_settled") {
      awaitingSettled = false;
      settledResolve?.();
    }
    if (event.type === "extension_error") settledReject?.(new Error(event.error ?? "Child extension error"));
  };
  child.stdout.on("data", (chunk: Buffer) => {
    try {
      for (const event of decoder.push(chunk)) handle(event);
    } catch (error) {
      settledReject?.(error instanceof Error ? error : new Error(String(error)));
    }
  });
  child.stderr.on("data", (chunk: Buffer) => { stderr += chunk.toString(); });
  child.on("error", (error) => settledReject?.(error));
  child.stdin.on("error", (error) => settledReject?.(error));
  child.on("exit", (code) => {
    exited = true;
    if (awaitingSettled) settledReject?.(new Error(stderr || `Child Pi exited before settling with ${code ?? "no status"}`));
  });

  const abort = () => void stopProcess(child);
  options.signal?.addEventListener("abort", abort, { once: true });

  const artifactErrors = (candidate: ArtifactCandidate | undefined): string[] => {
    if (!candidate) return ["workflow_output was not called"];
    const errors = validateSchemaValue(options.schema, candidate);
    // Checks read the payload, so they run only on a schema-valid artifact.
    if (errors.length === 0 && options.check) errors.push(...options.check(candidate));
    const serialized = JSON.stringify(candidate, null, 2);
    if (Buffer.byteLength(serialized) > 50 * 1024) errors.push("workflow artifact exceeds 50 KB");
    if (serialized.split("\n").length > 2000) errors.push("workflow artifact exceeds 2,000 lines");
    return errors;
  };

  const attempt = async (message: string): Promise<string[]> => {
    send({ type: "prompt", message });
    await settled;
    options.signal?.throwIfAborted();
    const errors = artifactErrors(artifact);
    // Unless the artifact is valid, a provider error ends the stage: a correction cannot fix it.
    if (errors.length > 0 && lastAssistant?.stopReason === "error") {
      throw new Error(lastAssistant.errorMessage ?? "Child Pi provider request failed");
    }
    return errors;
  };

  try {
    let errors = await attempt(options.prompt);
    const repaired = errors.length > 0;
    if (repaired) {
      artifact = undefined;
      resetSettled();
      errors = await attempt(`Your stage output was invalid:\n${errors.join("\n")}\nCall workflow_output once with a corrected artifact.`);
    }
    // One line, so a display of only the first line still shows every error.
    if (!artifact || errors.length > 0) throw new Error(`Invalid workflow artifact after repair: ${errors.join("; ")}`);
    return { artifact, repaired, requestedArtifactIds: [...requestedArtifactIds], usage, peakContextTokens };
  } finally {
    clearTimeout(timeout);
    options.signal?.removeEventListener("abort", abort);
    await stopProcess(child);
    child.stdin.end();
    await rm(stageDir, { recursive: true, force: true });
  }
}
