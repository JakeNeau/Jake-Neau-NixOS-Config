import { existsSync } from "node:fs";
import { readdir, readFile } from "node:fs/promises";
import { isAbsolute, join, normalize, relative } from "node:path";

import { hasShellControlSyntax } from "./runner.ts";

export interface JoinDefinition {
  mode: "all" | "any";
  stages: string[];
}

export interface StageDefinition {
  prompt: string;
  tools: string[];
  readOnly: boolean;
  inputs: string[];
  outputSchema: string;
  transitions: Record<string, string[][]>;
  join?: JoinDefinition;
  mutationPaths?: string[];
  checkpoint?: "question" | "proposal";
}

export interface WorkflowDefinition {
  version: 1;
  name: string;
  description: string;
  inputHint?: string;
  color: string;
  entry: string;
  terminalOutcomes: string[];
  replaces?: string;
  maxParallel?: number;
  stages: Record<string, StageDefinition>;
}

export interface LoadedWorkflow extends WorkflowDefinition {
  source: "global" | "project";
  root: string;
  readOnlyCommandPrefixes?: Record<string, string[]>;
}

export interface DiscoveryResult {
  workflows: Map<string, LoadedWorkflow>;
  diagnostics: string[];
}

export const APPROVED_READ_ONLY_TOOLS = new Set([
  "read", "grep", "find", "ls", "bash", "follow_link", "rust_code", "web_search",
  "fetch_content", "get_search_content",
]);
const APPROVED_MUTATION_TOOLS = new Set([...APPROVED_READ_ONLY_TOOLS].filter((name) => name !== "bash").concat(["edit", "write"]));

