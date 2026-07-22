import {
  lstat,
  mkdir,
  opendir,
  readFile,
  realpath,
  stat,
  writeFile,
} from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

export const REGISTRY_VERSION = 1;
export const SUPPORTED_TYPES = new Set(["skill", "command", "spec", "doc"]);

const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const PATH_SEGMENT = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

function parseScalar(value) {
  const trimmed = value.trim();
  if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return JSON.parse(trimmed);
  }
  if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
    return trimmed.slice(1, -1).replaceAll("''", "'");
  }
  if (trimmed === "true") return true;
  if (trimmed === "false") return false;
  if (trimmed === "null") return null;
  if (/^-?\d+(?:\.\d+)?$/.test(trimmed)) return Number(trimmed);
  return trimmed;
}

export function parseFrontmatter(source) {
  const lines = source.split("\n");
  if (lines[0] !== "---") return { metadata: {}, body: source };
  const closing = lines.indexOf("---", 1);
  if (closing === -1) throw new Error("frontmatter has no closing fence");

  const metadata = {};
  for (let index = 1; index < closing; index += 1) {
    const line = lines[index];
    if (!line.trim() || line.trimStart().startsWith("#")) continue;
    const match = line.match(/^([A-Za-z0-9_-]+):(?:\s*(.*))?$/);
    if (!match) continue;
    const [, key, raw = ""] = match;
    if (raw === ">" || raw === "|") {
      const block = [];
      while (index + 1 < closing) {
        const next = lines[index + 1];
        if (next && !/^\s/.test(next)) break;
        index += 1;
        block.push(next.replace(/^ {1,2}/, ""));
      }
      metadata[key] = raw === ">"
        ? block.join(" ").replace(/\s+/g, " ").trim()
        : `${block.join("\n").replace(/\n+$/, "")}\n`;
      continue;
    }
    metadata[key] = parseScalar(raw);
  }

  return {
    metadata,
    body: lines.slice(closing + 1).join("\n").replace(/^\n/, ""),
  };
}

function normalizePathName(path) {
  return path.split(sep).join("/").replace(/\.md$/, "");
}

function validName(type, name) {
  if (type === "skill" || type === "command") return SLUG.test(name);
  if (!name || name.startsWith("/") || name.includes("\\") || name.includes("//")) {
    return false;
  }
  return name.split("/").every(
    (segment) => segment !== "." && segment !== ".." && PATH_SEGMENT.test(segment),
  );
}

