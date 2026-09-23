import { readFile } from "node:fs/promises";
import { isAbsolute, resolve } from "node:path";

import { generateUnifiedPatch, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { Container, Text } from "@earendil-works/pi-tui";

import { countPatchChanges, diffSummary, type DiffEntryData } from "./core.ts";

const ENTRY_TYPE = "minimal-transcript-diff";

interface PendingMutation {
  path: string;
  absolutePath: string;
  before: string;
  existed: boolean;
  readable: boolean;
}

async function readBefore(path: string): Promise<Pick<PendingMutation, "before" | "existed" | "readable">> {
  try {
    return { before: await readFile(path, "utf8"), existed: true, readable: true };
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
      return { before: "", existed: false, readable: true };
    }
    return { before: "", existed: false, readable: false };
  }
}

function colorPatch(patch: string, theme: Theme): string {
  return patch
    .split("\n")
    .map((line) => {
      if (line.startsWith("+") && !line.startsWith("+++")) return theme.fg("success", line);
      if (line.startsWith("-") && !line.startsWith("---")) return theme.fg("error", line);
      if (line.startsWith("@@")) return theme.fg("accent", line);
      return theme.fg("dim", line);
    })
    .join("\n");
}

export default function minimalTranscript(pi: ExtensionAPI): void {
  if (process.env.PI_MINIMAL_TRANSCRIPT !== "1") {
    throw new Error("The minimal transcript extension requires the patched Pi package.");
  }

  const pending = new Map<string, PendingMutation>();

  pi.registerEntryRenderer<DiffEntryData>(ENTRY_TYPE, (entry, { expanded }, theme) => {
    if (!entry.data) return undefined;

    const summary = diffSummary(entry.data);
    if (!expanded) return new Text(theme.fg("accent", summary), 1, 0);

    const container = new Container();
    container.addChild(new Text(theme.fg("accent", summary), 1, 0));
    container.addChild(new Text(colorPatch(entry.data.patch, theme), 1, 0));
    return container;
  });

  pi.registerShortcut("ctrl+shift+o", {
    description: "Collapse file diffs",
    handler: (ctx) => ctx.ui.setToolsExpanded(false),
  });

  pi.on("session_start", (_event, ctx) => {
    if (ctx.hasUI) ctx.ui.setToolsExpanded(true);
  });

  pi.on("tool_execution_start", async (event, ctx) => {
    if ((event.toolName !== "edit" && event.toolName !== "write") || typeof event.args?.path !== "string") return;

    const absolutePath = isAbsolute(event.args.path) ? event.args.path : resolve(ctx.cwd, event.args.path);
    pending.set(event.toolCallId, {
      path: event.args.path,
      absolutePath,
      ...(await readBefore(absolutePath)),
    });
  });

  pi.on("tool_execution_end", async (event) => {
    const mutation = pending.get(event.toolCallId);
    pending.delete(event.toolCallId);
    if (!mutation || event.isError) return;

    let patch = typeof event.result?.details?.patch === "string" ? event.result.details.patch : "";
    if (!patch && mutation.readable) {
      try {
        const after = await readFile(mutation.absolutePath, "utf8");
        if (mutation.existed && mutation.before === after) return;
        patch = generateUnifiedPatch(mutation.path, mutation.before, after);
      } catch {
        return;
      }
    }
    if (!patch) return;

    pi.appendEntry<DiffEntryData>(ENTRY_TYPE, {
      path: mutation.path,
      patch,
      ...countPatchChanges(patch),
      action: mutation.existed ? "updated" : "created",
    });
  });

  pi.on("session_shutdown", () => pending.clear());
}
