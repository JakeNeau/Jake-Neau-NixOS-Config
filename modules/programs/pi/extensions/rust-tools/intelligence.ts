import type { ExtensionAPI, ExtensionFactory } from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";

import {
  RustAnalyzerSession,
  type RustAnalyzerStartOptions,
  type RustSymbol,
  type SourcePosition,
} from "./lsp.ts";
import {
  collectCargoDiagnostics,
  discoverRustProject,
  listDebugTargets,
  searchProjectDocs,
  type RustProject,
  type RustRuntime,
} from "./project.ts";

interface Analyzer {
  symbols(query: string): Promise<RustSymbol[]>;
  definition(point: SourcePosition): Promise<unknown[]>;
  hover(point: SourcePosition): Promise<{ text: string } | undefined>;
  references(point: SourcePosition): Promise<unknown[]>;
  callers(point: SourcePosition): Promise<{ incoming: unknown[]; outgoing: unknown[] }>;
  diagnostics(path?: string): unknown[];
  close(): Promise<void>;
}

export interface RustIntelligenceConfig {
  rustAnalyzerPath: string;
  cargoPath: string;
  rustcPath: string;
  nixPath?: string;
  toolPath?: string;
  timeoutMs?: number;
  maxBytes?: number;
  maxLines?: number;
  startAnalyzer?: (project: RustProject, config: RustIntelligenceConfig) => Promise<Analyzer>;
}

interface RustCodeInput {
  action: "overview" | "symbol" | "definition" | "hover" | "references" | "callers" | "diagnostics" | "context";
  query?: string;
  path?: string;
  line?: number;
  column?: number;
  limit?: number;
}

const actions = ["overview", "symbol", "definition", "hover", "references", "callers", "diagnostics", "context"];

function schema() {
  return {
    type: "object",
    properties: {
      action: { type: "string", enum: actions },
      query: { type: "string" },
      path: { type: "string" },
      line: { type: "integer", minimum: 1 },
      column: { type: "integer", minimum: 1 },
      limit: { type: "integer", minimum: 1, maximum: 100 },
    },
    required: ["action"],
    additionalProperties: false,
  };
}

function display(value: unknown): string {
  return JSON.stringify(value, null, 2);
}

function truncate(value: string, maxBytes: number, maxLines: number) {
  const lines = value.split("\n");
  let text = lines.slice(0, maxLines).join("\n");
  let truncated = lines.length > maxLines;
  if (Buffer.byteLength(text) > maxBytes) {
    text = Buffer.from(text).subarray(0, maxBytes).toString("utf8");
    truncated = true;
  }
  if (truncated) text += "\n\n[Output truncated]";
  return { text, truncated };
}

function toolResult(value: unknown, details: Record<string, unknown>, config: RustIntelligenceConfig) {
  const output = truncate(display(value), config.maxBytes ?? 50 * 1024, config.maxLines ?? 2000);
  return {
    content: [{ type: "text", text: output.text }],
    details: { ...details, truncated: output.truncated },
  };
}

function pointFrom(input: RustCodeInput): SourcePosition | undefined {
  return input.path && input.line
    ? { path: input.path, line: input.line, column: input.column ?? 1 }
    : undefined;
}

async function symbolPoint(analyzer: Analyzer, input: RustCodeInput): Promise<{ point?: SourcePosition; candidates?: RustSymbol[] }> {
  const direct = pointFrom(input);
  if (direct) return { point: direct };
  if (!input.query) return {};
  const symbols = await analyzer.symbols(input.query);
  const exact = symbols.filter((item) => item.name === input.query);
  const candidates = exact.length > 0 ? exact : symbols;
  if (candidates.length !== 1) return { candidates };
  return {
    point: {
      path: candidates[0].path,
      line: candidates[0].range.start.line,
      column: candidates[0].range.start.column,
    },
  };
}

export function resolveRustAnalyzerStart(
  project: Pick<RustProject, "root" | "cargo">,
  config: RustIntelligenceConfig,
): RustAnalyzerStartOptions {
  if (config.nixPath && project.cargo.executable === config.nixPath) {
    const args = [...project.cargo.argsPrefix];
    const cargoIndex = args.lastIndexOf("cargo");
    if (cargoIndex !== -1) args.splice(cargoIndex, 1, config.rustAnalyzerPath);
    return {
      executable: config.nixPath,
      args,
      cwd: project.root,
      env: project.cargo.env,
      timeoutMs: config.timeoutMs,
    };
  }
  return {
    executable: config.rustAnalyzerPath,
    cwd: project.root,
    env: {
      ...process.env,
      PATH: config.toolPath
        ? `${config.toolPath}:${process.env.PATH ?? ""}`
        : process.env.PATH,
      RUSTC: config.rustcPath,
    },
    timeoutMs: config.timeoutMs,
  };
}

function sourceExcerpt(source: string, symbol: RustSymbol): string {
  const lines = source.split("\n");
  const start = Math.max(0, symbol.range.start.line - 4);
  const end = Math.min(lines.length, symbol.range.end.line + 4);
  return lines.slice(start, end).map((line, index) => `${start + index + 1}: ${line}`).join("\n");
}

