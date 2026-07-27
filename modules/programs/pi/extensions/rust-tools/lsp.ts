import { spawn, type ChildProcess } from "node:child_process";
import { readFile } from "node:fs/promises";
import { pathToFileURL, fileURLToPath } from "node:url";

import { ContentLengthConnection } from "./protocol.ts";
import { stopProcessTree, waitForSpawn } from "./process.ts";

export interface SourcePosition {
  path: string;
  line: number;
  column: number;
}

export interface SourceRange {
  start: { line: number; column: number };
  end: { line: number; column: number };
}

export interface SourceLocation {
  path: string;
  range: SourceRange;
}

export interface RustSymbol extends SourceLocation {
  name: string;
  kind: number;
}

export interface RustHover {
  text: string;
  range?: SourceRange;
}

export interface RustCall {
  name: string;
  path: string;
  range: SourceRange;
}

export interface RustCalls {
  incoming: RustCall[];
  outgoing: RustCall[];
}

export interface AnalyzerDiagnostic {
  message: string;
  severity?: number;
  range: SourceRange;
}

export interface RustAnalyzerStartOptions {
  executable: string;
  args?: string[];
  cwd: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
}

interface LspPosition {
  line: number;
  character: number;
}

interface LspRange {
  start: LspPosition;
  end: LspPosition;
}

interface LspLocation {
  uri: string;
  range: LspRange;
}

interface LspLocationLink {
  targetUri: string;
  targetRange: LspRange;
  targetSelectionRange: LspRange;
}

interface LspSymbol {
  name: string;
  kind: number;
  location: LspLocation;
}

interface CallItem {
  name: string;
  uri: string;
  range: LspRange;
  selectionRange: LspRange;
}

function range(value: LspRange): SourceRange {
  return {
    start: { line: value.start.line + 1, column: value.start.character + 1 },
    end: { line: value.end.line + 1, column: value.end.character + 1 },
  };
}

function location(value: LspLocation): SourceLocation {
  return { path: fileURLToPath(value.uri), range: range(value.range) };
}

function definitionLocation(value: LspLocation | LspLocationLink): SourceLocation {
  return "targetUri" in value
    ? { path: fileURLToPath(value.targetUri), range: range(value.targetSelectionRange ?? value.targetRange) }
    : location(value);
}

function lspPoint(value: SourcePosition) {
  return {
    textDocument: { uri: pathToFileURL(value.path).href },
    position: { line: value.line - 1, character: value.column - 1 },
  };
}

function hoverText(contents: unknown): string {
  if (typeof contents === "string") return contents;
  if (Array.isArray(contents)) return contents.map(hoverText).filter(Boolean).join("\n");
  if (!contents || typeof contents !== "object") return "";
  const value = contents as { value?: unknown; language?: unknown };
  if (typeof value.value !== "string") return "";
  return typeof value.language === "string"
    ? `\`\`\`${value.language}\n${value.value}\n\`\`\``
    : value.value;
}

export class RustAnalyzerSession {
  private readonly diagnosticsByPath = new Map<string, AnalyzerDiagnostic[]>();
  private readonly openDocuments = new Map<string, { version: number; text: string }>();
  private readonly child: ChildProcess;
  private readonly connection: ContentLengthConnection;
  private closed = false;

  private constructor(child: ChildProcess, connection: ContentLengthConnection) {
    this.child = child;
    this.connection = connection;
  }

  static async start(options: RustAnalyzerStartOptions): Promise<RustAnalyzerSession> {
    const child = spawn(options.executable, options.args ?? [], {
      cwd: options.cwd,
      env: options.env ?? process.env,
      detached: true,
      stdio: ["pipe", "pipe", "pipe"],
    });
    let startupError = "";
    child.stderr?.on("data", (chunk) => { startupError += Buffer.from(chunk).toString("utf8"); });
    await waitForSpawn(child);
    if (!child.stdin || !child.stdout) throw new Error("rust-analyzer did not expose stdio");
    const connection = new ContentLengthConnection(child.stdout, child.stdin, {
      timeoutMs: options.timeoutMs ?? 30_000,
    });
    const session = new RustAnalyzerSession(child, connection);
    let resolveReady: (() => void) | undefined;
    const ready = new Promise<void>((resolve) => { resolveReady = resolve; });
    connection.onNotification("experimental/serverStatus", (params) => {
      const value = params as { health?: string; quiescent?: boolean };
      if (value.health === "ok" && value.quiescent) resolveReady?.();
    });
    connection.onNotification("textDocument/publishDiagnostics", (params) => {
      const value = params as { uri?: string; diagnostics?: Array<{ message: string; severity?: number; range: LspRange }> };
      if (!value.uri) return;
      session.diagnosticsByPath.set(fileURLToPath(value.uri), (value.diagnostics ?? []).map((item) => ({
        message: item.message,
        severity: item.severity,
        range: range(item.range),
      })));
    });
    try {
      await connection.request("initialize", {
        processId: process.pid,
        rootUri: pathToFileURL(options.cwd).href,
        capabilities: {
          textDocument: {
            definition: { linkSupport: true },
            hover: { contentFormat: ["markdown", "plaintext"] },
            references: {},
            callHierarchy: { dynamicRegistration: false },
            publishDiagnostics: { relatedInformation: true },
          },
          workspace: { symbol: { resolveSupport: { properties: ["location.range"] } } },
          experimental: { serverStatusNotification: true },
        },
        workspaceFolders: [{ uri: pathToFileURL(options.cwd).href, name: options.cwd.split("/").at(-1) }],
      });
      await connection.notify("initialized", {});
      const readyTimeoutMs = options.timeoutMs ?? 30_000;
      let readyTimer: NodeJS.Timeout | undefined;
      await Promise.race([
        ready,
        new Promise<never>((_resolve, reject) => {
          readyTimer = setTimeout(
            () => reject(new Error(`rust-analyzer did not become ready within ${readyTimeoutMs}ms`)),
            readyTimeoutMs,
          );
        }),
      ]).finally(() => {
        if (readyTimer) clearTimeout(readyTimer);
      });
      return session;
    } catch (error) {
      await session.close();
      const suffix = startupError.trim() ? `: ${startupError.trim()}` : "";
      throw new Error(`${error instanceof Error ? error.message : String(error)}${suffix}`);
    }
  }

