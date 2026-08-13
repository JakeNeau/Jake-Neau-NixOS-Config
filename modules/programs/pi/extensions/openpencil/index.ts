import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  truncateHead,
  withFileMutationQueue,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

import { OpenPencilMcpClient, type McpContent, type McpToolResult } from "./client.ts";
import {
  assertAllowedTool,
  isReadOnlyTool,
  resolveProjectPath,
  searchTools,
} from "./policy.ts";

export type OpenPencilExtensionOptions = {
  serverPath?: string;
};

export function createOpenPencilExtension(options: OpenPencilExtensionOptions = {}) {
  return function openPencilExtension(pi: ExtensionAPI) {
    const client = new OpenPencilMcpClient(options.serverPath ?? "openpencil-mcp");

    pi.registerTool({
      name: "openpencil",
      label: "OpenPencil",
      description: "Search or call bounded OpenPencil MCP tools against project-local .fig designs. Mutations require user confirmation. Output is truncated to 2,000 lines or 50KB.",
      promptSnippet: "Search and call OpenPencil design inspection or editing tools",
      promptGuidelines: [
        "Use openpencil for project-local .fig design work and inspect current state before proposing a mutation.",
        "Use openpencil search before call when the exact OpenPencil MCP tool or schema is unknown.",
      ],
      parameters: Type.Object({
        action: StringEnum(["search", "call"] as const),
        query: Type.Optional(Type.String({ description: "Capability to find when action is search" })),
        name: Type.Optional(Type.String({ description: "Exact MCP tool name when action is call" })),
        arguments: Type.Optional(Type.Record(Type.String(), Type.Unknown(), {
          description: "Arguments for the selected MCP tool",
        })),
      }),
      async execute(_toolCallId, params, signal, _onUpdate, ctx) {
        if (!ctx.isProjectTrusted()) {
          throw new Error("OpenPencil tools require a trusted project");
        }

        const tools = await client.listTools(ctx.cwd, signal);
        if (params.action === "search") {
          const matches = searchTools(tools, params.query ?? "");
          const text = matches.length === 0
            ? "No OpenPencil tools matched the query."
            : matches.map((tool) => `${tool.name}: ${tool.description ?? ""}\n${JSON.stringify(tool.inputSchema)}`).join("\n\n");
          return textResult(text, { matches: matches.map((tool) => tool.name) });
        }

        if (!params.name) throw new Error("OpenPencil call requires a tool name");
        const tool = tools.find((candidate) => candidate.name === params.name);
        if (!tool) throw new Error(`Unknown OpenPencil tool: ${params.name}`);
        assertAllowedTool(tool.name);

        const args = params.arguments ?? {};
        await validatePaths(ctx.cwd, args);
        if (!isReadOnlyTool(tool.name)) {
          if (!ctx.hasUI) {
            throw new Error(`OpenPencil mutation requires interactive approval: ${tool.name}`);
          }
          const approved = await ctx.ui.confirm(
            "Approve OpenPencil mutation?",
            `${tool.name}\n${JSON.stringify(args, null, 2)}`,
          );
          if (!approved) throw new Error(`OpenPencil mutation was not approved: ${tool.name}`);
        }

        const invoke = () => client.callTool(tool.name, args, ctx.cwd, signal);
        const result = tool.name === "save_file" && typeof args.path === "string"
          ? await withFileMutationQueue(await resolveProjectPath(ctx.cwd, args.path), invoke)
          : await invoke();
        if (result.isError) throw new Error(resultText(result) || `OpenPencil tool failed: ${tool.name}`);
        return normalizeResult(result, tool.name);
      },
    });

    pi.on("session_shutdown", async () => {
      await client.close();
    });
  };
}

async function validatePaths(root: string, args: Record<string, unknown>): Promise<void> {
  for (const key of ["path", "file", "output", "outputPath"]) {
    const value = args[key];
    if (typeof value === "string") await resolveProjectPath(root, value);
  }
}

function normalizeResult(result: McpToolResult, name: string) {
  const content = result.content.flatMap((item): McpContent[] => {
    if (item.type === "text" && typeof item.text === "string") {
      return [{ type: "text", text: truncate(item.text) }];
    }
    if (item.type === "image") return [item];
    return [{ type: "text", text: truncate(JSON.stringify(item)) }];
  });
  if (result.structuredContent !== undefined) {
    content.push({ type: "text", text: truncate(JSON.stringify(result.structuredContent, null, 2)) });
  }
  return {
    content: content as never,
    details: { tool: name, structuredContent: result.structuredContent },
  };
}

function resultText(result: McpToolResult): string {
  return result.content
    .filter((item): item is { type: "text"; text: string } => item.type === "text" && typeof item.text === "string")
    .map((item) => item.text)
    .join("\n");
}

function textResult(text: string, details: Record<string, unknown>) {
  return {
    content: [{ type: "text" as const, text: truncate(text) }],
    details,
  };
}

function truncate(text: string): string {
  return truncateHead(text, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES }).content;
}

export default createOpenPencilExtension();
