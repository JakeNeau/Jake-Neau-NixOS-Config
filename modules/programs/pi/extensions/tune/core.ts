type Level = "info" | "warning" | "error";

export interface TuneContext {
  mode: string;
  isIdle(): boolean;
  hasPendingMessages(): boolean;
  sessionManager: {
    getLeafId(): string | null;
    getEntry(id: string): { parentId: string | null } | undefined;
  };
  waitForIdle(): Promise<void>;
  navigateTree(targetId: string, options: { summarize: boolean }): Promise<{ cancelled: boolean }>;
  ui: {
    notify(message: string, level?: Level): void;
    select(title: string, options: string[]): Promise<string | undefined>;
    editor(title: string, prefill?: string): Promise<string | undefined>;
    input(title: string, placeholder?: string): Promise<string | undefined>;
    getEditorText(): string;
    setEditorText(text: string): void;
  };
}

export interface TuneTool {
  name: string;
  label: string;
  description: string;
  promptSnippet: string;
  parameters: unknown;
  execute(
    toolCallId: string,
    params: { prompt: string },
  ): Promise<{ content: Array<{ type: "text"; text: string }>; details: undefined; terminate: true }>;
}

export interface TuneApi {
  registerCommand(
    name: string,
    definition: { description: string; handler(args: string, ctx: TuneContext): Promise<void> },
  ): void;
  registerTool(tool: TuneTool): void;
  sendMessage(
    message: { customType: string; content: string; display: boolean },
    options?: { triggerTurn?: boolean },
  ): void;
  sendUserMessage(content: string): void;
  on(event: "session_start" | "session_shutdown", handler: () => void): void;
}

export interface TuneOptions {
  loadInstructions(): Promise<string>;
  parameters: unknown;
}

const CHOICES = ["Accept", "Edit", "Keep tuning", "Cancel"];

export class TuneState {
  active = false;
  proposal: string | undefined;

  begin(): void {
    if (this.active) throw new Error("/tune is already running.");
    this.active = true;
  }

  clearProposal(): void {
    this.proposal = undefined;
  }

  propose(prompt: string): void {
    if (!this.active) throw new Error("propose_prompt is available only during a /tune run.");
    const trimmed = prompt.trim();
    if (!trimmed) throw new Error("The proposed prompt is empty.");
    this.proposal = trimmed;
  }

  end(): void {
    this.active = false;
    this.proposal = undefined;
  }
}

export function preflight(
  args: string,
  ctx: Pick<TuneContext, "mode" | "isIdle" | "hasPendingMessages">,
  state: TuneState,
): { draft: string } | { message: string; level: Level } {
  const draft = args.trim();
  if (!draft) return { message: "Usage: /tune <draft prompt>", level: "warning" };
  if (ctx.mode !== "tui") return { message: "/tune requires interactive mode.", level: "error" };
  if (!ctx.isIdle() || ctx.hasPendingMessages()) {
    return { message: "/tune cannot start while the agent is busy.", level: "error" };
  }
  if (state.active) return { message: "/tune is already running.", level: "error" };
  return { draft };
}

export function registerTune(pi: TuneApi, options: TuneOptions): void {
  const state = new TuneState();

  async function tune(draft: string, ctx: TuneContext): Promise<void> {
    state.begin();
    const leaf = ctx.sessionManager.getLeafId();
    let anchorId: string | undefined;
    let rewound = false;

    // Navigating to the anchor restores its parent, so even an empty session returns exactly.
    const rewind = async () => {
      rewound = true;
      const editorText = ctx.ui.getEditorText();
      const result = await ctx.navigateTree(anchorId!, { summarize: false });
      ctx.ui.setEditorText(editorText);
      if (result.cancelled) throw new Error("Pi could not leave the tuning exchange. Open /tree to return.");
    };

    // A triggered custom message marks Pi busy before it returns, so waitForIdle cannot return early.
    const turn = async (customType: string, content: string) => {
      state.clearProposal();
      pi.sendMessage({ customType, content, display: true }, { triggerTurn: true });
      await ctx.waitForIdle();
      return state.proposal;
    };

    try {
      const instructions = await options.loadInstructions();
      pi.sendMessage({ customType: "tune-instructions", content: instructions, display: false });
      anchorId = ctx.sessionManager.getLeafId() ?? undefined;
      if (!anchorId || ctx.sessionManager.getEntry(anchorId)?.parentId !== leaf) {
        anchorId = undefined;
        throw new Error("Pi could not record the /tune rewind point.");
      }

      let proposal = await turn("tune-draft", `Draft prompt:\n\n${draft}`);
      while (true) {
        if (!proposal) {
          await rewind();
          ctx.ui.notify("The agent proposed no prompt.", "warning");
          return;
        }

        const choice = await ctx.ui.select(`Tuned prompt\n\n${proposal}`, CHOICES);
        if (choice === "Accept") {
          await rewind();
          pi.sendUserMessage(proposal);
          return;
        }
        if (choice === "Edit") {
          proposal = (await ctx.ui.editor("Edit tuned prompt", proposal))?.trim() || proposal;
          continue;
        }
        if (choice === "Keep tuning") {
          const feedback = (await ctx.ui.input("Tuning feedback", "What should change?"))?.trim();
          if (feedback) proposal = await turn("tune-feedback", `Feedback on the proposed prompt:\n\n${feedback}`);
          continue;
        }
        await rewind();
        return;
      }
    } catch (error) {
      if (anchorId && !rewound && ctx.isIdle()) await rewind().catch(() => {});
      ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
    } finally {
      state.end();
    }
  }

  pi.registerCommand("tune", {
    description: "Tune a draft prompt with the agent before submitting it",
    handler: async (args, ctx) => {
      const checked = preflight(args, ctx, state);
      if ("message" in checked) {
        ctx.ui.notify(checked.message, checked.level);
        return;
      }
      await tune(checked.draft, ctx);
    },
  });

  pi.registerTool({
    name: "propose_prompt",
    label: "Propose Prompt",
    description: "Propose the tuned prompt for the user to review during a /tune run.",
    promptSnippet: "Propose the tuned prompt during /tune",
    parameters: options.parameters,
    async execute(_toolCallId, params) {
      state.propose(params.prompt);
      return {
        content: [{ type: "text", text: "The proposal is recorded for user review." }],
        details: undefined,
        terminate: true,
      };
    },
  });

  pi.on("session_start", () => state.end());
  pi.on("session_shutdown", () => state.end());
}
