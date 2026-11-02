import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { BorderedLoader, CustomEditor } from "@earendil-works/pi-coding-agent";
import { Text, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

import { runAskUserTui } from "../ask-user/dialog.ts";
import {
  type WorkflowArtifact,
  workflowArtifactDetail,
  workflowEntryType,
} from "./artifacts.ts";
import {
  type WorkflowAnswer,
  workflowAnswerForDialogEvent,
} from "./question.ts";

export interface WorkflowQuestion {
  text: string;
  why: string;
  options: Array<{ id: string; label: string; consequence: string }>;
  recommendation: string | null;
}

export interface WorkflowUiState {
  name: string;
  source: "global" | "project";
  color: string;
  stage?: string;
  progress?: string;
  usage?: string;
}

function appendBorderLabel(line: string, label: string, width: number): string {
  if (width <= label.length) return truncateToWidth(label, width, "");
  return truncateToWidth(line, width - visibleWidth(label), "") + label;
}

export class WorkflowUi {
  private state?: WorkflowUiState;
  private previousEditor: ReturnType<ExtensionContext["ui"]["getEditorComponent"]>;

  constructor(private readonly pi: ExtensionAPI, private readonly ctx: ExtensionContext) {
    this.previousEditor = ctx.ui.getEditorComponent();
  }

  arm(state: WorkflowUiState): void {
    this.state = state;
    const owner = this;
    class WorkflowEditor extends CustomEditor {
      render(width: number): string[] {
        const lines = super.render(width);
        if (!owner.state || lines.length === 0) return lines;
        const color = owner.state.color as any;
        const border = (text: string) => owner.ctx.ui.theme.fg(color, text);
        lines[0] = border("─".repeat(width));
        const parts = [owner.state.name, owner.state.stage, owner.state.progress].filter(Boolean);
        const label = border(` ${parts.join(" · ")} `);
        lines[lines.length - 1] = appendBorderLabel(border("─".repeat(width)), label, width);
        return lines;
      }
    }
    this.ctx.ui.setEditorComponent((tui, theme, keybindings) => new WorkflowEditor(tui, theme, keybindings));
    this.update(state);
  }

  update(patch: Partial<WorkflowUiState>): void {
    if (!this.state) return;
    this.state = { ...this.state, ...patch };
    const status = [this.state.name, this.state.stage, this.state.progress, this.state.usage].filter(Boolean).join(" · ");
    this.ctx.ui.setStatus("workflow", this.ctx.ui.theme.fg(this.state.color as any, status));
  }

  appendArtifact(
    artifact: WorkflowArtifact,
    checkpoint?: "question" | "proposal",
  ): void {
    this.pi.appendEntry(workflowEntryType(checkpoint), artifact);
  }

  async runLoader<T>(
    label: string,
    stop: AbortSignal,
    action: (signal: AbortSignal) => Promise<T>,
  ): Promise<T | undefined> {
    return this.ctx.ui.custom<T | undefined>((tui, theme, _keybindings, done) => {
      const loader = new BorderedLoader(tui, theme, label);
      const signal = AbortSignal.any([loader.signal, stop]);
      loader.onAbort = () => done(undefined);
      action(signal).then(done).catch((error) => {
        // An abort is a deliberate stop, so its error is not reported.
        if (!signal.aborted) {
          const message = error instanceof Error ? error.message : String(error);
          this.ctx.ui.notify(message.trim().split("\n", 1)[0].slice(0, 200), "error");
        }
        done(undefined);
      });
      return loader;
    });
  }

  async ask(question: WorkflowQuestion): Promise<WorkflowAnswer> {
    const recommendation = question.recommendation ? `\nRecommendation: ${question.recommendation}` : "";
    const title = `${question.text}\n\n${question.why}${recommendation}`;
    const optionLabels = question.options.map((option) => `${option.label} — ${option.consequence}`);
    const answerLabels = optionLabels.map((label, index) => `${index + 1}. ${label}`);

    const event = await runAskUserTui(
      { question: title, options: optionLabels.map((label) => ({ label })) },
      this.ctx,
    );
    return workflowAnswerForDialogEvent(answerLabels, event);
  }

  async choose(title: string, options: string[]): Promise<string | undefined> {
    return this.ctx.ui.select(title, options);
  }

  stop(): void {
    this.ctx.ui.setStatus("workflow", undefined);
    this.ctx.ui.setWidget("workflow", undefined);
    this.ctx.ui.setEditorComponent(this.previousEditor);
    this.state = undefined;
  }
}

export function renderWorkflowArtifact(
  artifact: WorkflowArtifact,
  expanded: boolean,
  theme: any,
  review = false,
): Text {
  const heading = `${artifact.workflow} · ${artifact.stageType} · ${artifact.artifactKind}`;
  let text = theme.fg("warning", theme.bold(heading));
  text += `\n${theme.fg("text", artifact.summary)}`;
  const detail = workflowArtifactDetail(artifact, expanded, review);
  if (detail) text += `\n${theme.fg(detail.dim ? "dim" : "text", detail.text)}`;
  return new Text(text, 1, 0);
}
