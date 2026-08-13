import { createHash, randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { ArtifactStore, type ArtifactCandidate, type WorkflowArtifact } from "./artifacts.ts";
import type { LoadedWorkflow, StageDefinition } from "./definitions.ts";
import { InvocationGraph, mapWithConcurrency, resolveSuccessorSet, validateRouterSelection } from "./engine.ts";
import { approvedPlanTargets, approvedTargets } from "./paths.ts";
import { chooseSpecificationLocation, fingerprintIssue, suppressSkippedIssues, type RefinementIssue } from "./refine-spec.ts";
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

async function fileHash(path: string): Promise<string | null> {
  if (!existsSync(path)) return null;
  return createHash("sha256").update(await readFile(path)).digest("hex");
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

  async runRefinement(input: string): Promise<"done" | "stopped"> {
    const planMode = this.definition.name === "refine-plan";
    this.ui.arm({ name: this.definition.name, source: this.definition.source, color: this.definition.color, stage: "starting" });
    const inputArtifact = this.addArtifact("input", [], {
      artifactKind: "workflow-input",
      outcome: "provided",
      summary: input.trim() || "No input supplied. Audit all active specifications.",
      payload: { text: input },
    });
    try {
      let context = await this.stage("discover", [inputArtifact], { input });
      if (context.outcome === "ambiguous") {
        const intent = await this.ui.choose(`How should ${this.definition.name} use this input?`, [
          "Treat it as a new design idea",
          "Treat it as an area that needs refinement",
          "Ignore it and audit all active specifications",
          "Stop workflow",
        ]);
        if (!intent || intent === "Stop workflow") throw new WorkflowStopped("Workflow stopped");
        const intentName = intent.startsWith("Treat it as a new") ? "idea" : intent.startsWith("Treat it as an area") ? "focus" : "audit";
        const intentArtifact = this.addArtifact("intent", [context], {
          artifactKind: "intent-decision",
          outcome: intentName,
          summary: intent,
          payload: { intent: intentName },
        });
        context = await this.stage("discover", [inputArtifact, intentArtifact], { input, forcedIntent: intentName });
      }

      const payload = object(context.payload);
      const locationRecords = array(payload.locations).map((location) => ({
        path: text(location.path),
        evidence: text(location.evidence),
        documented: location.documented === true,
        fileCount: Number(location.fileCount ?? 0),
      })).filter((location) => location.path);
      const inferred = chooseSpecificationLocation(locationRecords);
      if (inferred.warning) this.ctx.ui.notify(inferred.warning, "warning");
      let chosenLocation = payload.confidence === "low" && !locationRecords.some((location) => location.documented)
        ? undefined
        : inferred.path || text(payload.chosenLocation);
      if (!chosenLocation) {
        const locations = locationRecords.map((location) => location.path);
        if (locations.length === 0) throw new Error("The workflow could not identify a specification location");
        const choice = await this.ui.choose("Choose the canonical specification location", [...locations, "Stop workflow"]);
        if (!choice || choice === "Stop workflow") throw new WorkflowStopped("Workflow stopped");
        chosenLocation = choice;
      }
      if (chosenLocation !== payload.chosenLocation) {
        context = this.addArtifact("spec-location", [context], {
          artifactKind: "spec-context",
          outcome: context.outcome,
          summary: `Selected ${chosenLocation} as the canonical specification location.`,
          payload: { ...payload, chosenLocation, confidence: inferred.needsUser ? "high" : payload.confidence },
        });
      }
      for (const warning of array(object(context.payload).warnings)) this.ctx.ui.notify(String(warning), "warning");

      if (context.outcome === "audit") return await this.runAudit(context, planMode);
      const focus = this.addArtifact("focus", [context], {
        artifactKind: "focus-item",
        outcome: "selected",
        summary: input.trim() || "Refine the selected specification area.",
        payload: { input, intent: context.outcome },
      });
      const result = await this.refineOne(context, focus, false, planMode);
      return result === "passed" ? "done" : "stopped";
    } catch (error) {
      if (error instanceof WorkflowStopped) return "stopped";
      throw error;
    } finally {
      this.ui.stop();
    }
  }

  private async runAudit(context: WorkflowArtifact, planMode: boolean): Promise<"done" | "stopped"> {
    const skipped = new Set<string>();
    const resolved = new Set<string>();
    while (true) {
      const state = this.addArtifact("audit-state", [context], {
        artifactKind: "resolved-issues",
        outcome: "current",
        summary: `${resolved.size} resolved and ${skipped.size} skipped issues in this run.`,
        payload: { resolved: [...resolved], skipped: [...skipped] },
      });
      const audit = await this.stage("audit", [context, state]);
      const issues = suppressSkippedIssues(
        array(object(audit.payload).issues) as RefinementIssue[],
        new Set([...skipped, ...resolved]),
      );
      if (audit.outcome === "no-issues" || issues.length === 0) {
        this.ctx.ui.notify(`No unresolved ${planMode ? "plan" : "specification"} issues remain.`, "info");
        return "done";
      }
      const issue = issues[0];
      const choice = await this.ui.choose(
        `${issue.title}\n\n${issue.claim}\n\n${issue.rankingReason ?? "Highest-ranked current issue"}`,
        ["Refine this issue", "Skip this issue for this run", "Stop workflow"],
      );
      if (!choice || choice === "Stop workflow") return "stopped";
      const fingerprint = fingerprintIssue(issue);
      if (choice.startsWith("Skip")) {
        skipped.add(fingerprint);
        continue;
      }
      const focus = this.addArtifact("focus", [audit], {
        artifactKind: "focus-item",
        outcome: "selected",
        summary: issue.title,
        payload: issue,
      });
      const result = await this.refineOne(context, focus, true, planMode);
      if (result === "stopped") return "stopped";
      if (result === "skipped") skipped.add(fingerprint);
      if (result === "passed") resolved.add(fingerprint);
    }
  }

  private async collectDecisions(
    focus: WorkflowArtifact,
    synthesis: WorkflowArtifact,
    decisions: WorkflowArtifact[],
  ): Promise<void> {
    while (true) {
      const elicited = await this.stage("elicit", [synthesis, ...decisions]);
      if (elicited.outcome === "ready") return;
      const question = object(object(elicited.payload).question) as WorkflowQuestion;
      if (!question.text || !Array.isArray(question.options)) throw new Error("Elicitation stage returned no valid question");

      while (true) {
        this.ui.setDecisionWidget(text(focus.summary), decisions.map((decision) => decision.summary));
        const answer = await this.ui.ask(question);
        if (answer.status === "cancelled") throw new WorkflowStopped("Workflow stopped");
        if (answer.status === "clarification" && answer.clarification) {
          const request = this.addArtifact("clarification-request", [elicited], {
            artifactKind: "clarification-request",
            outcome: "requested",
            summary: answer.clarification,
            payload: { question, request: answer.clarification },
          });
          const clarification = await this.stage("clarify", [synthesis, elicited, request]);
          this.ctx.ui.notify(text(object(clarification.payload).answer), "info");
          continue;
        }
        if (answer.status !== "answered" || !answer.answer) continue;
        const option = answer.index ? question.options[answer.index - 1] : undefined;
        decisions.push(this.addArtifact("decision", [elicited], {
          artifactKind: "decision-record",
          outcome: "answered",
          summary: option?.label ?? answer.answer,
          payload: {
            question: question.text,
            answer: option ? { id: option.id, label: option.label } : { freeForm: answer.answer },
            reason: option?.consequence ?? "The user supplied a free-form answer.",
            rejectedAlternatives: question.options.filter((candidate) => candidate.id !== option?.id),
          },
        }));
        break;
      }
    }
  }

  private async refineOne(
    context: WorkflowArtifact,
    focus: WorkflowArtifact,
    auditMode: boolean,
    planMode: boolean,
  ): Promise<"passed" | "skipped" | "stopped"> {
    const evidence = await this.parallelStage("investigate", [context, focus], [
      { lens: "specification", iteration: focus.artifactId },
      { lens: "documentation", iteration: focus.artifactId },
      { lens: "implementation", iteration: focus.artifactId },
      { lens: "verification", iteration: focus.artifactId },
    ]);
    const synthesis = await this.stage("synthesize", evidence, { iteration: focus.artifactId });
    const decisions: WorkflowArtifact[] = [];
    await this.collectDecisions(focus, synthesis, decisions);

    let proposal = await this.stage("propose", [context, synthesis, ...decisions]);
    while (true) {
      const proposalPayload = object(proposal.payload);
      const files = array(proposalPayload.files).map((file) => text(file.path));
      const choice = await this.ui.choose(
        `${proposalPayload.design}\n\nFiles: ${files.join(", ")}\n\nDoes this design make sense?`,
        ["Accept and write", "Ask more questions", "Correct the proposal", "Skip this issue", "Stop workflow"],
      );
      if (!choice || choice === "Stop workflow") return "stopped";
      if (choice === "Skip this issue") return "skipped";
      if (choice === "Ask more questions") {
        const request = await this.ui.edit("What should the workflow refine further?");
        decisions.push(this.addArtifact("decision", [proposal], {
          artifactKind: "decision-record",
          outcome: "answered",
          summary: request?.trim() || "Ask more design questions.",
          payload: {
            question: "What needs further refinement?",
            answer: { freeForm: request?.trim() || "Ask more questions based on the current evidence." },
            reason: "User requested more design work.",
            rejectedAlternatives: [],
          },
        }));
        await this.collectDecisions(focus, synthesis, decisions);
        proposal = await this.stage("propose", [context, synthesis, ...decisions]);
        continue;
      }
      if (choice === "Correct the proposal") {
        const correction = await this.ui.edit("Correct the proposal");
        if (!correction?.trim()) continue;
        decisions.push(this.addArtifact("decision", [proposal], {
          artifactKind: "decision-record",
          outcome: "answered",
          summary: correction.trim(),
          payload: { question: "How should the proposal change?", answer: { freeForm: correction.trim() }, reason: "User corrected the proposal.", rejectedAlternatives: [] },
        }));
        proposal = await this.stage("propose", [context, synthesis, ...decisions]);
        continue;
      }

      const approvedPaths = this.approvedPaths(context, proposal, planMode);
      const baselines = new Map<string, string | null>();
      for (const path of approvedPaths) baselines.set(path, await fileHash(path));
      const approval = this.addArtifact("approval", [proposal], {
        artifactKind: "approval",
        outcome: "accepted",
        summary: `Approved changes to ${approvedPaths.length} ${planMode ? "plan" : "specification"} file(s).`,
        payload: { paths: approvedPaths, baselines: Object.fromEntries(baselines) },
      });
      for (const [path, hash] of baselines) {
        if (await fileHash(path) !== hash) throw new Error(`${planMode ? "Plan" : "Specification"} changed after approval: ${path}`);
      }
      let write = await this.stage("write", [proposal, approval, ...decisions], { approvedPaths }, approvedPaths);
      const changed = await Promise.all(approvedPaths.map(async (path) => (await fileHash(path)) !== baselines.get(path)));
      if (!changed.some(Boolean)) throw new Error(`The writer did not change any approved ${planMode ? "plan" : "specification"} file`);
      let verification = await this.stage("verify", [proposal, write, ...decisions], { auditMode });
      if (verification.outcome === "failed") {
        write = await this.stage("write", [proposal, write, verification, ...decisions], { correction: true, approvedPaths }, approvedPaths);
        verification = await this.stage("verify", [proposal, write, verification, ...decisions], { auditMode });
      }
      if (verification.outcome !== "passed") {
        this.ctx.ui.notify(`${planMode ? "Plan" : "Specification"} verification failed after one correction.`, "error");
        return "stopped";
      }
      this.ctx.ui.notify(`${planMode ? "Plan" : "Specification"} refinement written and verified.`, "info");
      return "passed";
    }
  }

  private approvedPaths(context: WorkflowArtifact, proposal: WorkflowArtifact, planMode: boolean): string[] {
    const location = text(object(context.payload).chosenLocation);
    if (!location) throw new Error("No approved specification location");
    const payload = object(proposal.payload);
    const paths = array(payload.files).map((file) => text(file.path));
    if (paths.length === 0) throw new Error(`The proposal contains no ${planMode ? "plan" : "specification"} files`);
    if (!planMode) return approvedTargets(this.ctx.cwd, location, paths);
    const specificationPath = text(payload.specificationPath);
    if (!specificationPath) throw new Error("The plan proposal does not identify its specification");
    return approvedPlanTargets(this.ctx.cwd, location, specificationPath, paths);
  }
}
