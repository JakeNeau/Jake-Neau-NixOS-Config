import { readFile } from "node:fs/promises";

import { parseFrontmatter } from "./registry.mjs";

export interface RegistryLink {
  raw: string;
  type: "skill" | "command" | "spec" | "doc";
  name: string;
  status: string;
  targetId?: string;
}

export interface RegistryEntry {
  id: string;
  type: "skill" | "command" | "spec" | "doc";
  name: string;
  layer: "global" | "project";
  path: string;
  description: string;
  metadata: Record<string, unknown>;
  adapter: string;
  links: RegistryLink[];
  mtimeMs: number | null;
}

export interface LoadedResource {
  text: string;
  path: string;
  type: "skill" | "command" | "spec" | "doc";
}

function tokenizeArguments(source: string): string[] {
  const values: string[] = [];
  let value = "";
  let quote: "'" | '"' | undefined;
  let started = false;
  let escaped = false;

  for (const character of source) {
    if (escaped) {
      value += character;
      started = true;
      escaped = false;
      continue;
    }
    if (character === "\\") {
      escaped = true;
      started = true;
      continue;
    }
    if (quote) {
      if (character === quote) quote = undefined;
      else value += character;
      started = true;
      continue;
    }
    if (character === "'" || character === '"') {
      quote = character;
      started = true;
      continue;
    }
    if (/\s/.test(character)) {
      if (started) {
        values.push(value);
        value = "";
        started = false;
      }
      continue;
    }
    value += character;
    started = true;
  }

  if (escaped) throw new Error("argument string ends with a dangling escape");
  if (quote) throw new Error("argument string has an unterminated quote");
  if (started) values.push(value);
  return values;
}

function valueWithDefault(value: string, fallback: string | undefined): string {
  return value === "" && fallback !== undefined ? fallback : value;
}

export function expandPromptTemplate(source: string, argumentsText = ""): string {
  const values = tokenizeArguments(argumentsText);
  const all = values.join(" ");
  let result = source.replace(
    /\$\{@:(\d+)(?::(\d+))?\}/g,
    (_match, startText: string, lengthText?: string) => {
      const start = Math.max(0, Number(startText) - 1);
      const slice = lengthText === undefined
        ? values.slice(start)
        : values.slice(start, start + Number(lengthText));
      return slice.join(" ");
    },
  );
  result = result.replace(
    /\$\{(ARGUMENTS|@|\d+):-([^}]*)\}/g,
    (_match, key: string, fallback: string) => {
      const value = key === "@" || key === "ARGUMENTS"
        ? all
        : values[Number(key) - 1] ?? "";
      return valueWithDefault(value, fallback);
    },
  );
  result = result.replace(/\$ARGUMENTS|\$@/g, all);
  result = result.replace(/\$(\d+)/g, (_match, position: string) => (
    values[Number(position) - 1] ?? ""
  ));
  return result;
}

export async function loadLinkedResource(
  entry: RegistryEntry,
  argumentsText = "",
): Promise<LoadedResource> {
  const source = await readFile(entry.path, "utf8");
  let text = source;
  if (entry.type === "skill" && argumentsText) {
    text = `${source.trimEnd()}\n\nUser: ${argumentsText}`;
  } else if (entry.type === "command") {
    text = expandPromptTemplate(parseFrontmatter(source).body, argumentsText);
  }
  return { text, path: entry.path, type: entry.type };
}

function formatLinks(links: RegistryLink[]): string | undefined {
  if (links.length === 0) return undefined;
  const rows = links.map((link) => (
    `- ${link.raw} → ${link.targetId ?? link.status}`
  ));
  return `Linked resources:\n${rows.join("\n")}`;
}

export function formatOutgoingLinks(entry: RegistryEntry): string | undefined {
  return formatLinks(entry.links);
}

export function formatReadLinkFooter(
  source: string,
  links: RegistryLink[],
): string | undefined {
  if (source.includes("[pi-typed-links]")) return source;
  const formatted = formatLinks(links);
  if (!formatted) return undefined;
  return `${source}\n\n[pi-typed-links]\n${formatted}`;
}