const RESERVED_NAMES = new Set([
  "workflow", "model", "settings", "resume", "new", "session", "tree", "fork",
  "compact", "copy", "export", "reload", "hotkeys", "quit", "trust", "login", "logout",
]);
const PORTABLE_SCHEMA_KEYS = new Set([
  "type", "properties", "required", "additionalProperties", "items", "enum", "const",
  "description", "minLength", "maxLength", "minimum", "maximum",
  "minItems", "maxItems", "uniqueItems", "pattern", "title", "default",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}

function validatePortableSchema(schema: unknown, path = "$", errors: string[] = []): string[] {
  if (!isRecord(schema)) {
    errors.push(`${path}: schema must be an object`);
    return errors;
  }
  for (const [key, value] of Object.entries(schema)) {
    if (!PORTABLE_SCHEMA_KEYS.has(key)) errors.push(`${path}.${key}: unsupported schema keyword`);
    if (key === "properties" && isRecord(value)) {
      for (const [name, child] of Object.entries(value)) validatePortableSchema(child, `${path}.properties.${name}`, errors);
    }
    if (key === "items") validatePortableSchema(value, `${path}.items`, errors);
  }
  return errors;
}

export function validateWorkflowDefinition(value: unknown): string[] {
  const errors: string[] = [];
  if (!isRecord(value)) return ["workflow definition must be an object"];
  if (value.version !== 1) errors.push("version must be 1");
  for (const forbidden of ["model", "provider", "thinking", "thinkingLevel", "readOnlyCommandPrefixes"]) {
    if (forbidden in value) errors.push(`${forbidden} is forbidden in workflow definitions`);
  }
  if (typeof value.name !== "string" || !/^[a-z][a-z0-9-]*$/.test(value.name)) {
    errors.push("name must use lowercase letters, digits, and hyphens");
  } else if (RESERVED_NAMES.has(value.name)) {
    errors.push(`name conflicts with reserved Pi command: ${value.name}`);
  }
  if (typeof value.description !== "string" || value.description.trim().length === 0) errors.push("description is required");
  if (value.inputHint !== undefined && typeof value.inputHint !== "string") errors.push("inputHint must be a string");
  if (!["accent", "warning", "success", "error", "borderAccent"].includes(String(value.color))) {
    errors.push("color must be an approved theme color");
  }
  if (value.maxParallel !== undefined && (!Number.isInteger(value.maxParallel) || Number(value.maxParallel) < 1 || Number(value.maxParallel) > 8)) {
    errors.push("maxParallel must be an integer from 1 through 8");
  }
  if (value.replaces !== undefined && typeof value.replaces !== "string") errors.push("replaces must be a string");
  if (typeof value.entry !== "string") errors.push("entry is required");
  if (!isStringArray(value.terminalOutcomes) || value.terminalOutcomes.length === 0) errors.push("terminalOutcomes must be non-empty");
  if (!isRecord(value.stages) || Object.keys(value.stages).length === 0) {
    errors.push("stages must be a non-empty object");
    return errors;
  }
  const stageNames = new Set(Object.keys(value.stages));
  if (typeof value.entry === "string" && !stageNames.has(value.entry)) errors.push(`entry stage does not exist: ${value.entry}`);
  const terminalOutcomes = new Set(isStringArray(value.terminalOutcomes) ? value.terminalOutcomes : []);

  for (const [stageName, rawStage] of Object.entries(value.stages)) {
    if (!isRecord(rawStage)) {
      errors.push(`stage ${stageName} must be an object`);
      continue;
    }
    for (const forbidden of ["model", "provider", "thinking", "thinkingLevel"]) {
      if (forbidden in rawStage) errors.push(`stage ${stageName}: ${forbidden} is forbidden`);
    }
    if (typeof rawStage.prompt !== "string") errors.push(`stage ${stageName}: prompt is required`);
    if (!isStringArray(rawStage.tools)) {
      errors.push(`stage ${stageName}: tools must be strings`);
    } else {
      const approved = rawStage.readOnly === true ? APPROVED_READ_ONLY_TOOLS : APPROVED_MUTATION_TOOLS;
      for (const tool of rawStage.tools) {
        if (!approved.has(tool)) errors.push(`stage ${stageName}: tool is not approved for this permission mode: ${tool}`);
      }
    }
    if (!isStringArray(rawStage.inputs)) errors.push(`stage ${stageName}: inputs must be strings`);
    if (typeof rawStage.outputSchema !== "string") errors.push(`stage ${stageName}: outputSchema is required`);
    if (rawStage.readOnly !== true && rawStage.readOnly !== false) errors.push(`stage ${stageName}: readOnly must be boolean`);
    if (rawStage.readOnly === false && !isStringArray(rawStage.mutationPaths)) {
      errors.push(`stage ${stageName}: mutation stages must declare mutationPaths`);
    }
    if (!isRecord(rawStage.transitions)) {
      errors.push(`stage ${stageName}: transitions must be an object`);
    } else {
      for (const [outcome, rawSets] of Object.entries(rawStage.transitions)) {
        if (!Array.isArray(rawSets) || !rawSets.every((set) => isStringArray(set))) {
          errors.push(`stage ${stageName}: transition ${outcome} must be an array of successor sets`);
          continue;
        }
        if (rawSets.length === 0 && !terminalOutcomes.has(outcome)) {
          errors.push(`stage ${stageName}: ${outcome} is not a terminal outcome`);
        }
        for (const set of rawSets as string[][]) {
          for (const successor of set) {
            if (!stageNames.has(successor)) errors.push(`stage ${stageName}: successor does not exist: ${successor}`);
          }
        }
      }
    }
    if (rawStage.checkpoint !== undefined && rawStage.checkpoint !== "question" && rawStage.checkpoint !== "proposal") {
      errors.push(`stage ${stageName}: checkpoint must be question or proposal`);
    }
    if (rawStage.join !== undefined) {
      if (!isRecord(rawStage.join) || !["all", "any"].includes(String(rawStage.join.mode)) || !isStringArray(rawStage.join.stages)) {
        errors.push(`stage ${stageName}: join is invalid`);
      } else {
        for (const joined of rawStage.join.stages) {
          if (!stageNames.has(joined)) errors.push(`stage ${stageName}: join stage does not exist: ${joined}`);
        }
      }
    }
  }
  return errors;
}

async function loadOne(root: string, directory: string, source: "global" | "project"): Promise<{ workflow?: LoadedWorkflow; diagnostics: string[] }> {
  const workflowRoot = join(root, directory);
  const path = join(workflowRoot, "workflow.json");
  const diagnostics: string[] = [];
  let raw: unknown;
  try {
    raw = JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    return { diagnostics: [`${path}: ${String(error)}`] };
  }
  diagnostics.push(...validateWorkflowDefinition(raw).map((error) => `${path}: ${error}`));
  if (!isRecord(raw) || !isRecord(raw.stages)) return { diagnostics };

  for (const [stageName, stageValue] of Object.entries(raw.stages)) {
    if (!isRecord(stageValue)) continue;
    for (const field of ["prompt", "outputSchema"] as const) {
      const rel = stageValue[field];
      if (typeof rel !== "string") continue;
      const resolved = normalize(join(workflowRoot, rel));
      if (isAbsolute(rel) || relative(workflowRoot, resolved).startsWith("..")) {
        diagnostics.push(`${path}: stage ${stageName} ${field} escapes the workflow root`);
      } else if (!existsSync(resolved)) {
        diagnostics.push(`${path}: stage ${stageName} ${field} does not exist: ${rel}`);
      }
      if (field === "outputSchema" && existsSync(resolved)) {
        try {
          const schema = JSON.parse(await readFile(resolved, "utf8"));
          diagnostics.push(...validatePortableSchema(schema).map((error) => `${resolved}: ${error}`));
        } catch (error) {
          diagnostics.push(`${resolved}: ${String(error)}`);
        }
      }
    }
  }
  if (diagnostics.length > 0) return { diagnostics };
  return { workflow: { ...(raw as unknown as WorkflowDefinition), source, root: workflowRoot }, diagnostics };
}

async function loadRoot(root: string | undefined, source: "global" | "project"): Promise<{ workflows: LoadedWorkflow[]; diagnostics: string[] }> {
  if (!root || !existsSync(root)) return { workflows: [], diagnostics: [] };
  const workflows: LoadedWorkflow[] = [];
  const diagnostics: string[] = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const result = await loadOne(root, entry.name, source);
    if (result.workflow) workflows.push(result.workflow);
    diagnostics.push(...result.diagnostics);
  }
  return { workflows, diagnostics };
}