export function createRustIntelligence(config: RustIntelligenceConfig): ExtensionFactory {
  return function rustIntelligence(pi: ExtensionAPI) {
    let analyzer: Analyzer | undefined;
    let analyzerRoot: string | undefined;

    const runtime = (signal?: AbortSignal): RustRuntime => ({
      cargoPath: config.cargoPath,
      rustcPath: config.rustcPath,
      nixPath: config.nixPath,
      toolPath: config.toolPath,
      timeoutMs: config.timeoutMs,
      signal,
    });

    const getAnalyzer = async (project: RustProject): Promise<Analyzer> => {
      if (analyzer && analyzerRoot === project.root) return analyzer;
      await analyzer?.close();
      analyzer = config.startAnalyzer
        ? await config.startAnalyzer(project, config)
        : await RustAnalyzerSession.start(resolveRustAnalyzerStart(project, config));
      analyzerRoot = project.root;
      return analyzer;
    };

    pi.registerTool({
      name: "rust_code",
      label: "Rust Code",
      description: "Navigate and inspect Rust code with project documentation, Cargo metadata, and rust-analyzer",
      promptSnippet: "Use compiler-aware Rust symbols, references, callers, diagnostics, and compact context",
      promptGuidelines: [
        "Use rust_code before broad Rust file reads, and consult its project documentation results before choosing build or test commands.",
      ],
      parameters: schema(),
      async execute(_id: string, input: RustCodeInput, signal: AbortSignal | undefined, _onUpdate: unknown, ctx: { cwd: string; isProjectTrusted(): boolean }) {
        if (input.path) {
          const path = input.path.replace(/^@/, "");
          input = { ...input, path: isAbsolute(path) ? path : resolve(ctx.cwd, path) };
        }
        const project = await discoverRustProject({ cwd: ctx.cwd, runtime: runtime(signal) });
        if (input.action === "overview") {
          const value = {
            root: project.root,
            packages: project.packages.map((item) => item.name),
            targets: listDebugTargets(project),
            documents: project.documents.map((item) => relative(project.root, item.path)),
          };
          return toolResult(value, value, config);
        }
        if (input.action === "diagnostics") {
          if (!ctx.isProjectTrusted()) throw new Error("Cargo diagnostics require a trusted project");
          const diagnostics = await collectCargoDiagnostics(project, runtime(signal));
          return toolResult(diagnostics, { diagnostics }, config);
        }

        if (!ctx.isProjectTrusted()) throw new Error("rust-analyzer requires a trusted project");
        const session = await getAnalyzer(project);
        if (input.action === "symbol") {
          if (!input.query) throw new Error("rust_code symbol requires query");
          const symbols = (await session.symbols(input.query)).slice(0, input.limit ?? 20);
          return toolResult(symbols, { symbols }, config);
        }
        if (input.action === "context") {
          if (!input.query) throw new Error("rust_code context requires query");
          const docs = searchProjectDocs(project, input.query, { maxResults: 4, maxBytes: 12_000 });
          const terms = [...new Set(input.query.toLowerCase().split(/[^a-z0-9_]+/).filter((item) => item.length > 2))].slice(0, 6);
          const found = (await Promise.all(terms.map((term) => session.symbols(term)))).flat();
          const symbols = [...new Map(found.map((item) => [`${item.path}:${item.range.start.line}:${item.name}`, item])).values()]
            .slice(0, input.limit ?? 8);
          const diagnostics = session.diagnostics();
          const sections: string[] = diagnostics.length > 0
            ? [`## Current diagnostics\n${display(diagnostics)}`]
            : [];
          for (const doc of docs) sections.push(`## ${doc.heading}\n${relative(project.root, doc.path)}\n${doc.text}`);
          for (const symbol of symbols.slice(0, 3)) {
            const point = {
              path: symbol.path,
              line: symbol.range.start.line,
              column: symbol.range.start.column,
            };
            const [source, hover, calls, references] = await Promise.all([
              readFile(symbol.path, "utf8"),
              session.hover(point),
              session.callers(point),
              session.references(point),
            ]);
            sections.push([
              `## ${symbol.name}`,
              `${relative(project.root, symbol.path)}:${symbol.range.start.line}`,
              hover?.text ?? "",
              `Incoming calls: ${display(calls.incoming.slice(0, 8))}`,
              `Outgoing calls: ${display(calls.outgoing.slice(0, 8))}`,
              `References: ${display(references.slice(0, 12))}`,
              sourceExcerpt(source, symbol),
            ].join("\n"));
          }
          const output = truncate(sections.join("\n\n"), config.maxBytes ?? 50 * 1024, config.maxLines ?? 2000);
          return {
            content: [{ type: "text", text: output.text }],
            details: { documents: docs.map((item) => item.path), symbols, diagnostics, truncated: output.truncated },
          };
        }

        const resolved = await symbolPoint(session, input);
        if (!resolved.point) {
          if (resolved.candidates) {
            return toolResult(
              { status: "ambiguous", candidates: resolved.candidates },
              { status: "ambiguous", candidates: resolved.candidates },
              config,
            );
          }
          throw new Error(`rust_code ${input.action} requires query or path and line`);
        }
        let value: unknown;
        if (input.action === "definition") value = await session.definition(resolved.point);
        else if (input.action === "hover") value = await session.hover(resolved.point);
        else if (input.action === "references") value = await session.references(resolved.point);
        else value = await session.callers(resolved.point);
        return toolResult(value, { value }, config);
      },
    });

    pi.on("session_shutdown", async () => {
      await analyzer?.close();
      analyzer = undefined;
      analyzerRoot = undefined;
    });
  };
}
