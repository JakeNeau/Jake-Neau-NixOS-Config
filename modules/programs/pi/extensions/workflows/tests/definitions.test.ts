import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import { discoverWorkflowDefinitions, validateWorkflowDefinition } from "../definitions.ts";

const validDefinition = {
  version: 1,
  name: "demo",
  description: "Demonstrate workflows",
  inputHint: "[task]",
  color: "warning",
  entry: "start",
  terminalOutcomes: ["done"],
  stages: {
    start: {
      prompt: "stages/start.md",
      tools: ["read"],
      readOnly: true,
      inputs: [],
      outputSchema: "schemas/start.json",
      transitions: { ready: [["finish"]] },
    },
    finish: {
      prompt: "stages/finish.md",
      tools: ["read"],
      readOnly: true,
      inputs: ["evidence"],
      outputSchema: "schemas/finish.json",
      transitions: { done: [] },
    },
  },
};

async function writeWorkflow(root: string, name: string, definition: Record<string, unknown>) {
  const dir = join(root, name);
  await mkdir(join(dir, "stages"), { recursive: true });
  await mkdir(join(dir, "schemas"), { recursive: true });
  await writeFile(join(dir, "workflow.json"), JSON.stringify(definition));
  await writeFile(join(dir, "stages/start.md"), "Start");
  await writeFile(join(dir, "stages/finish.md"), "Finish");
  await writeFile(join(dir, "schemas/start.json"), JSON.stringify({ type: "object" }));
  await writeFile(join(dir, "schemas/finish.json"), JSON.stringify({ type: "object" }));
}

test("accepts a reachable workflow and rejects model control", () => {
  assert.deepEqual(validateWorkflowDefinition(validDefinition), []);
  assert.match(
    validateWorkflowDefinition({ ...validDefinition, model: "forbidden" }).join("\n"),
    /model/,
  );
  const unsafe = structuredClone(validDefinition);
  unsafe.stages.start.tools = ["unknown_mutator"];
  assert.match(validateWorkflowDefinition(unsafe).join("\n"), /not approved/);
});

test("rejects broken transitions, joins, and nonterminal dead ends", () => {
  const broken = structuredClone(validDefinition);
  broken.stages.start.transitions.ready = [["missing"]];
  broken.stages.finish.transitions = { waiting: [] };
  (broken.stages.finish as Record<string, unknown>).join = {
    mode: "all",
    stages: ["unknown"],
  };

  const errors = validateWorkflowDefinition(broken).join("\n");
  assert.match(errors, /missing/);
  assert.match(errors, /unknown/);
  assert.match(errors, /terminal outcome/);
});

test("loads the bundled refine-spec definition without diagnostics", async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const result = await discoverWorkflowDefinitions({
    globalRoot: join(here, "..", "workflows"),
    projectTrusted: false,
  });
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.workflows.get("refine-spec")?.stages.investigate.join, undefined);
  assert.equal(result.workflows.get("refine-spec")?.stages.synthesize.join?.mode, "all");
});

test("loads trusted project workflows and requires explicit replacement", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-workflows-"));
  const globalRoot = join(root, "global");
  const projectRoot = join(root, "project");
  await writeWorkflow(globalRoot, "demo", validDefinition);
  await writeWorkflow(projectRoot, "demo", validDefinition);

  const untrusted = await discoverWorkflowDefinitions({ globalRoot, projectRoot, projectTrusted: false });
  assert.equal(untrusted.workflows.get("demo")?.source, "global");

  const collision = await discoverWorkflowDefinitions({ globalRoot, projectRoot, projectTrusted: true });
  assert.equal(collision.workflows.get("demo")?.source, "global");
  assert.match(collision.diagnostics.join("\n"), /replaces/);

  await writeWorkflow(projectRoot, "demo", { ...validDefinition, replaces: "demo" });
  const replaced = await discoverWorkflowDefinitions({ globalRoot, projectRoot, projectTrusted: true });
  assert.equal(replaced.workflows.get("demo")?.source, "project");
  assert.equal(replaced.workflows.get("demo")?.replaces, "demo");
});
