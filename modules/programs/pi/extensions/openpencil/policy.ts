import { lstat, realpath } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";

import type { McpTool } from "./client.ts";

const READ_ONLY_TOOLS = new Set([
  "get_selection",
  "get_page_tree",
  "get_current_page",
  "get_node",
  "find_nodes",
  "get_components",
  "list_pages",
  "list_documents",
  "list_variables",
  "list_collections",
  "list_fonts",
  "page_bounds",
  "node_bounds",
  "node_ancestors",
  "node_children",
  "node_tree",
  "node_bindings",
  "path_get",
  "export_image",
  "export_svg",
  "viewport_get",
  "get_variable",
  "find_variables",
  "get_collection",
  "analyze_colors",
  "analyze_typography",
  "analyze_spacing",
  "analyze_clusters",
  "diff_show",
]);

export function isReadOnlyTool(name: string): boolean {
  return READ_ONLY_TOOLS.has(name);
}

export function assertAllowedTool(name: string): void {
  if (name === "eval") {
    throw new Error("OpenPencil eval is disabled because it bypasses bounded tool schemas");
  }
}

export function searchTools(tools: McpTool[], query: string, limit = 20): McpTool[] {
  const terms = query.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  if (terms.length === 0) return tools.slice(0, limit);

  return tools
    .map((tool) => {
      const name = tool.name.toLowerCase();
      const haystack = `${name} ${tool.description ?? ""}`.toLowerCase();
      const score = terms.reduce((total, term) => {
        if (name === term) return total + 5;
        if (name.includes(term)) return total + 3;
        if (haystack.includes(term)) return total + 1;
        return total;
      }, 0);
      return { tool, score };
    })
    .filter(({ score }) => score > 0)
    .sort((left, right) => right.score - left.score || left.tool.name.localeCompare(right.tool.name))
    .slice(0, limit)
    .map(({ tool }) => tool);
}

export async function resolveProjectPath(root: string, input: string): Promise<string> {
  const rootPath = await realpath(root);
  const candidate = resolve(rootPath, input.replace(/^@/, ""));
  assertInside(rootPath, candidate);

  const existing = await nearestExisting(candidate);
  const canonicalExisting = await realpath(existing);
  const suffix = relative(existing, candidate);
  const canonicalCandidate = resolve(canonicalExisting, suffix);
  assertInside(rootPath, canonicalCandidate);
  return candidate;
}

function assertInside(root: string, candidate: string): void {
  const path = relative(root, candidate);
  if (path === "" || (!path.startsWith(`..${sep}`) && path !== ".." && !isAbsolute(path))) return;
  throw new Error(`OpenPencil path is outside the trusted project: ${candidate}`);
}

async function nearestExisting(path: string): Promise<string> {
  let current = path;
  while (true) {
    try {
      await lstat(current);
      return current;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
      const parent = dirname(current);
      if (parent === current) throw error;
      current = parent;
    }
  }
}