function descriptionFor(metadata, body, name) {
  if (typeof metadata.description === "string" && metadata.description.trim()) {
    return metadata.description.trim();
  }
  const heading = body.match(/^#\s+(.+)$/m)?.[1]?.trim();
  return heading || name;
}

export function extractTypedLinks(source) {
  const links = [];
  const seen = new Set();
  const prose = source
    .replace(/```[\s\S]*?```|~~~[\s\S]*?~~~/g, "")
    .replace(/`[^`\n]*`/g, "");
  for (const match of prose.matchAll(/\[\[([^\]\n]*)\]\]/g)) {
    const raw = match[0];
    const separator = match[1].indexOf(":");
    if (separator === -1) continue;
    const type = match[1].slice(0, separator);
    const name = match[1].slice(separator + 1);
    if (!SUPPORTED_TYPES.has(type)) continue;
    const key = `${type}:${name}`;
    if (seen.has(key)) continue;
    seen.add(key);
    links.push({
      raw,
      type,
      name,
      status: validName(type, name) ? "pending" : "malformed",
      targetId: undefined,
    });
  }
  return links;
}

function inside(root, target) {
  const rel = relative(root, target);
  return rel === "" || (!rel.startsWith(`..${sep}`) && rel !== ".." && !isAbsolute(rel));
}

async function exists(path) {
  try {
    await lstat(path);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function walk(root, { projectRoot, diagnostics, direct = false }) {
  if (!(await exists(root))) return [];
  const canonicalRoot = await realpath(root);
  if (projectRoot && !inside(projectRoot, canonicalRoot)) {
    diagnostics.push({
      code: "outside-root",
      message: `Resource root escapes project: ${root}`,
      path: root,
    });
    return [];
  }

  const files = [];
  const visited = new Set();
  async function visit(directory, depth) {
    const canonicalDirectory = await realpath(directory);
    if (projectRoot && !inside(projectRoot, canonicalDirectory)) {
      diagnostics.push({
        code: "outside-root",
        message: `Resource path escapes project: ${directory}`,
        path: directory,
      });
      return;
    }
    if (visited.has(canonicalDirectory)) return;
    visited.add(canonicalDirectory);

    const stream = await opendir(directory);
    for await (const entry of stream) {
      const path = resolve(directory, entry.name);
      let canonical;
      try {
        canonical = await realpath(path);
      } catch (error) {
        diagnostics.push({ code: "unreadable-resource", message: error.message, path });
        continue;
      }
      if (projectRoot && !inside(projectRoot, canonical)) {
        diagnostics.push({
          code: "outside-root",
          message: `Resource path escapes project: ${path}`,
          path,
        });
        continue;
      }
      const info = await stat(canonical);
      if (info.isDirectory()) {
        if (!direct && depth >= 0) await visit(path, depth + 1);
      } else if (info.isFile()) {
        files.push(canonical);
      }
    }
  }
  await visit(canonicalRoot, 0);
  return [...new Set(files)].sort();
}

async function makeEntry({ path, type, name, layer }) {
  if (!validName(type, name)) throw new Error(`invalid ${type} name: ${name}`);
  const source = await readFile(path, "utf8");
  const { metadata, body } = parseFrontmatter(source);
  if (type === "skill") {
    if (metadata.name !== name || typeof metadata.description !== "string" || !metadata.description.trim()) {
      throw new Error(`skill ${path} requires matching name and description`);
    }
  }
  const info = await stat(path);
  return {
    id: `${layer}:${type}:${name}`,
    type,
    name,
    layer,
    path,
    description: descriptionFor(metadata, body, name),
    metadata,
    adapter: type,
    links: extractTypedLinks(source),
    mtimeMs: layer === "project" ? info.mtimeMs : null,
  };
}

function resolveEntryLinks(entries) {
  const ids = new Set(entries.map((entry) => entry.id));
  return entries.map((entry) => ({
    ...entry,
    links: entry.links.map((link) => {
      if (link.status === "malformed") return link;
      const targetId = `${entry.layer}:${link.type}:${link.name}`;
      return ids.has(targetId)
        ? { ...link, status: "resolved", targetId }
        : { ...link, status: "missing-target", targetId: undefined };
    }),
  }));
}

function sortDiagnostics(diagnostics) {
  return diagnostics.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
}

async function collectEntries({ layer, skillRoots, commandRoots, projectRoot, diagnostics }) {
  const entries = [];
  for (const root of skillRoots) {
    const files = await walk(root, { projectRoot, diagnostics });
    for (const path of files.filter((candidate) => candidate.endsWith(`${sep}SKILL.md`))) {
      const parsed = parseFrontmatter(await readFile(path, "utf8"));
      const name = parsed.metadata.name;
      try {
        entries.push(await makeEntry({ path, type: "skill", name, layer }));
      } catch (error) {
        if (layer === "global") throw error;
        diagnostics.push({ code: "invalid-resource", message: error.message, path });
      }
    }
  }
  for (const root of commandRoots) {
    const files = await walk(root, { projectRoot, diagnostics, direct: true });
    for (const path of files.filter((candidate) => candidate.endsWith(".md"))) {
      const name = normalizePathName(relative(await realpath(root), path));
      try {
        entries.push(await makeEntry({ path, type: "command", name, layer }));
      } catch (error) {
        if (layer === "global") throw error;
        diagnostics.push({ code: "invalid-resource", message: error.message, path });
      }
    }
  }
  return entries;
}

function removeDuplicates(entries, layer, diagnostics) {
  const groups = Map.groupBy(entries, (entry) => entry.id);
  const result = [];
  for (const [id, group] of groups) {
    if (group.length === 1) {
      result.push(group[0]);
      continue;
    }
    if (layer === "global") throw new Error(`duplicate global resource: ${id}`);
    diagnostics.push({
      code: "duplicate-id",
      message: `Duplicate project resource: ${id}`,
      candidates: group.map((entry) => entry.path).sort(),
    });
  }
  return result;
}

export async function compileGlobalRegistry({ skillRoots = [], commandRoots = [] }) {
  const diagnostics = [];
  const entries = await collectEntries({
    layer: "global",
    skillRoots,
    commandRoots,
    projectRoot: null,
    diagnostics,
  });
  const unique = removeDuplicates(entries, "global", diagnostics);
  return {
    version: REGISTRY_VERSION,
    layer: "global",
    projectRoot: null,
    entries: resolveEntryLinks(unique).sort((a, b) => a.id.localeCompare(b.id)),
    diagnostics: sortDiagnostics(diagnostics),
  };
}

async function collectProjectMarkdown(root, type, projectRoot, diagnostics) {
  const files = await walk(root, { projectRoot, diagnostics });
  const entries = [];
  for (const path of files.filter((candidate) => candidate.endsWith(".md"))) {
    const name = normalizePathName(relative(await realpath(root), path));
    try {
      entries.push(await makeEntry({ path, type, name, layer: "project" }));
    } catch (error) {
      diagnostics.push({ code: "invalid-resource", message: error.message, path });
    }
  }
  return entries;
}

export async function compileProjectRegistry(projectRoot, { configDirName = ".pi" } = {}) {
  const root = await realpath(projectRoot);
  const diagnostics = [];
  const entries = await collectEntries({
    layer: "project",
    skillRoots: [resolve(root, ".agents", "skills"), resolve(root, configDirName, "skills")],
    commandRoots: [resolve(root, configDirName, "prompts")],
    projectRoot: root,
    diagnostics,
  });
  entries.push(...await collectProjectMarkdown(resolve(root, "specs"), "spec", root, diagnostics));
  entries.push(...await collectProjectMarkdown(resolve(root, "docs"), "doc", root, diagnostics));
  const unique = removeDuplicates(entries, "project", diagnostics);
  return {
    version: REGISTRY_VERSION,
    layer: "project",
    projectRoot: root,
    entries: resolveEntryLinks(unique).sort((a, b) => a.id.localeCompare(b.id)),
    diagnostics: sortDiagnostics(diagnostics),
  };
}

function parseReference(reference) {
  if (typeof reference !== "string") return { status: "malformed", reference };
  let value = reference.trim();
  if (value.startsWith("[[") && value.endsWith("]]")) value = value.slice(2, -2);
  const parts = value.split(":");
  let layer;
  let type;
  let name;
  if (parts.length >= 3 && (parts[0] === "global" || parts[0] === "project")) {
    [layer, type] = parts;
    name = parts.slice(2).join(":");
  } else if (parts.length >= 2) {
    [type] = parts;
    name = parts.slice(1).join(":");
  } else {
    return { status: "malformed", reference };
  }
  if (!SUPPORTED_TYPES.has(type)) return { status: "foreign-type", reference };
  if (!validName(type, name)) return { status: "malformed", reference };
  return { status: "parsed", reference, layer, type, name };
}

export function resolveReference({
  globalRegistry,
  projectRegistry,
  reference,
  originId,
}) {
  const parsed = parseReference(reference);
  if (parsed.status !== "parsed") return parsed;
  const originLayer = originId?.split(":", 1)[0];
  const requestedLayer = parsed.layer || (originLayer === "global" || originLayer === "project" ? originLayer : undefined);
  const registries = requestedLayer === "global"
    ? [globalRegistry]
    : requestedLayer === "project"
      ? [projectRegistry]
      : [globalRegistry, projectRegistry];
  const candidates = registries
    .filter(Boolean)
    .flatMap((registry) => registry.entries)
    .filter((entry) => entry.type === parsed.type && entry.name === parsed.name)
    .sort((a, b) => a.id.localeCompare(b.id));
  if (candidates.length === 0) return { status: "missing-target", reference };
  if (candidates.length > 1) {
    return {
      status: "ambiguous",
      reference,
      candidates: candidates.map((entry) => entry.id),
    };
  }
  return { status: "resolved", reference, target: candidates[0] };
}

export async function refreshProjectEntry(registry, id) {
  const entry = registry.entries.find((candidate) => candidate.id === id);
  if (!entry) throw new Error(`project resource not found: ${id}`);
  if (entry.layer !== "project" || !registry.projectRoot) return entry;
  const canonical = await realpath(entry.path);
  if (!inside(registry.projectRoot, canonical)) {
    throw new Error(`project resource escapes root: ${entry.path}`);
  }
  const refreshed = await makeEntry({
    path: canonical,
    type: entry.type,
    name: entry.name,
    layer: "project",
  });
  return resolveEntryLinks([
    ...registry.entries.filter((candidate) => candidate.id !== id),
    refreshed,
  ]).find((candidate) => candidate.id === id);
}

function parseCli(argv) {
  const result = { skillRoots: [], commandRoots: [], output: undefined };
  for (let index = 0; index < argv.length; index += 1) {
    const option = argv[index];
    const value = argv[index + 1];
    if (option === "--skill-root" && value) result.skillRoots.push(value);
    else if (option === "--command-root" && value) result.commandRoots.push(value);
    else if (option === "--output" && value) result.output = value;
    else throw new Error(`invalid CLI argument: ${option}`);
    index += 1;
  }
  if (!result.output) throw new Error("--output is required");
  return result;
}

async function main() {
  const [command, ...argv] = process.argv.slice(2);
  if (command !== "compile-global") throw new Error(`unknown command: ${command}`);
  const options = parseCli(argv);
  const registry = await compileGlobalRegistry(options);
  await mkdir(dirname(options.output), { recursive: true });
  await writeFile(options.output, `${JSON.stringify(registry, null, 2)}\n`, "utf8");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
