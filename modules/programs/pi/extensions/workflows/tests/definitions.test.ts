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
  assert.match(
    validateWorkflowDefinition({ ...validDefinition, readOnlyCommandPrefixes: { start: ["rm"] } }).join("\n"),
    /readOnlyCommandPrefixes/,
  );
});

test("lets read-only stages list any tool and restricts mutation stages", () => {
  const anyTool = structuredClone(validDefinition) as any;
  anyTool.stages.start.tools = ["bash", "unknown_tool"];
  assert.deepEqual(validateWorkflowDefinition(anyTool), []);

  const mutation = structuredClone(validDefinition) as any;
  mutation.stages.finish = { ...mutation.stages.finish, readOnly: false, mutationPaths: ["$approved"], tools: ["read", "unknown_mutator"] };
  assert.match(validateWorkflowDefinition(mutation).join("\n"), /not approved/);
  mutation.stages.finish.tools = ["read", "bash"];
  assert.match(validateWorkflowDefinition(mutation).join("\n"), /not approved for mutation stages: bash/);
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

test("loads compact bundled refinement workflows", async () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const result = await discoverWorkflowDefinitions({
    globalRoot: join(here, "..", "workflows"),
    projectTrusted: false,
  });
  assert.deepEqual(result.diagnostics, []);

  for (const name of ["refine-spec", "refine-plan"]) {
    const workflow = result.workflows.get(name);
    assert.ok(workflow);
    assert.equal(workflow.entry, "refine");
    assert.deepEqual(Object.keys(workflow.stages), ["refine", "write"]);
    assert.equal(workflow.stages.refine.checkpoint, "proposal");
    assert.deepEqual(workflow.stages.refine.transitions, { proposed: [["write"]] });
    assert.deepEqual(workflow.stages.write.transitions, { done: [] });
  }
});

test("warns that a trusted project's read-only exceptions file is no longer used", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-workflows-"));
  const globalRoot = join(root, "global");
  const projectRoot = join(root, "project");
  await writeWorkflow(globalRoot, "demo", validDefinition);
  await mkdir(projectRoot, { recursive: true });
  await writeFile(join(projectRoot, "read-only-exceptions.json"), "{}");

  const untrusted = await discoverWorkflowDefinitions({ globalRoot, projectRoot, projectTrusted: false });
  assert.deepEqual(untrusted.diagnostics, []);
  const trusted = await discoverWorkflowDefinitions({ globalRoot, projectRoot, projectTrusted: true });
  assert.deepEqual(trusted.diagnostics, [
    `${join(projectRoot, "read-only-exceptions.json")}: read-only-exceptions.json is no longer used, because read-only stages are prompt-only`,
  ]);
  assert.ok(trusted.workflows.get("demo"));
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

test("lets a read-only stage omit tools and requires them on a mutation stage", () => {
  const readOnly = structuredClone(validDefinition) as any;
  delete readOnly.stages.start.tools;
  assert.deepEqual(validateWorkflowDefinition(readOnly), []);

  const mutation = structuredClone(validDefinition) as any;
  mutation.stages.finish = { ...mutation.stages.finish, readOnly: false, mutationPaths: ["$approved"] };
  delete mutation.stages.finish.tools;
  assert.match(validateWorkflowDefinition(mutation).join("\n"), /tools must be strings/);
});

test("rejects a schema outcome without a route, except in the clarify stage", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-workflows-"));
  const definition = structuredClone(validDefinition) as any;
  definition.stages.start.outputSchema = "schemas/start-outcomes.json";
  definition.stages.clarify = { ...definition.stages.finish, outputSchema: "schemas/clarify.json", transitions: {} };
  await writeWorkflow(root, "demo", definition);
  const schemas = join(root, "demo", "schemas");
  await writeFile(join(schemas, "clarify.json"), JSON.stringify({ type: "object", properties: { outcome: { enum: ["answered"] } } }));

  const startOutcome = (outcome: unknown) =>
    writeFile(join(schemas, "start-outcomes.json"), JSON.stringify({ type: "object", properties: { outcome } }));

  for (const outcome of [{ enum: ["ready", "blocked"] }, { const: "blocked" }]) {
    await startOutcome(outcome);
    const unrouted = await discoverWorkflowDefinitions({ globalRoot: root, projectTrusted: false });
    assert.match(unrouted.diagnostics.join("\n"), /stage start outcome has no route: blocked/);
    assert.equal(unrouted.workflows.get("demo"), undefined);
  }

  await startOutcome({ const: "ready" });
  const routed = await discoverWorkflowDefinitions({ globalRoot: root, projectTrusted: false });
  assert.deepEqual(routed.diagnostics, []);
  assert.ok(routed.workflows.get("demo"));
});

test("treats an inherited key such as constructor as an outcome without a route at load", async () => {
  const root = await mkdtemp(join(tmpdir(), "pi-workflows-"));
  const definition = structuredClone(validDefinition) as any;
  definition.stages.start.outputSchema = "schemas/start-outcomes.json";
  await writeWorkflow(root, "demo", definition);
  await writeFile(
    join(root, "demo", "schemas", "start-outcomes.json"),
    JSON.stringify({ type: "object", properties: { outcome: { enum: ["ready", "constructor"] } } }),
  );
  const result = await discoverWorkflowDefinitions({ globalRoot: root, projectTrusted: false });
  assert.match(result.diagnostics.join("\n"), /stage start outcome has no route: constructor/);
  assert.equal(result.workflows.get("demo"), undefined);
});
