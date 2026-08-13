import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";

import { validateSchemaValue, type ArtifactCandidate } from "./artifacts.ts";
import { buildChildArguments, StrictJsonlDecoder, type StageRunOptions, type StageRunResult } from "./runner.ts";

export type ConversationAction<T> =
  | { action: "continue"; prompt: string }
  | { action: "finish"; prompt: string; value: T }
  | { action: "stop" };

function invocation(args: string[]): { command: string; args: string[] } {
  const script = process.argv[1];
  const virtual = script?.startsWith("/$bunfs/root/");
  if (script && !virtual && existsSync(script)) return { command: process.execPath, args: [script, ...args] };
  const executable = basename(process.execPath).toLowerCase();
  if (!/^(node|bun)(\.exe)?$/.test(executable)) return { command: process.execPath, args };
  return { command: "pi", args };
}

function assistantText(message: any): string {
  if (typeof message?.content === "string") return message.content.trim();
  if (!Array.isArray(message?.content)) return "";
  return message.content
    .filter((block: any) => block?.type === "text" && typeof block.text === "string")
    .map((block: any) => block.text)
    .join("\n")
    .trim();
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

export async function runConversationStage<T>(
  options: StageRunOptions,
  interact: (response: string) => Promise<ConversationAction<T>>,
): Promise<{ result: StageRunResult; value: T } | undefined> {
  const stageDir = await mkdtemp(join(tmpdir(), "pi-workflow-conversation-"));
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

  const tools = [...new Set([...options.tools, "workflow_output", "request_workflow_artifacts"])];
  const args = buildChildArguments({
    provider: options.provider,
    model: options.model,
    thinking: options.thinking,
    tools,
    trusted: options.trusted,
  });
  const command = invocation(args);
  const child = spawn(command.command, command.args, {
    cwd: options.cwd,
    env: {
      ...process.env,
      PI_WORKFLOW_CHILD: "1",
      PI_WORKFLOW_CONVERSATION: "1",
      PI_WORKFLOW_SCHEMA: schemaPath,
      PI_WORKFLOW_ARTIFACT_MANIFEST: manifestPath,
      PI_WORKFLOW_READ_ONLY: options.readOnly ? "1" : "0",
      PI_WORKFLOW_READ_ONLY_COMMAND_PREFIXES: JSON.stringify(options.readOnlyCommandPrefixes ?? []),
      PI_WORKFLOW_APPROVED_PATHS: JSON.stringify(options.approvedPaths ?? []),
    },
    detached: process.platform !== "win32",
    stdio: ["pipe", "pipe", "pipe"],
  });

  const decoder = new StrictJsonlDecoder();
  const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
  const requestedArtifactIds = new Set<string>();
  let artifact: ArtifactCandidate | undefined;
  let response = "";
  let stderr = "";
  let settledResolve: (() => void) | undefined;
  let settledReject: ((error: Error) => void) | undefined;
  let settled = Promise.resolve();

  const resetTurn = () => {
    artifact = undefined;
    response = "";
    settled = new Promise<void>((resolve, reject) => {
      settledResolve = resolve;
      settledReject = reject;
    });
  };
  const handle = (raw: unknown) => {
    options.onEvent?.(raw);
    if (!raw || typeof raw !== "object") return;
    const event = raw as Record<string, any>;
    if (event.type === "tool_execution_end" && event.toolName === "workflow_output") {
      artifact = event.result?.details?.artifact as ArtifactCandidate | undefined;
    }
    if (event.type === "tool_execution_end" && event.toolName === "request_workflow_artifacts") {
      for (const artifactId of event.result?.details?.requestedArtifactIds ?? []) {
        if (typeof artifactId === "string") requestedArtifactIds.add(artifactId);
      }
    }
    if (event.type === "message_end" && event.message?.role === "assistant") {
      response = assistantText(event.message);
      const current = event.message.usage;
      if (current) {
        usage.input += current.input ?? 0;
        usage.output += current.output ?? 0;
        usage.cacheRead += current.cacheRead ?? 0;
        usage.cacheWrite += current.cacheWrite ?? 0;
        usage.cost += current.cost?.total ?? 0;
      }
    }
    if (event.type === "agent_settled") settledResolve?.();
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
  child.on("exit", (code) => settledReject?.(new Error(stderr || `Conversation child exited with ${code ?? "no status"}`)));

  const abort = () => void stopProcess(child);
  options.signal?.addEventListener("abort", abort, { once: true });

  const prompt = async (message: string): Promise<void> => {
    resetTurn();
    const timeout = setTimeout(
      () => settledReject?.(new Error("Workflow conversation turn timed out")),
      options.timeoutMs ?? 600_000,
    );
    child.stdin.write(`${JSON.stringify({ type: "prompt", message })}\n`);
    try {
      await settled;
    } finally {
      clearTimeout(timeout);
    }
  };
  const errors = (candidate: ArtifactCandidate | undefined): string[] => {
    if (!candidate) return ["workflow_output was not called"];
    const result = validateSchemaValue(options.schema, candidate);
    const serialized = JSON.stringify(candidate, null, 2);
    if (Buffer.byteLength(serialized) > 50 * 1024) result.push("workflow artifact exceeds 50 KB");
    if (serialized.split("\n").length > 2000) result.push("workflow artifact exceeds 2,000 lines");
    return result;
  };

  try {
    await prompt(options.prompt);
    while (true) {
      const action = await interact(response);
      if (action.action === "stop") return undefined;
      if (action.action === "continue") {
        await prompt(action.prompt);
        continue;
      }

      await prompt(action.prompt);
      let artifactErrors = errors(artifact);
      let repaired = false;
      if (artifactErrors.length > 0) {
        repaired = true;
        await prompt(`Your final conversation output was invalid:\n${artifactErrors.join("\n")}\nCall workflow_output once with a corrected artifact.`);
        artifactErrors = errors(artifact);
      }
      if (!artifact || artifactErrors.length > 0) {
        throw new Error(`Invalid workflow conversation artifact after repair:\n${artifactErrors.join("\n")}`);
      }
      return {
        value: action.value,
        result: { artifact, repaired, requestedArtifactIds: [...requestedArtifactIds], usage },
      };
    }
  } finally {
    options.signal?.removeEventListener("abort", abort);
    await stopProcess(child);
    child.stdin.end();
    await rm(stageDir, { recursive: true, force: true });
  }
}
