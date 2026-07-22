import { homedir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";

import {
  CONFIG_DIR_NAME,
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  truncateHead,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { createLinkRuntime } from "./runtime.mjs";

function registryPath(): string {
  if (process.env.PI_LINK_REGISTRY_PATH) return process.env.PI_LINK_REGISTRY_PATH;
  const configRoot = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
  return join(configRoot, "link-registry.json");
}

export default function typedLinks(pi: ExtensionAPI) {
  let runtime: Awaited<ReturnType<typeof createLinkRuntime>> | undefined;

  pi.on("session_start", async (_event, ctx) => {
    runtime = await createLinkRuntime({
      globalRegistryPath: registryPath(),
      cwd: ctx.cwd,
      projectTrusted: ctx.isProjectTrusted(),
      configDirName: CONFIG_DIR_NAME,
    });
    const summary = runtime.summary();
    if (ctx.hasUI) {
      ctx.ui.notify(
        `Link registry: ${summary.global} global, ${summary.project} project, ${summary.diagnostics} diagnostics`,
        summary.diagnostics > 0 ? "warning" : "info",
      );
    }
  });

  pi.on("session_shutdown", () => {
    runtime = undefined;
  });

  pi.registerTool({
    name: "follow_link",
    label: "Follow Link",
    description: "Resolve and load one supported [[type:name]] resource",
    promptSnippet: "Resolve and load one typed skill, command, spec, or doc link",
    promptGuidelines: [
      "When instructions say to read, use, or follow a supported [[type:name]], call follow_link before acting.",
    ],
    parameters: Type.Object({
      reference: Type.String(),
      arguments: Type.Optional(Type.String()),
    }),
    async execute(_id, params) {
      if (!runtime) {
        return {
          content: [{ type: "text", text: "Unable to follow link: registry unavailable" }],
          details: {
            status: "global-registry-unavailable",
            reference: params.reference,
            links: [],
          },
        };
      }
      const result = await runtime.follow(params.reference, params.arguments ?? "");
      const truncation = truncateHead(result.text, {
        maxBytes: DEFAULT_MAX_BYTES,
        maxLines: DEFAULT_MAX_LINES,
      });
      let text = truncation.content;
      if (truncation.truncated) {
        text += `\n\n[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines`;
        text += ` (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}).`;
        if (result.details.path) text += ` Read the full resource at ${result.details.path}.`;
        text += "]";
      }
      return {
        content: [{ type: "text", text }],
        details: { ...result.details, truncation },
      };
    },
  });

  pi.registerCommand("links", {
    description: "Inspect or reload the typed-link registry",
    handler: async (args, ctx) => {
      if (args.trim() === "reload") {
        await ctx.reload();
        return;
      }
      if (!runtime) {
        ctx.ui.notify("Link registry unavailable", "error");
        return;
      }
      if (args.trim() === "unresolved") {
        const unresolved = runtime.unresolved();
        ctx.ui.notify(
          unresolved.length === 0
            ? "No unresolved links"
            : unresolved.map((item) => `${item.code}: ${item.message}`).join("\n"),
          unresolved.length === 0 ? "info" : "warning",
        );
        return;
      }
      if (args.trim()) {
        ctx.ui.notify(JSON.stringify(runtime.inspect(args.trim()), null, 2), "info");
        return;
      }
      const summary = runtime.summary();
      ctx.ui.notify(
        `${summary.global} global, ${summary.project} project, ${summary.diagnostics} diagnostics`,
        "info",
      );
    },
  });

  pi.on("tool_result", async (event, ctx) => {
    if (!runtime || event.toolName !== "read") return;
    const index = event.content.findIndex((item) => item.type === "text");
    if (index === -1) return;
    const item = event.content[index];
    if (item.type !== "text") return;
    const input = event.input as { path?: string };
    if (!input.path) return;
    const normalized = input.path.replace(/^@/, "");
    const path = isAbsolute(normalized) ? normalized : resolve(ctx.cwd, normalized);
    const decorated = await runtime.decorateRead(path, item.text);
    if (decorated === item.text) return;
    const content = [...event.content];
    content[index] = { ...item, text: decorated };
    return { content };
  });
}
