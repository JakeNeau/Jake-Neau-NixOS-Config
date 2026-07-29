import { access, readFile, readdir, stat } from "node:fs/promises";
import { dirname, isAbsolute, join, parse, resolve } from "node:path";

import { runProcess } from "./process.ts";

export interface RustRuntime {
  cargoPath: string;
  rustcPath: string;
  nixPath?: string;
  toolPath?: string;
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface CargoTarget {
  name: string;
  kind: string[];
  crateTypes: string[];
  srcPath: string;
}

export interface CargoPackage {
  id: string;
  name: string;
  manifestPath: string;
  targets: CargoTarget[];
}

export interface ProjectDocument {
  path: string;
  text: string;
  mtimeMs: number;
}

export interface CargoInvocation {
  executable: string;
  argsPrefix: string[];
  env: NodeJS.ProcessEnv;
}

export interface RustProject {
  root: string;
  manifestPath: string;
  packages: CargoPackage[];
  documents: ProjectDocument[];
  cargo: CargoInvocation;
}

export interface DiscoverProjectOptions {
  cwd: string;
  runtime: RustRuntime;
}

export interface DocExcerpt {
  path: string;
  heading: string;
  text: string;
  score: number;
}

export interface DocSearchLimits {
  maxResults: number;
  maxBytes: number;
}

export type DebugTargetKind = "bin" | "test" | "example" | "bench" | "lib";

export interface DebugTarget {
  package: string;
  packageId: string;
  name: string;
  kind: DebugTargetKind;
  sourcePath: string;
}

export interface DebugSelection {
  package: string;
  target: string;
  kind: DebugTargetKind;
  testFilter?: string;
}

export interface BuiltTarget {
  target: DebugTarget;
  executable: string;
  args: string[];
  buildStdout: string;
  buildStderr: string;
}

export interface RustDiagnostic {
  level: string;
  message: string;
  path: string;
  line?: number;
  column?: number;
  rendered?: string;
}

interface MetadataTarget {
  name: string;
  kind: string[];
  crate_types: string[];
  src_path: string;
}

interface MetadataPackage {
  id: string;
  name: string;
  manifest_path: string;
  targets: MetadataTarget[];
}

interface CargoMetadata {
  workspace_root: string;
  packages: MetadataPackage[];
}

interface DocumentCache {
  signature: string;
  documents: ProjectDocument[];
}

const documentCache = new Map<string, DocumentCache>();

interface CargoMessage {
  reason?: string;
  package_id?: string;
  target?: MetadataTarget;
  executable?: string;
  message?: {
    level?: string;
    message?: string;
    rendered?: string;
    spans?: Array<{
      file_name?: string;
      line_start?: number;
      column_start?: number;
      is_primary?: boolean;
    }>;
  };
}

async function findManifest(cwd: string): Promise<string> {
  let current = resolve(cwd);
  while (true) {
    const candidate = join(current, "Cargo.toml");
    try {
      await access(candidate);
      return candidate;
    } catch {
      const parent = dirname(current);
      if (parent === current) throw new Error(`No Cargo workspace found from ${cwd}`);
      current = parent;
    }
  }
}

function runtimeEnv(runtime: RustRuntime): NodeJS.ProcessEnv {
  return {
    ...process.env,
    PATH: runtime.toolPath
      ? `${runtime.toolPath}:${process.env.PATH ?? ""}`
      : process.env.PATH,
    RUSTC: runtime.rustcPath,
  };
}

async function cargoMetadata(manifestPath: string, runtime: RustRuntime): Promise<CargoMetadata> {
  const result = await runProcess({
    executable: runtime.cargoPath,
    args: ["metadata", "--format-version", "1", "--no-deps", "--manifest-path", manifestPath],
    cwd: dirname(manifestPath),
    env: runtimeEnv(runtime),
    timeoutMs: runtime.timeoutMs ?? 120_000,
    signal: runtime.signal,
  });
  if (result.code !== 0) {
    throw new Error(`cargo metadata failed: ${result.stderr.trim() || result.stdout.trim()}`);
  }
  return JSON.parse(result.stdout) as CargoMetadata;
}

async function collectMarkdownFiles(root: string): Promise<string[]> {
  const paths: string[] = [];
  // Instruction files a project may ship: project context, so these filenames
  // are incidental, not references to another tool's config.
  for (const name of ["AGENTS.md", "CLAUDE.md", "README.md"]) {
    const path = join(root, name);
    try {
      await access(path);
      paths.push(path);
    } catch {
      continue;
    }
  }
  const docsRoot = join(root, "docs");
  async function walk(directory: string): Promise<void> {
    let entries;
    try {
      entries = await readdir(directory, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const path = join(directory, entry.name);
      if (entry.isDirectory()) await walk(path);
      else if (entry.isFile() && entry.name.endsWith(".md")) paths.push(path);
    }
  }
  await walk(docsRoot);
  return [...new Set(paths)].sort();
}

async function loadDocuments(root: string): Promise<ProjectDocument[]> {
  const paths = await collectMarkdownFiles(root);
  const details = await Promise.all(paths.map(async (path) => ({ path, stat: await stat(path) })));
  const signature = details.map((item) => `${item.path}:${item.stat.mtimeMs}:${item.stat.size}`).join("\n");
  const cached = documentCache.get(root);
  if (cached?.signature === signature) return cached.documents;
  const documents = await Promise.all(details.map(async (item) => ({
    path: item.path,
    text: await readFile(item.path, "utf8"),
    mtimeMs: item.stat.mtimeMs,
  })));
  documentCache.set(root, { signature, documents });
  return documents;
}

function selectCargoInvocation(
  documents: ProjectDocument[],
  runtime: RustRuntime,
): CargoInvocation {
  if (runtime.nixPath) {
    for (const document of documents) {
      const match = document.text.match(/nix develop(?:\s+([^\s`]+))?\s+--command\s+cargo\b/);
      if (!match) continue;
      const env = { ...process.env };
      delete env.RUSTC;
      return {
        executable: runtime.nixPath,
        argsPrefix: ["develop", ...(match[1] ? [match[1]] : []), "--command", "cargo"],
        env,
      };
    }
  }
  return {
    executable: runtime.cargoPath,
    argsPrefix: [],
    env: runtimeEnv(runtime),
  };
}

export async function discoverRustProject(options: DiscoverProjectOptions): Promise<RustProject> {
  const manifest = await findManifest(options.cwd);
  const metadata = await cargoMetadata(manifest, options.runtime);
  const root = resolve(metadata.workspace_root);
  const documents = await loadDocuments(root);
  return {
    root,
    manifestPath: join(root, "Cargo.toml"),
    packages: metadata.packages.map((item) => ({
      id: item.id,
      name: item.name,
      manifestPath: item.manifest_path,
      targets: item.targets.map((target) => ({
        name: target.name,
        kind: target.kind,
        crateTypes: target.crate_types,
        srcPath: target.src_path,
      })),
    })),
    documents,
    cargo: selectCargoInvocation(documents, options.runtime),
  };
}

function tokenize(value: string): string[] {
  return [...new Set(value.toLowerCase().split(/[^a-z0-9_]+/).filter((item) => item.length > 1))];
}

function documentSections(document: ProjectDocument): Array<{ heading: string; text: string }> {
  const sections: Array<{ heading: string; text: string }> = [];
  let heading = parse(document.path).name;
  let lines: string[] = [];
  const flush = () => {
    if (lines.length === 0) return;
    sections.push({ heading, text: lines.join("\n").trim() });
    lines = [];
  };
  for (const line of document.text.split("\n")) {
    const match = line.match(/^#{1,6}\s+(.+)$/);
    if (match) {
      flush();
      heading = match[1].trim();
    } else {
      lines.push(line);
    }
  }
  flush();
  return sections;
}

export function searchProjectDocs(
  project: RustProject,
  query: string,
  limits: DocSearchLimits,
): DocExcerpt[] {
  const terms = tokenize(query);
  const matches: DocExcerpt[] = [];
  for (const document of project.documents) {
    for (const section of documentSections(document)) {
      const heading = section.heading.toLowerCase();
      const text = section.text.toLowerCase();
      const score = terms.reduce((total, term) => (
        total + (heading.includes(term) ? 5 : 0) + (text.includes(term) ? 1 : 0)
      ), 0);
      if (score > 0) matches.push({ path: document.path, ...section, score });
    }
  }
  const selected: DocExcerpt[] = [];
  let bytes = 0;
  for (const match of matches.sort((a, b) => b.score - a.score || a.path.localeCompare(b.path))) {
    const size = Buffer.byteLength(match.text);
    if (selected.length >= limits.maxResults) break;
    if (selected.length > 0 && bytes + size > limits.maxBytes) continue;
    const remaining = Math.max(0, limits.maxBytes - bytes);
    const text = Buffer.from(match.text).subarray(0, remaining).toString("utf8");
    selected.push({ ...match, text });
    bytes += Buffer.byteLength(text);
  }
  return selected;
}

function targetKind(kinds: string[]): DebugTargetKind | undefined {
  for (const kind of ["bin", "test", "example", "bench", "lib"] as const) {
    if (kinds.includes(kind)) return kind;
  }
  return undefined;
}

export function listDebugTargets(project: RustProject): DebugTarget[] {
  return project.packages.flatMap((pkg) => pkg.targets.flatMap((target) => {
    const kind = targetKind(target.kind);
    return kind ? [{
      package: pkg.name,
      packageId: pkg.id,
      name: target.name,
      kind,
      sourcePath: target.srcPath,
    }] : [];
  }));
}

function invokeCargo(
  project: RustProject,
  args: string[],
  runtime: RustRuntime,
) {
  return runProcess({
    executable: project.cargo.executable,
    args: [...project.cargo.argsPrefix, ...args],
    cwd: project.root,
    env: project.cargo.env,
    timeoutMs: runtime.timeoutMs ?? 120_000,
    signal: runtime.signal,
  });
}

function parseCargoMessages(output: string): CargoMessage[] {
  return output.split("\n").flatMap((line) => {
    if (!line.trim().startsWith("{")) return [];
    try {
      return [JSON.parse(line) as CargoMessage];
    } catch {
      return [];
    }
  });
}

function buildArguments(project: RustProject, target: DebugTarget): string[] {
  const common = [
    "--manifest-path", project.manifestPath,
    "-p", target.package,
    "--message-format=json-render-diagnostics",
  ];
  if (target.kind === "bin") return ["build", ...common, "--bin", target.name];
  if (target.kind === "test") return ["test", "--no-run", ...common, "--test", target.name];
  if (target.kind === "example") return ["build", ...common, "--example", target.name];
  if (target.kind === "bench") return ["test", "--no-run", ...common, "--bench", target.name];
  return ["test", "--no-run", ...common, "--lib"];
}

export async function buildDebugTarget(
  project: RustProject,
  selection: DebugSelection,
  runtime: RustRuntime,
): Promise<BuiltTarget> {
  const matches = listDebugTargets(project).filter((target) => (
    target.package === selection.package
    && target.name === selection.target
    && target.kind === selection.kind
  ));
  if (matches.length !== 1) {
    throw new Error(`Debug target ${selection.package}:${selection.kind}:${selection.target} is not unique`);
  }
  const target = matches[0];
  const result = await invokeCargo(project, buildArguments(project, target), runtime);
  const artifacts = parseCargoMessages(result.stdout).filter((message) => (
    message.reason === "compiler-artifact"
    && message.executable
    && message.target?.name === target.name
    && message.target.kind.includes(target.kind)
  ));
  const executable = artifacts.at(-1)?.executable;
  if (result.code !== 0 || !executable) {
    throw new Error(`Cargo did not produce ${target.name}: ${result.stderr.trim() || result.stdout.trim()}`);
  }
  return {
    target,
    executable,
    args: selection.testFilter && target.kind !== "bin" ? [selection.testFilter, "--nocapture"] : [],
    buildStdout: result.stdout,
    buildStderr: result.stderr,
  };
}

export async function collectCargoDiagnostics(
  project: RustProject,
  runtime: RustRuntime,
): Promise<RustDiagnostic[]> {
  const result = await invokeCargo(project, [
    "check",
    "--manifest-path", project.manifestPath,
    "--workspace",
    "--all-targets",
    "--message-format=json",
  ], runtime);
  return parseCargoMessages(result.stdout).flatMap((item) => {
    if (item.reason !== "compiler-message" || !item.message?.message || !item.message.level) return [];
    const span = item.message.spans?.find((candidate) => candidate.is_primary) ?? item.message.spans?.[0];
    const path = span?.file_name
      ? (isAbsolute(span.file_name) ? span.file_name : resolve(project.root, span.file_name))
      : project.root;
    return [{
      level: item.message.level,
      message: item.message.message,
      path,
      line: span?.line_start,
      column: span?.column_start,
      rendered: item.message.rendered,
    }];
  });
}
