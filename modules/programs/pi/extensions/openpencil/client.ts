import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { createInterface } from "node:readline";

export type McpTool = {
  name: string;
  description?: string;
  inputSchema: Record<string, unknown>;
};

export type McpContent =
  | { type: "text"; text: string }
  | { type: "image"; data: string; mimeType: string }
  | Record<string, unknown>;

export type McpToolResult = {
  content: McpContent[];
  isError?: boolean;
  structuredContent?: unknown;
};

type PendingRequest = {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
};

export class OpenPencilMcpClient {
  private child?: ChildProcessWithoutNullStreams;
  private cwd?: string;
  private nextId = 1;
  private pending = new Map<number, PendingRequest>();
  private starting?: Promise<void>;
  private stderr = "";

  private readonly command: string;
  private readonly args: string[];

  constructor(command: string, args: string[] = []) {
    this.command = command;
    this.args = args;
  }

  async listTools(cwd: string, signal?: AbortSignal): Promise<McpTool[]> {
    await this.ensureStarted(cwd, signal);
    const tools: McpTool[] = [];
    let cursor: string | undefined;
    do {
      const result = await this.request(
        "tools/list",
        cursor ? { cursor } : {},
        signal,
      ) as { tools?: McpTool[]; nextCursor?: string };
      tools.push(...(result.tools ?? []));
      cursor = result.nextCursor;
    } while (cursor);
    return tools;
  }

  async callTool(
    name: string,
    args: Record<string, unknown>,
    cwd: string,
    signal?: AbortSignal,
  ): Promise<McpToolResult> {
    await this.ensureStarted(cwd, signal);
    return this.request("tools/call", { name, arguments: args }, signal) as Promise<McpToolResult>;
  }

  async close(): Promise<void> {
    const child = this.child;
    this.child = undefined;
    this.starting = undefined;
    if (!child || child.exitCode !== null) return;

    child.kill("SIGTERM");
    await Promise.race([
      new Promise<void>((resolve) => child.once("exit", () => resolve())),
      new Promise<void>((resolve) => setTimeout(resolve, 1000)),
    ]);
    if (child.exitCode === null) child.kill("SIGKILL");
  }

  private async ensureStarted(cwd: string, signal?: AbortSignal): Promise<void> {
    if (this.child && this.cwd === cwd && this.child.exitCode === null) return;
    if (this.child && this.cwd !== cwd) await this.close();
    if (this.starting) return this.starting;

    this.cwd = cwd;
    this.starting = this.start(cwd, signal).catch((error) => {
      this.starting = undefined;
      throw error;
    });
    return this.starting;
  }

  private async start(cwd: string, signal?: AbortSignal): Promise<void> {
    this.stderr = "";
    const child = spawn(this.command, this.args, {
      cwd,
      env: { ...process.env, OPENPENCIL_MCP_ROOT: cwd },
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.child = child;

    createInterface({ input: child.stdout }).on("line", (line) => this.handleLine(line));
    child.stderr.on("data", (chunk) => {
      this.stderr = `${this.stderr}${String(chunk)}`.slice(-8192);
    });
    child.once("error", (error) => this.rejectAll(error));
    child.once("exit", (code, exitSignal) => {
      const detail = this.stderr.trim();
      const suffix = detail ? `: ${detail}` : "";
      this.rejectAll(new Error(`OpenPencil MCP server exited (${code ?? exitSignal})${suffix}`));
    });

    await this.request("initialize", {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "pi-openpencil", version: "1" },
    }, signal);
    this.notify("notifications/initialized", {});
  }

  private request(method: string, params: unknown, signal?: AbortSignal): Promise<unknown> {
    const child = this.child;
    if (!child || child.exitCode !== null) {
      return Promise.reject(new Error("OpenPencil MCP server is not running"));
    }

    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`OpenPencil MCP request timed out: ${method}`));
      }, 15000);
      const onAbort = () => {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(new Error(`OpenPencil MCP request cancelled: ${method}`));
      };
      if (signal?.aborted) return onAbort();
      signal?.addEventListener("abort", onAbort, { once: true });

      this.pending.set(id, {
        resolve: (value) => {
          signal?.removeEventListener("abort", onAbort);
          resolve(value);
        },
        reject: (error) => {
          signal?.removeEventListener("abort", onAbort);
          reject(error);
        },
        timer,
      });
      child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    });
  }

  private notify(method: string, params: unknown): void {
    this.child?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  }

  private handleLine(line: string): void {
    let message: { id?: number; result?: unknown; error?: { message?: string } };
    try {
      message = JSON.parse(line);
    } catch {
      return;
    }
    if (typeof message.id !== "number") return;
    const pending = this.pending.get(message.id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pending.delete(message.id);
    if (message.error) {
      pending.reject(new Error(message.error.message ?? "OpenPencil MCP request failed"));
    } else {
      pending.resolve(message.result);
    }
  }

  private rejectAll(error: Error): void {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(error);
    }
    this.pending.clear();
  }
}
