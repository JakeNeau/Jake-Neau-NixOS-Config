import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { ArtifactStore, type ArtifactCandidate, type WorkflowArtifact } from "./artifacts.ts";
import type { LoadedWorkflow, StageDefinition } from "./definitions.ts";
import { InvocationGraph, mapWithConcurrency, resolveSuccessorSet, validateRouterSelection } from "./engine.ts";
import { runStage, type StageRunResult } from "./runner.ts";
import { fitEvidenceStageContext, MAX_STAGE_CONTEXT_BYTES, serializeStageContext } from "./stage-context.ts";
import { WorkflowUi, type WorkflowQuestion } from "./ui.ts";

class WorkflowStopped extends Error {}

interface UsageTotal {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  cost: number;
}

function formatCount(value: number): string {
  return value >= 1000 ? `${(value / 1000).toFixed(1)}k` : String(value);
}

function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function object(value: unknown): Record<string, any> {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, any> : {};
}

function array(value: unknown): any[] {
  return Array.isArray(value) ? value : [];
}

export class WorkflowRuntime {
  readonly runId = randomUUID();
  readonly artifacts: ArtifactStore;
  readonly graph: InvocationGraph;
  readonly ui: WorkflowUi;
  private readonly usage: UsageTotal = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 };
  private readonly provider: string;
  private readonly model: string;
  private readonly thinking: string;
  private readonly trusted: boolean;
  private readonly abortController = new AbortController();

  constructor(
    readonly pi: ExtensionAPI,
    readonly ctx: ExtensionContext,
    readonly definition: LoadedWorkflow,
  ) {
    if (!ctx.model) throw new Error("Select a model before starting a workflow");
    this.provider = ctx.model.provider;
    this.model = ctx.model.id;
    this.thinking = pi.getThinkingLevel();
    this.trusted = ctx.isProjectTrusted();
    this.artifacts = new ArtifactStore(this.runId, definition.name);
    this.graph = new InvocationGraph(this.runId);
    this.ui = new WorkflowUi(pi, ctx);
  }

  requestStop(): void {
    this.abortController.abort();
  }

  private stageSignal(signal: AbortSignal): AbortSignal {
    return AbortSignal.any([signal, this.abortController.signal]);
  }

  private updateUsage(result: StageRunResult): void {
    this.usage.input += result.usage.input;
    this.usage.output += result.usage.output;
    this.usage.cacheRead += result.usage.cacheRead;
    this.usage.cacheWrite += result.usage.cacheWrite;
    this.usage.cost += result.usage.cost;
    this.ui.update({
      usage: `↑${formatCount(this.usage.input)} ↓${formatCount(this.usage.output)} $${this.usage.cost.toFixed(3)}`,
    });
  }

  addArtifact(stageType: string, parents: WorkflowArtifact[], candidate: ArtifactCandidate): WorkflowArtifact {
    const invocation = this.graph.schedule(stageType, parents.map((parent) => parent.stageInvocationId));
    const artifact = this.artifacts.append(
      stageType,
      invocation.invocationId,
      parents.map((parent) => parent.artifactId),
      candidate,
    );
    this.ui.appendArtifact(artifact);
    return artifact;
  }

  private selectedInputs(stage: StageDefinition, parents: WorkflowArtifact[]): WorkflowArtifact[] {
    const selected = new Map<string, WorkflowArtifact>();
    for (const parent of parents) selected.set(parent.artifactId, parent);
    for (const artifact of this.artifacts.list()) {
      if (stage.inputs.includes(artifact.artifactKind)) selected.set(artifact.artifactId, artifact);
    }
    return [...selected.values()];
  }

  private async executeStage(
    stageType: string,
    parents: WorkflowArtifact[],
    extra: Record<string, unknown>,
    signal: AbortSignal,
    approvedPaths?: string[],
  ): Promise<WorkflowArtifact> {
    const stage = this.definition.stages[stageType];
    if (!stage) throw new Error(`Unknown workflow stage: ${stageType}`);
    const inputs = this.selectedInputs(stage, parents);
    const invocation = this.graph.schedule(
      stageType,
      inputs.map((input) => input.stageInvocationId),
      text(extra.iteration) || "root",
    );
    const promptTemplate = await readFile(resolve(this.definition.root, stage.prompt), "utf8");
    const schema = JSON.parse(await readFile(resolve(this.definition.root, stage.outputSchema), "utf8"));
    let stageContext = serializeStageContext(extra, inputs);
    if (
      Buffer.byteLength(stageContext) > MAX_STAGE_CONTEXT_BYTES
      && stageType === "synthesize"
      && inputs.every((input) => input.artifactKind === "evidence")
    ) {
      const fitted = fitEvidenceStageContext(extra, inputs);
      stageContext = fitted.serialized;
      if (fitted.compacted) {
        this.ctx.ui.notify(
          "Synthesis evidence exceeded 50 KB. Pi compacted the child prompt and retained the original artifacts.",
          "warning",
        );
      }
    }
    if (Buffer.byteLength(stageContext) > MAX_STAGE_CONTEXT_BYTES) {
      throw new Error(`Stage ${stageType} inputs exceed 50 KB`);
    }
    if (stageContext.split("\n").length > 2000) throw new Error(`Stage ${stageType} inputs exceed 2,000 lines`);
    const prompt = `${promptTemplate}\n\n## Stage context\n\n${stageContext}`;
    this.ui.update({ stage: stageType });
    const result = await runStage({
      cwd: this.ctx.cwd,
      prompt,
      schema,
      provider: this.provider,
      model: this.model,
      thinking: this.thinking,
      tools: stage.tools,
      trusted: this.trusted,
      readOnly: stage.readOnly,
      readOnlyCommandPrefixes: this.definition.readOnlyCommandPrefixes?.[stageType],
      approvedPaths,
      artifacts: [...this.artifacts.list()],
      catalog: this.artifacts.catalog(),
      signal,
    });
    this.updateUsage(result);
    const requested = result.requestedArtifactIds.map((artifactId) => {
      const artifact = this.artifacts.get(artifactId);
      if (!artifact) throw new Error(`Child requested an unknown artifact: ${artifactId}`);
      return artifact;
    });
    const parentArtifactIds = [...new Set([...inputs, ...requested].map((input) => input.artifactId))];
    const artifact = this.artifacts.append(
      stageType,
      invocation.invocationId,
      parentArtifactIds,
      result.artifact,
    );
    this.ui.appendArtifact(artifact);
    return artifact;
  }

  async stage(
    stageType: string,
    parents: WorkflowArtifact[],
    extra: Record<string, unknown> = {},
    approvedPaths?: string[],
  ): Promise<WorkflowArtifact> {
    const result = await this.ui.runLoader(`${this.definition.name}: ${stageType}`, (signal) =>
      this.executeStage(stageType, parents, extra, this.stageSignal(signal), approvedPaths)
    );
    if (!result) throw new WorkflowStopped("Workflow stopped");
    return result;
  }

  async parallelStage(
    stageType: string,
    parents: WorkflowArtifact[],
    variants: Array<Record<string, unknown>>,
  ): Promise<WorkflowArtifact[]> {
    const result = await this.ui.runLoader(`${this.definition.name}: ${stageType} (${variants.length} branches)`, (signal) =>
      mapWithConcurrency(variants, this.definition.maxParallel ?? 4, (variant) =>
        this.executeStage(stageType, parents, variant, this.stageSignal(signal))
      )
    );
    if (!result) throw new WorkflowStopped("Workflow stopped");
    return result;
  }

  private async chooseRoute(
    stageType: string,
    artifact: WorkflowArtifact,
    choices: string[][],
  ): Promise<string[]> {
    const schema = {
      type: "object",
      additionalProperties: false,
      required: ["artifactKind", "outcome", "summary", "payload"],
      properties: {
        artifactKind: { enum: ["route"] },
        outcome: { enum: ["selected"] },
        summary: { type: "string", minLength: 1, maxLength: 1000 },
        payload: {
          type: "object",
          additionalProperties: false,
          required: ["stages", "reason"],
          properties: {
            stages: { type: "array", maxItems: 20, items: { type: "string" } },
            reason: { type: "string", minLength: 1, maxLength: 1000 },
          },
        },
      },
    };
    const prompt = `Choose the best next stage set for workflow ${this.definition.name}.\n\nCurrent stage: ${stageType}\nArtifact: ${JSON.stringify(artifact)}\nAllowed sets: ${JSON.stringify(choices)}\n\nReturn a route artifact through workflow_output.`;
    const result = await this.ui.runLoader(`${this.definition.name}: route`, (signal) => runStage({
      cwd: this.ctx.cwd,
      prompt,
      schema,
      provider: this.provider,
      model: this.model,
      thinking: this.thinking,
      tools: [],
      trusted: this.trusted,
      readOnly: true,
      artifacts: [...this.artifacts.list()],
      catalog: this.artifacts.catalog(),
      signal: this.stageSignal(signal),
    }));
    if (!result) throw new WorkflowStopped("Workflow stopped");
    this.updateUsage(result);
    const route = this.addArtifact("route", [artifact], result.artifact);
    return validateRouterSelection(choices, array(object(route.payload).stages).map(String));
  }

  async runGraph(input: string): Promise<"done" | "stopped"> {
    this.ui.arm({ name: this.definition.name, source: this.definition.source, color: this.definition.color, stage: "starting" });
    const inputArtifact = this.addArtifact("input", [], {
      artifactKind: "workflow-input",
      outcome: "provided",
      summary: input.trim() || "No workflow input supplied.",
      payload: { text: input },
    });
    type Pending = { stageType: string; parents: WorkflowArtifact[]; iteration: string; approvedPaths?: string[] };
    const pending: Pending[] = [{ stageType: this.definition.entry, parents: [inputArtifact], iteration: "root" }];
    const joins = new Map<string, { parents: Map<string, WorkflowArtifact>; scheduled: boolean }>();
    let invocationCount = 0;

    try {
      while (pending.length > 0) {
        if (invocationCount > 100) throw new Error("Workflow exceeded 100 stage invocations");
        const first = pending[0];
        const firstDefinition = this.definition.stages[first.stageType];
        const batch = firstDefinition.readOnly
          ? pending.filter((item) => this.definition.stages[item.stageType].readOnly).slice(0, this.definition.maxParallel ?? 4)
          : [first];
        for (const item of batch) pending.splice(pending.indexOf(item), 1);
        invocationCount += batch.length;
        const results = await this.ui.runLoader(`${this.definition.name}: ${batch.map((item) => item.stageType).join(", ")}`, (signal) =>
          mapWithConcurrency(batch, this.definition.maxParallel ?? 4, (item) =>
            this.executeStage(item.stageType, item.parents, { input, iteration: item.iteration }, this.stageSignal(signal), item.approvedPaths)
          )
        );
        if (!results) throw new WorkflowStopped("Workflow stopped");

        for (let index = 0; index < batch.length; index++) {
          const item = batch[index];
          const artifact = results[index];
          const stage = this.definition.stages[item.stageType];
          let routingParent = artifact;
          let approvedPaths = item.approvedPaths;

          if (stage.checkpoint === "question" && artifact.artifactKind === "question") {
            const question = object(object(artifact.payload).question) as WorkflowQuestion;
            while (true) {
              const answer = await this.ui.ask(question);
              if (answer.status === "clarification" && answer.clarification) {
                const request = this.addArtifact("clarification-request", [artifact], {
                  artifactKind: "clarification-request",
                  outcome: "requested",
                  summary: answer.clarification,
                  payload: { question, request: answer.clarification },
                });
                if (this.definition.stages.clarify) {
                  const clarification = await this.stage("clarify", [artifact, request]);
                  this.ctx.ui.notify(text(object(clarification.payload).answer) || clarification.summary, "info");
                } else {
                  this.ctx.ui.notify("This workflow has no clarification stage. Rephrase or choose an answer.", "warning");
                }
                continue;
              }
              if (answer.status !== "answered" || !answer.answer) throw new WorkflowStopped("Workflow stopped");
              routingParent = this.addArtifact("decision", [artifact], {
                artifactKind: "decision-record",
                outcome: "answered",
                summary: answer.answer,
                payload: { question: question.text, answer },
              });
              break;
            }
          }
          if (stage.checkpoint === "proposal") {
            const files = array(object(artifact.payload).files).map((file) => text(file.path));
            const choice = await this.ui.choose(`${artifact.summary}\n\nFiles: ${files.join(", ")}`, ["Accept and continue", "Stop workflow"]);
            if (choice !== "Accept and continue") throw new WorkflowStopped("Workflow stopped");
            approvedPaths = files.map((path) => resolve(this.ctx.cwd, path));
            routingParent = this.addArtifact("approval", [artifact], {
              artifactKind: "approval",
              outcome: "accepted",
              summary: `Approved ${files.length} file(s).`,
              payload: { paths: approvedPaths },
            });
          }

          const choices = stage.transitions[artifact.outcome];
          if (!choices) throw new Error(`Stage ${item.stageType} has no route for ${artifact.outcome}`);
          if (choices.length === 0) continue;
          const successors = resolveSuccessorSet(stage.transitions, artifact.outcome)
            ?? await this.chooseRoute(item.stageType, artifact, choices);
          for (const successor of successors) {
            const successorDefinition = this.definition.stages[successor];
            if (!successorDefinition.join) {
              pending.push({ stageType: successor, parents: [routingParent], iteration: item.iteration, approvedPaths });
              continue;
            }
            const key = `${successor}:${item.iteration}`;
            const bucket = joins.get(key) ?? { parents: new Map<string, WorkflowArtifact>(), scheduled: false };
            bucket.parents.set(item.stageType, routingParent);
            joins.set(key, bucket);
            const completed = new Set(bucket.parents.keys());
            const ready = successorDefinition.join.mode === "all"
              ? successorDefinition.join.stages.every((name) => completed.has(name))
              : successorDefinition.join.stages.some((name) => completed.has(name));
            if (ready && !bucket.scheduled) {
              bucket.scheduled = true;
              pending.push({ stageType: successor, parents: [...bucket.parents.values()], iteration: item.iteration, approvedPaths });
            }
          }
        }
      }
      return "done";
    } catch (error) {
      if (error instanceof WorkflowStopped) return "stopped";
      throw error;
    } finally {
      this.ui.stop();
    }
  }
}
