import { spawn, type ChildProcess } from "node:child_process";
import net, { type Socket } from "node:net";

import { ContentLengthConnection } from "./protocol.ts";
import { stopProcessTree, waitForSpawn } from "./process.ts";

export interface CodeLldbStartOptions {
  executable: string;
  adapterArgs?: string[];
  cwd: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
}

export interface DebugBreakpoint {
  path: string;
  line: number;
}

export interface DebugLaunchOptions {
  program: string;
  cwd: string;
  args: string[];
  env: Record<string, string>;
  breakpoints: DebugBreakpoint[];
}

export interface StoppedEvent {
  reason: string;
  threadId?: number;
  terminated?: boolean;
}

export interface DapThread {
  id: number;
  name: string;
}

export interface DapStackFrame {
  id: number;
  name: string;
  line: number;
  column: number;
  source?: { path?: string; name?: string };
}

export interface DapScope {
  name: string;
  variablesReference: number;
  expensive?: boolean;
}

export interface DapVariable {
  name: string;
  value: string;
  type?: string;
  variablesReference: number;
}

interface EventWaiter {
  resolve(value: unknown): void;
  reject(error: Error): void;
  timer: NodeJS.Timeout;
}

async function reservePort(): Promise<number> {
  const server = net.createServer();
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const address = server.address();
  const port = typeof address === "object" && address ? address.port : 0;
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  if (!port) throw new Error("unable to reserve a CodeLLDB port");
  return port;
}

async function connect(port: number, child: ChildProcess, timeoutMs: number, errorText: () => string): Promise<Socket> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (child.exitCode !== null || child.signalCode !== null) {
      throw new Error(`CodeLLDB exited before accepting DAP connections: ${errorText().trim()}`);
    }
    try {
      return await new Promise<Socket>((resolve, reject) => {
        const socket = net.createConnection({ host: "127.0.0.1", port });
        socket.once("connect", () => resolve(socket));
        socket.once("error", reject);
      });
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
  }
  throw new Error(`CodeLLDB did not listen on port ${port} within ${timeoutMs}ms`);
}

export class CodeLldbSession {
  private readonly eventQueues = new Map<string, unknown[]>();
  private readonly eventWaiters = new Map<string, EventWaiter[]>();
  private readonly breakpoints = new Map<string, Set<number>>();
  private readonly child: ChildProcess;
  private readonly socket: Socket;
  private readonly connection: ContentLengthConnection;
  private readonly timeoutMs: number;
  private closed = false;

  private constructor(
    child: ChildProcess,
    socket: Socket,
    connection: ContentLengthConnection,
    timeoutMs: number,
  ) {
    this.child = child;
    this.socket = socket;
    this.connection = connection;
    this.timeoutMs = timeoutMs;
    for (const name of ["initialized", "stopped", "terminated", "exited"]) {
      connection.onNotification(name, (body) => this.receiveEvent(name, body));
    }
  }

  static async start(options: CodeLldbStartOptions): Promise<CodeLldbSession> {
    const port = await reservePort();
    let stderr = "";
    const child = spawn(options.executable, [...(options.adapterArgs ?? []), "--port", String(port)], {
      cwd: options.cwd,
      env: options.env ?? process.env,
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    });
    child.stderr?.on("data", (chunk) => { stderr += Buffer.from(chunk).toString("utf8"); });
    const timeoutMs = options.timeoutMs ?? 10_000;
    try {
      await waitForSpawn(child);
      const socket = await connect(port, child, timeoutMs, () => stderr);
      const connection = new ContentLengthConnection(socket, socket, { mode: "dap", timeoutMs });
      const session = new CodeLldbSession(child, socket, connection, timeoutMs);
      await connection.request("initialize", {
        clientID: "pi",
        clientName: "Pi coding agent",
        adapterID: "codelldb",
        pathFormat: "path",
        linesStartAt1: true,
        columnsStartAt1: true,
        supportsVariableType: true,
        supportsRunInTerminalRequest: false,
      });
      return session;
    } catch (error) {
      await stopProcessTree(child);
      throw error;
    }
  }

  async launch(options: DebugLaunchOptions): Promise<StoppedEvent> {
    const initialized = this.waitForEvent("initialized");
    const launch = this.connection.request("launch", {
      program: options.program,
      args: options.args,
      cwd: options.cwd,
      env: options.env,
      stopOnEntry: options.breakpoints.length === 0,
      sourceLanguages: ["rust"],
    });
    // Anything throwing before `await launch` abandons it, and close() then rejects it.
    launch.catch(() => {});
    await initialized;
    for (const breakpoint of options.breakpoints) await this.setBreakpoint(breakpoint.path, breakpoint.line);
    const stopped = this.waitForStop();
    // A failed launch never stops, so close() rejects this waiter — claim it now to avoid an unhandled rejection.
    stopped.catch(() => {});
    await this.connection.request("configurationDone", {});
    await launch;
    return stopped;
  }

