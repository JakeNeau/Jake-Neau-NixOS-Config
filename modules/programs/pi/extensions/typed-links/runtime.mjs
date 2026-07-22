import { lstat, readFile, realpath } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";

import {
  compileProjectRegistry,
  extractTypedLinks,
  refreshProjectEntry,
  REGISTRY_VERSION,
  resolveReference,
} from "./registry.mjs";
import {
  formatOutgoingLinks,
  formatReadLinkFooter,
  loadLinkedResource,
} from "./adapters.ts";

async function pathExists(path) {
  try {
    await lstat(path);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function findProjectRoot(cwd) {
  const start = await realpath(cwd);
  let current = start;
  while (true) {
    if (await pathExists(resolve(current, ".git"))) return current;
    const parent = dirname(current);
    if (parent === current) return start;
    current = parent;
  }
}

function inside(root, target) {
  const rel = relative(root, target);
  return rel === "" || (!rel.startsWith(`..${sep}`) && rel !== ".." && !isAbsolute(rel));
}

function diagnostic(code, message, path) {
  return { code, message, ...(path ? { path } : {}) };
}

async function readGlobalRegistry(path) {
  try {
    const parsed = JSON.parse(await readFile(path, "utf8"));
    if (
      parsed?.version !== REGISTRY_VERSION
      || parsed?.layer !== "global"
      || !Array.isArray(parsed?.entries)
      || !Array.isArray(parsed?.diagnostics)
    ) {
      throw new Error(`expected registry version ${REGISTRY_VERSION}`);
    }
    return { registry: parsed, diagnostics: [] };
  } catch (error) {
    const code = error?.code === "ENOENT"
      ? "global-registry-missing"
      : error instanceof SyntaxError
        ? "global-registry-malformed"
        : "global-registry-incompatible";
    return {
      registry: null,
      diagnostics: [diagnostic(code, error.message, path)],
    };
  }
}

function unresolvedFrom(registry) {
  if (!registry) return [];
  return registry.entries.flatMap((entry) => entry.links
    .filter((link) => link.status !== "resolved")
    .map((link) => ({
      code: link.status,
      message: `${entry.id}: ${link.raw}`,
      reference: link.raw,
      path: entry.path,
    })));
}

export async function createLinkRuntime({
  globalRegistryPath,
  cwd,
  projectTrusted,
  configDirName = ".pi",
}) {
  const loadedGlobal = await readGlobalRegistry(globalRegistryPath);
  const projectRoot = await findProjectRoot(cwd);
  let projectRegistry = projectTrusted
    ? await compileProjectRegistry(projectRoot, { configDirName })
    : null;
  let runtimeDiagnostics = loadedGlobal.diagnostics;

  function resolution(reference, originId) {
    return resolveReference({
      globalRegistry: loadedGlobal.registry,
      projectRegistry,
      reference,
      originId,
    });
  }

  function detailsFor(result, target, links = []) {
    return {
      status: result.status,
      reference: result.reference,
      ...(target ? { targetId: target.id, path: target.path } : {}),
      ...(result.candidates ? { candidates: result.candidates } : {}),
      links,
    };
  }

  async function refreshTarget(target) {
    if (target.layer !== "project") return target;
    const refreshed = await refreshProjectEntry(projectRegistry, target.id);
    projectRegistry = {
      ...projectRegistry,
      entries: projectRegistry.entries.map((entry) => (
        entry.id === refreshed.id ? refreshed : entry
      )),
    };
    return refreshed;
  }

  const runtime = {
    get globalRegistry() {
      return loadedGlobal.registry;
    },
    get projectRegistry() {
      return projectRegistry;
    },
    summary() {
      return {
        global: loadedGlobal.registry?.entries.length ?? 0,
        project: projectRegistry?.entries.length ?? 0,
        diagnostics: [
          ...runtimeDiagnostics,
          ...(loadedGlobal.registry?.diagnostics ?? []),
          ...(projectRegistry?.diagnostics ?? []),
          ...unresolvedFrom(loadedGlobal.registry),
          ...unresolvedFrom(projectRegistry),
        ].length,
      };
    },
    unresolved() {
      return [
        ...runtimeDiagnostics,
        ...(loadedGlobal.registry?.diagnostics ?? []),
        ...(projectRegistry?.diagnostics ?? []),
        ...unresolvedFrom(loadedGlobal.registry),
        ...unresolvedFrom(projectRegistry),
      ];
    },
    inspect(reference) {
      return resolution(reference);
    },
    async follow(reference, argumentsText = "") {
      const result = resolution(reference);
      if (result.status !== "resolved") {
        return {
          text: `Unable to follow ${reference}: ${result.status}`,
          details: detailsFor(result),
        };
      }
      let target;
      try {
        target = await refreshTarget(result.target);
      } catch (error) {
        const status = /escapes root/.test(error.message)
          ? "outside-root"
          : error?.code === "ENOENT"
            ? "missing-target"
            : "unreadable-resource";
        return {
          text: `Unable to follow ${reference}: ${status}`,
          details: {
            status,
            reference,
            targetId: result.target.id,
            path: result.target.path,
            links: [],
          },
        };
      }
      const loaded = await loadLinkedResource(target, argumentsText);
      const outgoing = formatOutgoingLinks(target);
      return {
        text: outgoing ? `${loaded.text}\n\n${outgoing}` : loaded.text,
        details: detailsFor(result, target, target.links),
      };
    },
    async decorateRead(path, text) {
      if (text.includes("[pi-typed-links]")) return text;
      let canonical;
      try {
        canonical = await realpath(path);
      } catch {
        canonical = resolve(path);
      }
      const globalEntry = loadedGlobal.registry?.entries.find(
        (entry) => entry.path === canonical,
      );
      const projectEntry = projectRegistry?.entries.find(
        (entry) => entry.path === canonical,
      );
      const layer = globalEntry
        ? "global"
        : projectEntry || (projectRegistry && inside(projectRegistry.projectRoot, canonical))
          ? "project"
          : undefined;
      const originId = layer ? `${layer}:doc:read-origin` : undefined;
      const links = extractTypedLinks(text).map((link) => {
        if (link.status === "malformed") return link;
        const result = resolution(link.raw, originId);
        return result.status === "resolved"
          ? { ...link, status: "resolved", targetId: result.target.id }
          : { ...link, status: result.status, targetId: undefined };
      });
      return formatReadLinkFooter(text, links) ?? text;
    },
    async reload() {
      projectRegistry = projectTrusted
        ? await compileProjectRegistry(projectRoot, { configDirName })
        : null;
      runtimeDiagnostics = loadedGlobal.diagnostics;
      return runtime.summary();
    },
  };

  return runtime;
}
