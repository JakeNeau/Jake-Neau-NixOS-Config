interface TranscriptControlContext {
  mode: string;
  ui: {
    notify(message: string, type?: string): void;
    setMinimalTranscript?: (enabled: boolean) => void;
    setToolsExpanded(enabled: boolean): void;
    setWorkingMessage(message?: string): void;
  };
}

interface MessageUpdateControlEvent {
  message: unknown;
}

interface ToolExecutionStartControlEvent {
  parentToolCallId?: string;
}

interface TranscriptControlApi {
  registerShortcut(
    key: string,
    definition: { description: string; handler(ctx: TranscriptControlContext): void | Promise<void> },
  ): void;
  on(
    event: "session_start" | "turn_start" | "agent_settled",
    handler: (event: unknown, ctx: TranscriptControlContext) => void | Promise<void>,
  ): void;
  on(
    event: "message_update",
    handler: (event: MessageUpdateControlEvent, ctx: TranscriptControlContext) => void | Promise<void>,
  ): void;
  on(
    event: "tool_execution_start",
    handler: (event: ToolExecutionStartControlEvent, ctx: TranscriptControlContext) => void | Promise<void>,
  ): void;
}

const THINKING_LABEL = "Thinking…";
const WRITING_LABEL = "Writing response…";
const WORKING_LABEL = "Working…";
const MAX_PROGRESS_COLUMNS = 48;

function assistantTextBlocks(message: unknown): string[] {
  if (!message || typeof message !== "object" || !("role" in message) || message.role !== "assistant") return [];
  if (!("content" in message) || !Array.isArray(message.content)) return [];

  const blocks: string[] = [];
  for (const content of message.content) {
    if (
      content &&
      typeof content === "object" &&
      "type" in content &&
      content.type === "text" &&
      "text" in content &&
      typeof content.text === "string"
    ) {
      blocks.push(content.text);
    }
  }
  return blocks;
}

export function progressLineFromMessage(
  message: unknown,
  measureWidth: (text: string) => number,
): string | undefined {
  const textBlocks = assistantTextBlocks(message)
    .map((text) => text.trim())
    .filter((text) => text.length > 0);
  if (textBlocks.length !== 1) return;

  const line = textBlocks[0]!;
  if (/[\u0000-\u001f\u007f-\u009f]/u.test(line)) return;
  if (measureWidth(line) > MAX_PROGRESS_COLUMNS) return;
  return line;
}

function transcriptUi(ctx: TranscriptControlContext): (enabled: boolean) => void {
  if (typeof ctx.ui.setMinimalTranscript !== "function") {
    throw new Error("patched Pi transcript UI is unavailable");
  }
  return ctx.ui.setMinimalTranscript;
}

export function registerTranscriptControls(
  pi: TranscriptControlApi,
  measureWidth: (text: string) => number,
): void {
  let minimal = true;
  let activityLabel: string | undefined;
  let candidateMessage: unknown;

  const applyActivityLabel = (ctx: TranscriptControlContext) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setWorkingMessage(minimal ? activityLabel : undefined);
  };

  pi.registerShortcut("alt+t", {
    description: "Toggle full transcript",
    handler: (ctx) => {
      try {
        const next = !minimal;
        transcriptUi(ctx)(next);
        minimal = next;
        applyActivityLabel(ctx);
        ctx.ui.notify(minimal ? "Minimal transcript" : "Full transcript", "info");
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Transcript toggle failed: ${message}`, "error");
      }
    },
  });

  pi.on("session_start", (_event, ctx) => {
    minimal = true;
    activityLabel = undefined;
    candidateMessage = undefined;
    if (ctx.mode !== "tui") return;
    try {
      transcriptUi(ctx)(true);
      ctx.ui.setToolsExpanded(true);
      ctx.ui.setWorkingMessage();
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`Transcript toggle failed: ${message}`, "error");
      throw error;
    }
  });

  pi.on("turn_start", (_event, ctx) => {
    activityLabel = THINKING_LABEL;
    candidateMessage = undefined;
    applyActivityLabel(ctx);
  });

  pi.on("message_update", (event, ctx) => {
    if (!assistantTextBlocks(event.message).some((text) => text.trim().length > 0)) return;
    activityLabel = WRITING_LABEL;
    candidateMessage = event.message;
    applyActivityLabel(ctx);
  });

  pi.on("tool_execution_start", (event, ctx) => {
    if (event.parentToolCallId !== undefined) return;
    activityLabel = progressLineFromMessage(candidateMessage, measureWidth) ?? WORKING_LABEL;
    applyActivityLabel(ctx);
  });

  pi.on("agent_settled", (_event, ctx) => {
    activityLabel = undefined;
    candidateMessage = undefined;
    if (ctx.mode === "tui") ctx.ui.setWorkingMessage();
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