async function loadReadOnlyExceptions(
  projectRoot: string | undefined,
  workflows: Map<string, LoadedWorkflow>,
): Promise<{ exceptions: Map<string, Record<string, string[]>>; diagnostics: string[] }> {
  const exceptions = new Map<string, Record<string, string[]>>();
  if (!projectRoot) return { exceptions, diagnostics: [] };
  const path = join(projectRoot, "read-only-exceptions.json");
  if (!existsSync(path)) return { exceptions, diagnostics: [] };

  let raw: unknown;
  try {
    raw = JSON.parse(await readFile(path, "utf8"));
  } catch (error) {
    return { exceptions, diagnostics: [`${path}: ${String(error)}`] };
  }

  const errors: string[] = [];
  if (!isRecord(raw)) {
    errors.push("policy must be an object");
  } else {
    if (raw.version !== 1) errors.push("version must be 1");
    if (!isRecord(raw.workflows)) {
      errors.push("workflows must be an object");
    } else {
      for (const [workflowName, rawStages] of Object.entries(raw.workflows)) {
        const workflow = workflows.get(workflowName);
        if (!workflow) {
          errors.push(`unknown workflow: ${workflowName}`);
          continue;
        }
        if (!isRecord(rawStages)) {
          errors.push(`workflow exceptions must be an object: ${workflowName}`);
          continue;
        }
        const stages: Record<string, string[]> = {};
        for (const [stageName, rawPolicy] of Object.entries(rawStages)) {
          const stage = workflow.stages[stageName];
          if (!stage) {
            errors.push(`unknown stage: ${workflowName}.${stageName}`);
            continue;
          }
          if (!stage.readOnly) {
            errors.push(`stage is not read-only: ${workflowName}.${stageName}`);
            continue;
          }
          if (!stage.tools.includes("bash")) {
            errors.push(`stage does not enable bash: ${workflowName}.${stageName}`);
            continue;
          }
          if (!isRecord(rawPolicy) || !isStringArray(rawPolicy.allowedCommandPrefixes)) {
            errors.push(`allowedCommandPrefixes must be strings: ${workflowName}.${stageName}`);
            continue;
          }
          const prefixes = rawPolicy.allowedCommandPrefixes.map((prefix) => prefix.trim());
          if (prefixes.length === 0 || prefixes.some((prefix) => prefix.length === 0)) {
            errors.push(`allowedCommandPrefixes must contain non-empty command prefixes: ${workflowName}.${stageName}`);
            continue;
          }
          if (prefixes.some(hasShellControlSyntax)) {
            errors.push(`allowedCommandPrefixes cannot contain shell control syntax: ${workflowName}.${stageName}`);
            continue;
          }
          stages[stageName] = [...new Set(prefixes)];
        }
        if (Object.keys(stages).length > 0) exceptions.set(workflowName, stages);
      }
    }
  }
  if (errors.length > 0) return { exceptions: new Map(), diagnostics: errors.map((error) => `${path}: ${error}`) };
  return { exceptions, diagnostics: [] };
}

export async function discoverWorkflowDefinitions(options: {
  globalRoot: string;
  projectRoot?: string;
  projectTrusted: boolean;
}): Promise<DiscoveryResult> {
  const global = await loadRoot(options.globalRoot, "global");
  const project = options.projectTrusted ? await loadRoot(options.projectRoot, "project") : { workflows: [], diagnostics: [] };
  const workflows = new Map<string, LoadedWorkflow>();
  const diagnostics = [...global.diagnostics, ...project.diagnostics];
  for (const workflow of global.workflows) workflows.set(workflow.name, workflow);
  for (const workflow of project.workflows) {
    const existing = workflows.get(workflow.name);
    if (existing && workflow.replaces !== existing.name) {
      diagnostics.push(`${join(workflow.root, "workflow.json")}: project collision requires replaces: ${existing.name}`);
      continue;
    }
    if (!existing && workflow.replaces) {
      diagnostics.push(`${join(workflow.root, "workflow.json")}: replaces names no global workflow: ${workflow.replaces}`);
      continue;
    }
    workflows.set(workflow.name, workflow);
  }
  if (options.projectTrusted) {
    const policy = await loadReadOnlyExceptions(options.projectRoot, workflows);
    diagnostics.push(...policy.diagnostics);
    for (const [workflowName, readOnlyCommandPrefixes] of policy.exceptions) {
      const workflow = workflows.get(workflowName);
      if (workflow) workflows.set(workflowName, { ...workflow, readOnlyCommandPrefixes });
    }
  }
  return { workflows, diagnostics };
}
