interface TranscriptControlContext {
  mode: string;
  ui: {
    notify(message: string, type?: string): void;
    setMinimalTranscript?: (enabled: boolean) => void;
    setToolsExpanded(enabled: boolean): void;
  };
}

interface TranscriptControlApi {
  registerShortcut(
    key: string,
    definition: { description: string; handler(ctx: TranscriptControlContext): void | Promise<void> },
  ): void;
  on(
    event: "session_start",
    handler: (event: unknown, ctx: TranscriptControlContext) => void | Promise<void>,
  ): void;
}

function transcriptUi(ctx: TranscriptControlContext): (enabled: boolean) => void {
  if (typeof ctx.ui.setMinimalTranscript !== "function") {
    throw new Error("patched Pi transcript UI is unavailable");
  }
  return ctx.ui.setMinimalTranscript;
}

export function registerTranscriptControls(pi: TranscriptControlApi): void {
  let minimal = true;

  pi.registerShortcut("alt+t", {
    description: "Toggle full transcript",
    handler: (ctx) => {
      try {
        const next = !minimal;
        transcriptUi(ctx)(next);
        minimal = next;
        ctx.ui.notify(minimal ? "Minimal transcript" : "Full transcript", "info");
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Transcript toggle failed: ${message}`, "error");
      }
    },
  });

  pi.on("session_start", (_event, ctx) => {
    minimal = true;
    if (ctx.mode !== "tui") return;
    try {
      transcriptUi(ctx)(true);
      ctx.ui.setToolsExpanded(true);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Transcript toggle failed: ${message}`, "error");
      throw error;
    }
  });
}

export interface DiffEntryData {
  path: string;
  patch: string;
  additions: number;
  deletions: number;
  action: "created" | "updated";
}

export function countPatchChanges(patch: string): { additions: number; deletions: number } {
  let additions = 0;
  let deletions = 0;
  let inHunk = false;

  for (const line of patch.split("\n")) {
    if (line.startsWith("@@")) {
      inHunk = true;
    } else if (inHunk && line.startsWith("+")) {
      additions++;
    } else if (inHunk && line.startsWith("-")) {
      deletions++;
    }
  }

  return { additions, deletions };
}

export function diffSummary(data: DiffEntryData): string {
  return `${data.action === "created" ? "created" : "updated"} ${data.path} +${data.additions} −${data.deletions}`;
}
