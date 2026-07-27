import type { ExtensionAPI, ExtensionFactory } from "@earendil-works/pi-coding-agent";
import { isAbsolute, relative, resolve } from "node:path";

import {
  CodeLldbSession,
  type CodeLldbStartOptions,
  type StoppedEvent,
} from "./dap.ts";
import {
  buildDebugTarget,
  discoverRustProject,
  listDebugTargets,
  searchProjectDocs,
  type BuiltTarget,
  type DebugSelection,
  type DebugTarget,
  type DocExcerpt,
  type RustProject,
  type RustRuntime,
} from "./project.ts";

interface DebugSession {
  launch(options: { program: string; cwd: string; args: string[]; env: Record<string, string>; breakpoints: Array<{ path: string; line: number }> }): Promise<StoppedEvent>;
  setBreakpoint(path: string, line: number): Promise<unknown>;
  continue(threadId: number): Promise<unknown>;
  next(threadId: number): Promise<unknown>;
  stepIn(threadId: number): Promise<unknown>;
  stepOut(threadId: number): Promise<unknown>;
  threads(): Promise<unknown>;
  stackTrace(threadId: number, startFrame?: number, levels?: number): Promise<unknown>;
  scopes(frameId: number): Promise<unknown>;
  variables(reference: number, start?: number, count?: number): Promise<unknown>;
  evaluate(expression: string, frameId?: number): Promise<unknown>;
  close(): Promise<void>;
}

export interface RustDebuggerConfig {
  codeLldbPath: string;
  cargoPath: string;
  rustcPath: string;
  nixPath?: string;
  toolPath?: string;
  timeoutMs?: number;
  maxBytes?: number;
  buildTarget?: (project: RustProject, selection: DebugSelection, runtime: RustRuntime) => Promise<BuiltTarget>;
  startSession?: (project: RustProject, config: RustDebuggerConfig) => Promise<DebugSession>;
}

interface StartInput {
  goal: string;
  package?: string;
  target?: string;
  targetKind?: "bin" | "test" | "example" | "bench" | "lib";
  testFilter?: string;
  args?: string[];
  env?: Record<string, string>;
}

interface ControlInput {
  action: "breakpoint" | "continue" | "step_in" | "step_over" | "step_out" | "threads" | "stack" | "scopes" | "variables" | "evaluate" | "stop";
  path?: string;
  line?: number;
  threadId?: number;
  frameId?: number;
  variablesReference?: number;
  expression?: string;
  start?: number;
  count?: number;
}

const debugActions = ["breakpoint", "continue", "step_in", "step_over", "step_out", "threads", "stack", "scopes", "variables", "evaluate", "stop"];

function startSchema() {
  return {
    type: "object",
    properties: {
      goal: { type: "string" },
      package: { type: "string" },
      target: { type: "string" },
      targetKind: { type: "string", enum: ["bin", "test", "example", "bench", "lib"] },
      testFilter: { type: "string" },
      args: { type: "array", items: { type: "string" } },
      env: { type: "object", additionalProperties: { type: "string" } },
    },
    required: ["goal"],
    additionalProperties: false,
  };
}

function controlSchema() {
  return {
    type: "object",
    properties: {
      action: { type: "string", enum: debugActions },
      path: { type: "string" },
      line: { type: "integer", minimum: 1 },
      threadId: { type: "integer", minimum: 1 },
      frameId: { type: "integer", minimum: 1 },
      variablesReference: { type: "integer", minimum: 0 },
      expression: { type: "string" },
      start: { type: "integer", minimum: 0 },
      count: { type: "integer", minimum: 1, maximum: 1000 },
    },
    required: ["action"],
    additionalProperties: false,
  };
}

function flagValue(args: string[], ...flags: string[]): string | undefined {
  const index = args.findIndex((item) => flags.includes(item));
  return index === -1 ? undefined : args[index + 1];
}

