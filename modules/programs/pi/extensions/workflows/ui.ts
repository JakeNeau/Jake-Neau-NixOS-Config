import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { BorderedLoader, CustomEditor } from "@earendil-works/pi-coding-agent";
import { Text, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

import { runAskUserTui } from "../ask-user/dialog.ts";
import type { WorkflowArtifact } from "./artifacts.ts";
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

const EXPLORE_DECISION_LABEL = "Explore this decision";

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

  setDecisionWidget(title: string, decisions: string[]): void {
    const lines = [this.ctx.ui.theme.fg("warning", title), ...decisions.slice(-6).map((decision) => `✓ ${decision}`)];
    this.ctx.ui.setWidget("workflow", lines);
  }

  appendArtifact(artifact: WorkflowArtifact): void {
    this.pi.appendEntry("workflow-artifact", artifact);
  }

  appendConversation(role: "user" | "assistant", content: string): void {
    this.pi.appendEntry("workflow-conversation", { role, content });
  }

  async runLoader<T>(label: string, action: (signal: AbortSignal) => Promise<T>): Promise<T | undefined> {
    if (this.ctx.mode !== "tui") return action(new AbortController().signal);
    return this.ctx.ui.custom<T | undefined>((tui, theme, _keybindings, done) => {
      const loader = new BorderedLoader(tui, theme, label);
      loader.onAbort = () => done(undefined);
      action(loader.signal).then(done).catch((error) => {
        this.ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
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

    if (this.ctx.mode === "tui") {
      const event = await runAskUserTui(
        {
          question: title,
          options: [...optionLabels.map((label) => ({ label })), { label: EXPLORE_DECISION_LABEL }],
        },
        this.ctx,
      );
      return workflowAnswerForDialogEvent(answerLabels, event, optionLabels.length);
    }

    const freeForm = "Type a free-form answer...";
    const clarify = "Ask a clarifying question...";
    while (true) {
      const choice = await this.ctx.ui.select(title, [
        ...answerLabels,
        EXPLORE_DECISION_LABEL,
        freeForm,
        clarify,
      ]);
      if (!choice) return { answer: null, status: "cancelled" };
      if (choice === EXPLORE_DECISION_LABEL) return { answer: null, status: "explore" };
      if (choice === freeForm) {
        const answer = (await this.ctx.ui.input("Free-form answer", "Type your answer"))?.trim();
        if (answer) return { answer, status: "answered" };
        continue;
      }
      if (choice === clarify) {
        const clarification = (await this.ctx.ui.input("Clarifying question", "Ask what you need to know"))?.trim();
        if (clarification) return { answer: null, clarification, status: "clarification" };
        continue;
      }
      const index = answerLabels.indexOf(choice);
      if (index >= 0) return { answer: answerLabels[index], index: index + 1, status: "answered" };
    }
  }

  async choose(title: string, options: string[]): Promise<string | undefined> {
    return this.ctx.ui.select(title, options);
  }

  async edit(title: string, prefill = ""): Promise<string | undefined> {
    return this.ctx.ui.editor(title, prefill);
  }

  stop(): void {
    this.ctx.ui.setStatus("workflow", undefined);
    this.ctx.ui.setWidget("workflow", undefined);
    this.ctx.ui.setEditorComponent(this.previousEditor);
    this.state = undefined;
  }
}

export function renderWorkflowConversation(
  message: { role: "user" | "assistant"; content: string },
  theme: any,
): Text {
  const color = message.role === "user" ? "accent" : "text";
  const label = message.role === "user" ? "You" : "Refiner";
  return new Text(`${theme.fg(color, theme.bold(label))}\n${theme.fg("text", message.content)}`, 1, 0);
}

export function renderWorkflowArtifact(artifact: WorkflowArtifact, expanded: boolean, theme: any): Text {
  const heading = `${artifact.workflow} · ${artifact.stageType} · ${artifact.artifactKind}`;
  let text = theme.fg("warning", theme.bold(heading));
  text += `\n${theme.fg("text", artifact.summary)}`;
  if (expanded) text += `\n${theme.fg("dim", JSON.stringify(artifact.payload, null, 2))}`;
  return new Text(text, 1, 0);
}