  async symbols(query: string): Promise<RustSymbol[]> {
    const result = await this.connection.request("workspace/symbol", { query }) as LspSymbol[] | null;
    return (result ?? []).flatMap((item) => item.location?.uri ? [{
      name: item.name,
      kind: item.kind,
      ...location(item.location),
    }] : []);
  }

  async definition(point: SourcePosition): Promise<SourceLocation[]> {
    await this.ensureOpen(point.path);
    const result = await this.connection.request("textDocument/definition", lspPoint(point)) as LspLocation | LspLocationLink | Array<LspLocation | LspLocationLink> | null;
    return (Array.isArray(result) ? result : result ? [result] : []).map(definitionLocation);
  }

  async hover(point: SourcePosition): Promise<RustHover | undefined> {
    await this.ensureOpen(point.path);
    const result = await this.connection.request("textDocument/hover", lspPoint(point)) as { contents: unknown; range?: LspRange } | null;
    return result ? { text: hoverText(result.contents), range: result.range ? range(result.range) : undefined } : undefined;
  }

  async references(point: SourcePosition): Promise<SourceLocation[]> {
    await this.ensureOpen(point.path);
    const result = await this.connection.request("textDocument/references", {
      ...lspPoint(point),
      context: { includeDeclaration: true },
    }) as LspLocation[] | null;
    return (result ?? []).map(location);
  }

  async callers(point: SourcePosition): Promise<RustCalls> {
    await this.ensureOpen(point.path);
    const prepared = await this.connection.request("textDocument/prepareCallHierarchy", lspPoint(point)) as CallItem[] | null;
    const item = prepared?.[0];
    if (!item) return { incoming: [], outgoing: [] };
    const [incoming, outgoing] = await Promise.all([
      this.connection.request("callHierarchy/incomingCalls", { item }) as Promise<Array<{ from: CallItem }> | null>,
      this.connection.request("callHierarchy/outgoingCalls", { item }) as Promise<Array<{ to: CallItem }> | null>,
    ]);
    const convert = (value: CallItem): RustCall => ({
      name: value.name,
      path: fileURLToPath(value.uri),
      range: range(value.selectionRange ?? value.range),
    });
    return {
      incoming: (incoming ?? []).map((entry) => convert(entry.from)),
      outgoing: (outgoing ?? []).map((entry) => convert(entry.to)),
    };
  }

  diagnostics(path?: string): AnalyzerDiagnostic[] {
    if (path) return this.diagnosticsByPath.get(path) ?? [];
    return [...this.diagnosticsByPath.values()].flat();
  }

  async close(): Promise<void> {
    if (this.closed) return;
    this.closed = true;
    try {
      await this.connection.request("shutdown", null, { timeoutMs: 1000 });
      await this.connection.notify("exit", null);
    } catch {
      await stopProcessTree(this.child);
    }
    await this.connection.close();
    await stopProcessTree(this.child);
  }

  private async ensureOpen(path: string): Promise<void> {
    const text = await readFile(path, "utf8");
    const current = this.openDocuments.get(path);
    if (!current) {
      await this.connection.notify("textDocument/didOpen", {
        textDocument: {
          uri: pathToFileURL(path).href,
          languageId: "rust",
          version: 1,
          text,
        },
      });
      this.openDocuments.set(path, { version: 1, text });
      return;
    }
    if (current.text === text) return;
    const version = current.version + 1;
    await this.connection.notify("textDocument/didChange", {
      textDocument: { uri: pathToFileURL(path).href, version },
      contentChanges: [{ text }],
    });
    this.openDocuments.set(path, { version, text });
  }
}
