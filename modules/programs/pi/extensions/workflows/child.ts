import { existsSync, readFileSync, realpathSync } from "node:fs";
import { basename, dirname, isAbsolute, resolve } from "node:path";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { isAllowedReadOnlyCommand, isSafeReadOnlyCommand } from "./runner.ts";

function canonicalTarget(cwd: string, path: string): string {
  const absolute = isAbsolute(path) ? resolve(path) : resolve(cwd, path);
  if (existsSync(absolute)) return realpathSync(absolute);
  const missing: string[] = [];
  let current = absolute;
  while (!existsSync(current)) {
    const parent = dirname(current);
    if (parent === current) return absolute;
    missing.unshift(basename(current));
    current = parent;
  }
  return resolve(realpathSync(current), ...missing);
}

export default function registerWorkflowChild(pi: ExtensionAPI): void {
  const schemaPath = process.env.PI_WORKFLOW_SCHEMA;
  const manifestPath = process.env.PI_WORKFLOW_ARTIFACT_MANIFEST;
  if (!schemaPath || !manifestPath) throw new Error("Workflow child configuration is incomplete");

  const schema = JSON.parse(readFileSync(schemaPath, "utf8"));
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as {
    catalog: unknown[];
    artifacts: Record<string, string>;
  };
  const readOnly = process.env.PI_WORKFLOW_READ_ONLY === "1";
  const readOnlyCommandPrefixes = JSON.parse(
    process.env.PI_WORKFLOW_READ_ONLY_COMMAND_PREFIXES ?? "[]",
  ) as string[];
  const approved = new Set<string>(
    (JSON.parse(process.env.PI_WORKFLOW_APPROVED_PATHS ?? "[]") as string[])
      .map((path) => canonicalTarget(process.cwd(), path)),
  );

  pi.registerTool({
    name: "workflow_output",
    label: "Workflow Output",
    description: "Return the final validated artifact for this workflow stage.",
    promptSnippet: "Return the workflow stage artifact",
    promptGuidelines: [
      "Call workflow_output exactly once as the final action of a workflow child stage.",
      "Do not describe a workflow artifact only in assistant text.",
    ],
    parameters: Type.Unsafe(schema),
    executionMode: "sequential",
    async execute(_toolCallId, params) {
      return {
        content: [{ type: "text", text: "Workflow artifact recorded." }],
        details: { artifact: params },
        terminate: true,
      };
    },
  } as any);

  pi.registerTool({
    name: "request_workflow_artifacts",
    label: "Request Workflow Artifacts",
    description: "Load up to three earlier artifacts from the current workflow run by identity.",
    parameters: Type.Object({
      artifactIds: Type.Array(Type.String(), { minItems: 1, maxItems: 3, uniqueItems: true }),
      reason: Type.String({ minLength: 1, maxLength: 500 }),
    }, { additionalProperties: false }),
    executionMode: "sequential",
    async execute(_toolCallId, params) {
      const loaded: unknown[] = [];
      let bytes = 0;
      for (const artifactId of params.artifactIds) {
        const path = manifest.artifacts[artifactId];
        if (!path) throw new Error(`Unknown workflow artifact: ${artifactId}`);
        const text = readFileSync(path, "utf8");
        bytes += Buffer.byteLength(text);
        if (bytes > 50 * 1024) throw new Error("Requested workflow artifacts exceed 50 KB");
        loaded.push(JSON.parse(text));
      }
      const content = JSON.stringify({ reason: params.reason, artifacts: loaded }, null, 2);
      if (content.split("\n").length > 2000) throw new Error("Requested workflow artifacts exceed 2,000 lines");
      return {
        content: [{ type: "text", text: content }],
        details: { requestedArtifactIds: params.artifactIds, reason: params.reason },
      };
    },
  });

  pi.on("tool_call", (event, ctx) => {
    if (event.toolName === "bash" && readOnly) {
      const command = String((event.input as { command?: unknown }).command ?? "");
      if (!isSafeReadOnlyCommand(command) && !isAllowedReadOnlyCommand(command, readOnlyCommandPrefixes)) {
        return { block: true, reason: `Workflow read-only stage blocked command: ${command}` };
      }
    }
    if (event.toolName !== "edit" && event.toolName !== "write") return;
    if (readOnly) return { block: true, reason: "Workflow stage is read-only" };
    const inputPath = (event.input as { path?: unknown }).path;
    if (typeof inputPath !== "string") return { block: true, reason: "Workflow mutation has no path" };
    const path = canonicalTarget(ctx.cwd, inputPath);
    if (!approved.has(path)) return { block: true, reason: `Workflow mutation path is not approved: ${path}` };
  });
}