function targetsFromDocumentation(targets: DebugTarget[], docs: DocExcerpt[]): DebugTarget[] {
  const matches: DebugTarget[] = [];
  for (const doc of docs) {
    for (const command of doc.text.matchAll(/\bcargo\s+(test|run|build)\b([^`\n]*)/g)) {
      const args = command[2].trim().split(/\s+/).filter(Boolean);
      const packageName = flagValue(args, "-p", "--package");
      const selectors: Array<[DebugTarget["kind"], string | undefined]> = [
        ["test", flagValue(args, "--test")],
        ["bin", flagValue(args, "--bin")],
        ["example", flagValue(args, "--example")],
        ["bench", flagValue(args, "--bench")],
      ];
      for (const [kind, name] of selectors) {
        if (!name) continue;
        matches.push(...targets.filter((target) => (
          target.kind === kind
          && target.name === name
          && (!packageName || target.package === packageName)
        )));
      }
    }
  }
  return [...new Map(matches.map((item) => [`${item.package}:${item.kind}:${item.name}`, item])).values()];
}

function chooseTarget(targets: DebugTarget[], input: StartInput, docs: DocExcerpt[]): DebugTarget | DebugTarget[] {
  let candidates = targets;
  if (input.package) candidates = candidates.filter((item) => item.package === input.package);
  if (input.target) candidates = candidates.filter((item) => item.name === input.target);
  if (input.targetKind) candidates = candidates.filter((item) => item.kind === input.targetKind);
  if (candidates.length === 1) return candidates[0];
  if (input.target || input.targetKind) return candidates;
  const terms = input.goal.toLowerCase().split(/[^a-z0-9_]+/).filter(Boolean);
  const exact = candidates.filter((item) => terms.includes(item.name.toLowerCase()));
  if (exact.length === 1) return exact[0];
  if (exact.length > 1) return exact;
  const documented = targetsFromDocumentation(candidates, docs);
  return documented.length === 1 ? documented[0] : documented.length > 1 ? documented : candidates;
}

export function resolveCodeLldbStart(
  project: Pick<RustProject, "root" | "cargo">,
  config: RustDebuggerConfig,
): CodeLldbStartOptions {
  if (config.nixPath && project.cargo.executable === config.nixPath) {
    const adapterArgs = [...project.cargo.argsPrefix];
    const cargoIndex = adapterArgs.lastIndexOf("cargo");
    if (cargoIndex !== -1) adapterArgs.splice(cargoIndex, 1, config.codeLldbPath);
    return {
      executable: config.nixPath,
      adapterArgs,
      cwd: project.root,
      env: project.cargo.env,
      timeoutMs: config.timeoutMs,
    };
  }
  return {
    executable: config.codeLldbPath,
    cwd: project.root,
    env: {
      ...process.env,
      PATH: config.toolPath
        ? `${config.toolPath}:${process.env.PATH ?? ""}`
        : process.env.PATH,
    },
    timeoutMs: config.timeoutMs,
  };
}

function bounded(value: unknown, maxBytes: number): string {
  const text = JSON.stringify(value, null, 2);
  if (Buffer.byteLength(text) <= maxBytes) return text;
  return `${Buffer.from(text).subarray(0, maxBytes).toString("utf8")}\n[Output truncated]`;
}

export function createRustDebugger(config: RustDebuggerConfig): ExtensionFactory {
  return function rustDebugger(pi: ExtensionAPI) {
    let session: DebugSession | undefined;
    let activeRoot: string | undefined;
    let stoppedThreadId: number | undefined;

    const runtime = (signal?: AbortSignal): RustRuntime => ({
      cargoPath: config.cargoPath,
      rustcPath: config.rustcPath,
      nixPath: config.nixPath,
      toolPath: config.toolPath,
      timeoutMs: config.timeoutMs,
      signal,
    });

    const stop = async () => {
      await session?.close();
      session = undefined;
      activeRoot = undefined;
      stoppedThreadId = undefined;
    };

    pi.registerTool({
      name: "rust_debug_start",
      label: "Rust Debug Start",
      description: "Discover, build, and autonomously launch a trusted local Rust target under CodeLLDB",
      promptSnippet: "Launch a documented Cargo binary or test under the Rust debugger",
      promptGuidelines: [
        "Use rust_debug_start only after consulting project guidance, reproducing the failure, and stating a root-cause hypothesis that runtime evidence can test.",
      ],
      parameters: startSchema(),
      async execute(_id: string, input: StartInput, signal: AbortSignal | undefined, _onUpdate: unknown, ctx: { cwd: string; isProjectTrusted(): boolean }) {
        if (!ctx.isProjectTrusted()) throw new Error("Rust debugging requires a trusted project");
        if (session) throw new Error("A Rust debug session is already active");
        const project = await discoverRustProject({ cwd: ctx.cwd, runtime: runtime(signal) });
        const targets = listDebugTargets(project);
        const docs = searchProjectDocs(project, input.goal, { maxResults: 4, maxBytes: 8000 });
        const selected = chooseTarget(targets, input, docs);
        if (Array.isArray(selected)) {
          const details = { status: "ambiguous", candidates: selected, documents: docs };
          return { content: [{ type: "text", text: bounded(details, config.maxBytes ?? 50 * 1024) }], details };
        }
        const selection: DebugSelection = {
          package: selected.package,
          target: selected.name,
          kind: selected.kind,
          testFilter: input.testFilter,
        };
        const built = config.buildTarget
          ? await config.buildTarget(project, selection, runtime(signal))
          : await buildDebugTarget(project, selection, runtime(signal));
        session = config.startSession
          ? await config.startSession(project, config)
          : await CodeLldbSession.start(resolveCodeLldbStart(project, config));
        activeRoot = project.root;
        try {
          const stopped = await session.launch({
            program: built.executable,
            cwd: project.root,
            args: [...built.args, ...(input.args ?? [])],
            env: input.env ?? {},
            breakpoints: [],
          });
          stoppedThreadId = stopped.threadId;
          const details = {
            status: "stopped",
            target: built.target,
            executable: built.executable,
            stopped,
            documents: docs.map((item) => ({ path: relative(project.root, item.path), heading: item.heading, text: item.text })),
          };
          return { content: [{ type: "text", text: bounded(details, config.maxBytes ?? 50 * 1024) }], details };
        } catch (error) {
          await stop();
          throw error;
        }
      },
    });

    pi.registerTool({
      name: "rust_debug",
      label: "Rust Debug",
      description: "Control the active Rust CodeLLDB session and inspect focused runtime state",
      promptSnippet: "Set breakpoints, step, inspect stacks and variables, evaluate expressions, or stop Rust debugging",
      promptGuidelines: [
        "Use rust_debug to test one explicit debugging hypothesis at a time, and stop the session before editing source.",
      ],
      parameters: controlSchema(),
      async execute(_id: string, input: ControlInput, _signal: AbortSignal | undefined, _onUpdate: unknown, ctx: { cwd: string }) {
        if (!session) throw new Error("No Rust debug session is active");
        let value: unknown;
        if (input.action === "stop") {
          await stop();
          value = { status: "stopped" };
        } else if (input.action === "breakpoint") {
          if (!input.path || !input.line) throw new Error("breakpoint requires path and line");
          const path = input.path.replace(/^@/, "");
          const absolutePath = isAbsolute(path) ? path : resolve(ctx.cwd, path);
          const workspacePath = activeRoot ? relative(activeRoot, absolutePath) : "..";
          if (workspacePath === ".." || workspacePath.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`) || isAbsolute(workspacePath)) {
            throw new Error(`Breakpoint path is outside the active Cargo workspace: ${absolutePath}`);
          }
          value = await session.setBreakpoint(absolutePath, input.line);
        } else if (input.action === "threads") {
          value = await session.threads();
        } else if (input.action === "stack") {
          const threadId = input.threadId ?? stoppedThreadId;
          if (!threadId) throw new Error("stack requires threadId before a stopped thread is known");
          value = await session.stackTrace(threadId, input.start, input.count);
        } else if (input.action === "scopes") {
          if (!input.frameId) throw new Error("scopes requires frameId");
          value = await session.scopes(input.frameId);
        } else if (input.action === "variables") {
          if (input.variablesReference === undefined) throw new Error("variables requires variablesReference");
          value = await session.variables(input.variablesReference, input.start, input.count);
        } else if (input.action === "evaluate") {
          if (!input.expression) throw new Error("evaluate requires expression");
          value = await session.evaluate(input.expression, input.frameId);
        } else {
          const threadId = input.threadId ?? stoppedThreadId;
          if (!threadId) throw new Error(`${input.action} requires threadId before a stopped thread is known`);
          if (input.action === "continue") value = await session.continue(threadId);
          else if (input.action === "step_over") value = await session.next(threadId);
          else if (input.action === "step_in") value = await session.stepIn(threadId);
          else value = await session.stepOut(threadId);
          stoppedThreadId = (value as { threadId?: number }).threadId ?? stoppedThreadId;
        }
        const details = { action: input.action, value };
        return { content: [{ type: "text", text: bounded(details, config.maxBytes ?? 50 * 1024) }], details };
      },
    });

    pi.on("session_shutdown", stop);
  };
}