  async setBreakpoint(path: string, line: number): Promise<{ verified: boolean; line?: number; message?: string }> {
    const lines = this.breakpoints.get(path) ?? new Set<number>();
    lines.add(line);
    this.breakpoints.set(path, lines);
    const result = await this.connection.request("setBreakpoints", {
      source: { path },
      breakpoints: [...lines].sort((a, b) => a - b).map((value) => ({ line: value })),
      sourceModified: false,
    }) as { breakpoints?: Array<{ verified: boolean; line?: number; message?: string }> };
    return result.breakpoints?.find((item) => item.line === line) ?? result.breakpoints?.at(-1) ?? { verified: false };
  }

  continue(threadId: number): Promise<StoppedEvent> {
    return this.resume("continue", { threadId }, "continue");
  }

  next(threadId: number): Promise<StoppedEvent> {
    return this.resume("next", { threadId, singleThread: false }, "next");
  }

  stepIn(threadId: number): Promise<StoppedEvent> {
    return this.resume("stepIn", { threadId, singleThread: false }, "stepIn");
  }

  stepOut(threadId: number): Promise<StoppedEvent> {
    return this.resume("stepOut", { threadId, singleThread: false }, "stepOut");
  }

  async threads(): Promise<DapThread[]> {
    const result = await this.connection.request("threads", {}) as { threads?: DapThread[] };
    return result.threads ?? [];
  }

  async stackTrace(threadId: number, startFrame = 0, levels = 50): Promise<{ frames: DapStackFrame[]; totalFrames?: number }> {
    const result = await this.connection.request("stackTrace", { threadId, startFrame, levels }) as { stackFrames?: DapStackFrame[]; totalFrames?: number };
    return { frames: result.stackFrames ?? [], totalFrames: result.totalFrames };
  }

  async scopes(frameId: number): Promise<DapScope[]> {
    const result = await this.connection.request("scopes", { frameId }) as { scopes?: DapScope[] };
    return result.scopes ?? [];
  }

  async variables(variablesReference: number, start = 0, count = 100): Promise<DapVariable[]> {
    const result = await this.connection.request("variables", { variablesReference, start, count }) as { variables?: DapVariable[] };
    return result.variables ?? [];
  }

  evaluate(expression: string, frameId?: number): Promise<{ result: string; type?: string; variablesReference: number }> {
    return this.connection.request("evaluate", { expression, frameId, context: "watch" }) as Promise<{ result: string; type?: string; variablesReference: number }>;
  }

  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    for (const waiters of this.eventWaiters.values()) {
      for (const waiter of waiters) {
        clearTimeout(waiter.timer);
        waiter.reject(new Error("debug session closed"));
      }
    }
    this.eventWaiters.clear();
    try {
      await this.connection.request("disconnect", { restart: false, terminateDebuggee: true }, { timeoutMs: 1000 });
    } catch {
      await stopProcessTree(this.child);
    }
    await this.connection.close();
    this.socket.destroy();
    await stopProcessTree(this.child);
  }

  private async resume(command: string, args: Record<string, unknown>, label: string): Promise<StoppedEvent> {
    const stopped = this.waitForStop();
    await this.connection.request(command, args);
    try {
      return await stopped;
    } catch (error) {
      throw new Error(`${label} failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async waitForStop(): Promise<StoppedEvent> {
    const event = await this.waitForAny(["stopped", "terminated", "exited"]);
    if (event.name === "stopped") return event.body as StoppedEvent;
    return { reason: event.name, terminated: true };
  }

  private async waitForEvent(name: string): Promise<unknown> {
    return (await this.waitForAny([name])).body;
  }

  private waitForAny(names: string[]): Promise<{ name: string; body: unknown }> {
    for (const name of names) {
      const queued = this.eventQueues.get(name);
      if (queued?.length) return Promise.resolve({ name, body: queued.shift() });
    }
    return new Promise((resolve, reject) => {
      const registered: Array<{ name: string; waiter: EventWaiter }> = [];
      let settled = false;
      const cleanup = () => {
        for (const item of registered) {
          const waiters = this.eventWaiters.get(item.name) ?? [];
          const remaining = waiters.filter((candidate) => candidate !== item.waiter);
          if (remaining.length === 0) this.eventWaiters.delete(item.name);
          else this.eventWaiters.set(item.name, remaining);
        }
      };
      const timer = setTimeout(() => {
        if (settled) return;
        settled = true;
        cleanup();
        reject(new Error(`${names.join("/")} event timed out after ${this.timeoutMs}ms`));
      }, this.timeoutMs);
      for (const name of names) {
        const waiter: EventWaiter = {
          timer,
          resolve: (body) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            cleanup();
            resolve({ name, body });
          },
          reject: (error) => {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            cleanup();
            reject(error);
          },
        };
        registered.push({ name, waiter });
        const waiters = this.eventWaiters.get(name) ?? [];
        waiters.push(waiter);
        this.eventWaiters.set(name, waiters);
      }
    });
  }

  private receiveEvent(name: string, body: unknown): void {
    const waiters = this.eventWaiters.get(name);
    const waiter = waiters?.shift();
    if (waiter) {
      clearTimeout(waiter.timer);
      waiter.resolve(body);
      return;
    }
    const queue = this.eventQueues.get(name) ?? [];
    queue.push(body);
    this.eventQueues.set(name, queue);
  }
}
