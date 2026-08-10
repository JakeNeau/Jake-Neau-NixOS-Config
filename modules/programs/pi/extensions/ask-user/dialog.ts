import {
  getMarkdownTheme,
  type ExtensionContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  type Focusable,
  Input,
  Key,
  Markdown,
  matchesKey,
  type TUI,
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
} from "@earendil-works/pi-tui";

import type { AskUserParams } from "./core.ts";
import {
  activePreview,
  createDialogState,
  type DialogAction,
  type DialogEvent,
  type DialogState,
  reduceDialogState,
} from "./dialog-state.ts";

const FREE_FORM_LABEL = "Type a free-form answer...";
const CLARIFICATION_LABEL = "Ask a clarifying question...";
const MAX_PREVIEW_LINES = 16;

class AskUserDialog implements Focusable {
  private state: DialogState;
  private readonly input = new Input();
  private _focused = false;

  constructor(
    private readonly params: AskUserParams,
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly done: (event: DialogEvent) => void,
  ) {
    this.state = createDialogState(params.options.length);
  }

  get focused(): boolean {
    return this._focused;
  }

  set focused(value: boolean) {
    this._focused = value;
    this.input.focused = value && this.state.mode !== "menu";
  }

  handleInput(data: string): void {
    if (this.state.mode !== "menu") {
      if (matchesKey(data, Key.enter)) {
        this.apply({ type: "enter" });
      } else if (matchesKey(data, Key.escape)) {
        this.apply({ type: "escape" });
      } else {
        this.input.handleInput(data);
        this.apply({ type: "input", value: this.input.getValue() });
      }
      return;
    }

    if (matchesKey(data, Key.up)) this.apply({ type: "up" });
    else if (matchesKey(data, Key.down)) this.apply({ type: "down" });
    else if (matchesKey(data, Key.enter)) this.apply({ type: "enter" });
    else if (matchesKey(data, Key.escape)) this.apply({ type: "escape" });
  }

  private apply(action: DialogAction): void {
    const previousMode = this.state.mode;
    const transition = reduceDialogState(this.state, action);
    this.state = transition.state;

    if (previousMode === "menu" && this.state.mode !== "menu") {
      this.input.setValue("");
    }
    this.input.focused = this._focused && this.state.mode !== "menu";

    if (transition.event) this.done(transition.event);
    else this.tui.requestRender();
  }

  render(width: number): string[] {
    const renderWidth = Math.max(1, width);
    const lines: string[] = [this.theme.fg("accent", "─".repeat(renderWidth))];

    this.addWrapped(lines, this.params.question, renderWidth, " ");
    lines.push("");

    for (let index = 0; index < this.params.options.length; index++) {
      this.addMenuRow(
        lines,
        `${index + 1}. ${this.params.options[index]!.label}`,
        index === this.state.selectedIndex,
        renderWidth,
      );
    }

    this.addActionRow(lines, "free-form", FREE_FORM_LABEL, renderWidth);
    this.addActionRow(lines, "clarification", CLARIFICATION_LABEL, renderWidth);

    const preview = activePreview(this.params.options, this.state);
    if (preview) {
      lines.push("");
      lines.push(...this.renderPreview(preview, renderWidth));
    }

    lines.push("");
    const help = this.state.mode === "menu"
      ? "↑↓ navigate • enter select • esc cancel"
      : "enter submit • esc back";
    this.addWrapped(lines, this.theme.fg("dim", help), renderWidth, " ");
    lines.push(this.theme.fg("accent", "─".repeat(renderWidth)));
    return lines.map((line) => truncateToWidth(line, renderWidth, ""));
  }

  private addActionRow(
    lines: string[],
    mode: "free-form" | "clarification",
    label: string,
    width: number,
  ): void {
    const index = mode === "free-form" ? this.params.options.length : this.params.options.length + 1;
    const selected = index === this.state.selectedIndex;

    if (this.state.mode === mode) {
      const innerWidth = Math.max(1, width - 2);
      for (const inputLine of this.input.render(innerWidth)) {
        this.addSelectedLine(lines, `  ${inputLine}`, width);
      }
      return;
    }

    this.addMenuRow(lines, label, selected, width);
  }

  private addMenuRow(lines: string[], label: string, selected: boolean, width: number): void {
    const prefix = selected ? "> " : "  ";
    const contentWidth = Math.max(1, width - visibleWidth(prefix));
    const wrapped = wrapTextWithAnsi(label, contentWidth);

    for (let index = 0; index < wrapped.length; index++) {
      const line = `${index === 0 ? prefix : "  "}${wrapped[index]}`;
      if (selected) this.addSelectedLine(lines, line, width);
      else lines.push(this.theme.fg("text", line));
    }
  }

  private addSelectedLine(lines: string[], line: string, width: number): void {
    const clipped = truncateToWidth(line, width, "");
    const padded = clipped + " ".repeat(Math.max(0, width - visibleWidth(clipped)));
    lines.push(this.theme.bg("selectedBg", this.theme.fg("accent", padded)));
  }

  private addWrapped(lines: string[], text: string, width: number, prefix: string): void {
    const prefixWidth = visibleWidth(prefix);
    const wrapped = wrapTextWithAnsi(text, Math.max(1, width - prefixWidth));
    const continuation = " ".repeat(prefixWidth);
    for (let index = 0; index < wrapped.length; index++) {
      lines.push(`${index === 0 ? prefix : continuation}${wrapped[index]}`);
    }
  }

  private renderPreview(preview: string, width: number): string[] {
    if (width < 8) return [this.theme.fg("borderMuted", truncateToWidth("Preview", width, ""))];

    const contentWidth = width - 4;
    const markdown = new Markdown(preview, 0, 0, getMarkdownTheme());
    const rendered = markdown.render(contentWidth);
    const truncated = rendered.length > MAX_PREVIEW_LINES;
    const content = truncated
      ? [
          ...rendered.slice(0, MAX_PREVIEW_LINES - 1),
          this.theme.fg("dim", "… preview truncated"),
        ]
      : rendered;

    const title = " Preview ";
    const top = `┌─${title}${"─".repeat(Math.max(0, width - visibleWidth(title) - 3))}┐`;
    const bottom = `└${"─".repeat(width - 2)}┘`;
    const lines = [this.theme.fg("borderMuted", top)];

    for (const renderedLine of content) {
      const clipped = truncateToWidth(renderedLine, contentWidth, "");
      const padding = " ".repeat(Math.max(0, contentWidth - visibleWidth(clipped)));
      lines.push(
        this.theme.fg("borderMuted", "│ ")
          + clipped
          + padding
          + this.theme.fg("borderMuted", " │"),
      );
    }
    lines.push(this.theme.fg("borderMuted", bottom));
    return lines;
  }

  invalidate(): void {
    this.input.invalidate();
  }
}

export async function runAskUserTui(
  params: AskUserParams,
  ctx: ExtensionContext,
  signal?: AbortSignal,
): Promise<DialogEvent> {
  if (signal?.aborted) return { type: "cancelled" };

  let finish: ((event: DialogEvent) => void) | undefined;
  const abort = () => finish?.({ type: "cancelled" });
  signal?.addEventListener("abort", abort, { once: true });

  try {
    return await ctx.ui.custom<DialogEvent>((tui, theme, _keybindings, done) => {
      finish = done;
      return new AskUserDialog(params, tui, theme, done);
    });
  } finally {
    signal?.removeEventListener("abort", abort);
  }
}
