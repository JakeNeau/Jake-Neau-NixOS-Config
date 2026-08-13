import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { CONFIG_DIR_NAME, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";

import { workflowAutocompleteItems } from "./autocomplete.ts";
import registerWorkflowChild from "./child.ts";
import { discoverWorkflowDefinitions, type LoadedWorkflow } from "./definitions.ts";
import { WorkflowRuntime } from "./runtime.ts";
import { renderWorkflowArtifact, renderWorkflowConversation, WorkflowUi } from "./ui.ts";
import type { WorkflowArtifact } from "./artifacts.ts";

function findProjectWorkflowRoot(cwd: string): string | undefined {
  let current = cwd;
  while (true) {
    const candidate = join(current, CONFIG_DIR_NAME, "workflows");
    if (existsSync(candidate)) return candidate;
    const parent = dirname(current);
    if (parent === current) return undefined;
    current = parent;
  }
}

export default function workflows(pi: ExtensionAPI): void {
  if (process.env.PI_WORKFLOW_CHILD === "1") {
    registerWorkflowChild(pi);
    return;
  }

  const globalRoot = fileURLToPath(new URL("./workflows", import.meta.url));
  let definitions = new Map<string, LoadedWorkflow>();
  let armed = "normal";
  let armedUi: WorkflowUi | undefined;
  let active: WorkflowRuntime | undefined;
  let activePromise: Promise<void> | undefined;
  let lastRun: { name: string; input: string } | undefined;

  const sortedNames = () => [...definitions.keys()].sort();

  function disarm(): void {
    armedUi?.stop();
    armedUi = undefined;
    armed = "normal";
  }

  function arm(name: string, ctx: ExtensionContext): void {
    if (ctx.mode !== "tui") {
      ctx.ui.notify("Workflow modes require interactive TUI mode.", "error");
      return;
    }
    if (active) {
      ctx.ui.notify("Finish or stop the active workflow before changing modes.", "warning");
      return;
    }
    armedUi?.stop();
    armedUi = undefined;
    armed = name;
    if (name === "normal") {
      ctx.ui.notify("Workflow mode: normal", "info");
      return;
    }
    const definition = definitions.get(name);
    if (!definition) {
      armed = "normal";
      ctx.ui.notify(`Unknown workflow: ${name}`, "error");
      return;
    }
    armedUi = new WorkflowUi(pi, ctx);
    armedUi.arm({ name, source: definition.source, color: definition.color, stage: "armed" });
    ctx.ui.notify(`Workflow armed: ${name}. Submit a prompt to start.`, "info");
  }

  async function start(name: string, input: string, ctx: ExtensionContext): Promise<void> {
    if (activePromise) {
      ctx.ui.notify("A workflow is already running.", "warning");
      return;
    }
    if (ctx.mode !== "tui") {
      ctx.ui.notify("Workflows require interactive TUI mode.", "error");
      return;
    }
    const definition = definitions.get(name);
    if (!definition) {
      ctx.ui.notify(`Unknown workflow: ${name}`, "error");
      return;
    }
    armedUi?.stop();
    armedUi = undefined;
    armed = name;
    lastRun = { name, input };
    active = new WorkflowRuntime(pi, ctx, definition);
    activePromise = (async () => {
      try {
        const result = name === "refine-spec" || name === "refine-plan"
          ? await active!.runRefinement(input)
          : await active!.runGraph(input);
        ctx.ui.notify(result === "done" ? `Workflow completed: ${name}` : `Workflow stopped: ${name}`, "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      } finally {
        active = undefined;
        activePromise = undefined;
        armed = "normal";
      }
    })();
    await activePromise;
  }

  async function reloadDefinitions(ctx: ExtensionContext): Promise<void> {
    const result = await discoverWorkflowDefinitions({
      globalRoot,
      projectRoot: findProjectWorkflowRoot(ctx.cwd),
      projectTrusted: ctx.isProjectTrusted(),
    });
    definitions = result.workflows;
    for (const diagnostic of result.diagnostics.slice(0, 5)) ctx.ui.notify(diagnostic, "warning");
    if (result.diagnostics.length > 5) ctx.ui.notify(`${result.diagnostics.length - 5} more workflow diagnostics`, "warning");
    if (armed !== "normal" && !definitions.has(armed)) disarm();
  }

  pi.registerEntryRenderer("workflow-artifact", (entry, options, theme) =>
    renderWorkflowArtifact(entry.data as WorkflowArtifact, options.expanded, theme)
  );
  pi.registerEntryRenderer("workflow-conversation", (entry, _options, theme) =>
    renderWorkflowConversation(entry.data as { role: "user" | "assistant"; content: string }, theme)
  );

  pi.registerCommand("refine-spec", {
    description: "Refine project specifications from an idea, focus area, or audit",
    handler: async (args, ctx) => start("refine-spec", args.trim(), ctx),
  });

  pi.registerCommand("refine-plan", {
    description: "Create or refine an implementation-complete plan for a specification",
    handler: async (args, ctx) => start("refine-plan", args.trim(), ctx),
  });

  pi.registerCommand("workflow", {
    description: "Select, run, stop, restart, or inspect workflows",
    getArgumentCompletions: (prefix) => {
      const values = ["status", "stop", "restart", "run", ...sortedNames()];
      const matches = values.filter((value) => value.startsWith(prefix));
      return matches.length ? matches.map((value) => ({ value, label: value })) : null;
    },
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      if (!trimmed) {
        const choice = await ctx.ui.select("Select workflow mode", ["normal", ...sortedNames()]);
        if (choice) arm(choice, ctx);
        return;
      }
      const [command, ...rest] = trimmed.split(/\s+/);
      if (command === "status") {
        ctx.ui.notify(active ? `Running workflow: ${active.definition.name}` : `Workflow mode: ${armed}`, "info");
        return;
      }
      if (command === "stop") {
        if (!active) ctx.ui.notify("No workflow is running.", "info");
        else active.requestStop();
        return;
      }
      if (command === "restart") {
        if (!lastRun) {
          ctx.ui.notify("No workflow is available to restart.", "warning");
          return;
        }
        if (active) {
          ctx.ui.notify("Stop the active workflow before restarting it.", "warning");
          return;
        }
        await start(lastRun.name, rest.join(" ") || lastRun.input, ctx);
        return;
      }
      if (command === "run") {
        const [name, ...input] = rest;
        if (!name) {
          ctx.ui.notify("Usage: /workflow run <name> [input]", "error");
          return;
        }
        await start(name, input.join(" "), ctx);
        return;
      }
      if (definitions.has(command)) {
        if (rest.length) await start(command, rest.join(" "), ctx);
        else arm(command, ctx);
        return;
      }
      ctx.ui.notify(`Unknown workflow command: ${command}`, "error");
    },
  });

  pi.registerShortcut("shift+tab", {
    description: "Cycle workflow modes",
    handler: async (ctx) => {
      if (active) {
        ctx.ui.notify("Finish or stop the active workflow before changing modes.", "warning");
        return;
      }
      const modes = ["normal", ...sortedNames()];
      const current = Math.max(0, modes.indexOf(armed));
      arm(modes[(current + 1) % modes.length], ctx);
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    await reloadDefinitions(ctx);
    if (ctx.mode !== "tui") return;
    ctx.ui.addAutocompleteProvider((current) => ({
      triggerCharacters: ["/"],
      async getSuggestions(lines, line, column, options) {
        const before = (lines[line] ?? "").slice(0, column);
        const match = before.match(/^\/([a-z0-9-]*)$/);
        if (!match) return current.getSuggestions(lines, line, column, options);
        const prefix = match[1];
        const workflowItems = workflowAutocompleteItems(definitions.values(), prefix);
        if (workflowItems.length === 0) return current.getSuggestions(lines, line, column, options);
        return { prefix: `/${prefix}`, items: workflowItems };
      },
      applyCompletion: (lines, line, column, item, prefix) => current.applyCompletion(lines, line, column, item, prefix),
      shouldTriggerFileCompletion: (lines, line, column) => current.shouldTriggerFileCompletion?.(lines, line, column) ?? true,
    }));
  });

  pi.on("resources_discover", async (event, ctx) => {
    if (event.reason === "reload") await reloadDefinitions(ctx);
  });

  pi.on("input", async (event, ctx) => {
    if (event.source !== "interactive" || active) return { action: "continue" as const };
    const slash = event.text.match(/^\/([a-z][a-z0-9-]*)(?:\s+([\s\S]*))?$/);
    if (slash && definitions.has(slash[1])) {
      await start(slash[1], slash[2] ?? "", ctx);
      return { action: "handled" as const };
    }
    if (armed === "normal") return { action: "continue" as const };
    await start(armed, event.text, ctx);
    return { action: "handled" as const };
  });

  pi.on("session_shutdown", () => {
    active?.requestStop();
    armedUi?.stop();
    active = undefined;
    activePromise = undefined;
  });
}
