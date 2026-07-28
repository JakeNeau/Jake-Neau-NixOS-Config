export interface ArtifactCandidate {
  artifactKind: string;
  outcome: string;
  summary: string;
  payload: unknown;
}

export interface WorkflowArtifact extends ArtifactCandidate {
  schemaVersion: 1;
  runId: string;
  artifactId: string;
  workflow: string;
  stageType: string;
  stageInvocationId: string;
  parentArtifactIds: string[];
  createdAt: string;
}

export interface ArtifactCatalogEntry {
  artifactId: string;
  artifactKind: string;
  stageType: string;
  summary: string;
  parentArtifactIds: string[];
}

type JsonSchema = Record<string, unknown>;

function valueType(value: unknown): string {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  if (Number.isInteger(value)) return "integer";
  return typeof value;
}

function sameJsonValue(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function validateSchemaValue(schema: JsonSchema, value: unknown, path = "$", errors: string[] = []): string[] {
  if (Array.isArray(schema.enum) && !schema.enum.some((item) => sameJsonValue(item, value))) {
    errors.push(`${path}: value is not in enum`);
  }
  if ("const" in schema && !sameJsonValue(schema.const, value)) {
    errors.push(`${path}: value does not match const`);
  }
  if (Array.isArray(schema.anyOf)) {
    const matches = schema.anyOf.some((candidate) =>
      validateSchemaValue(candidate as JsonSchema, value, path, []).length === 0
    );
    if (!matches) errors.push(`${path}: value does not match anyOf`);
    return errors;
  }
  if (Array.isArray(schema.oneOf)) {
    const matches = schema.oneOf.filter((candidate) =>
      validateSchemaValue(candidate as JsonSchema, value, path, []).length === 0
    ).length;
    if (matches !== 1) errors.push(`${path}: value must match exactly one oneOf schema`);
    return errors;
  }

  const expected = schema.type;
  if (typeof expected === "string") {
    const actual = valueType(value);
    const valid = expected === actual || (expected === "number" && actual === "integer");
    if (!valid) {
      errors.push(`${path}: expected ${expected}, got ${actual}`);
      return errors;
    }
  }

  if (typeof value === "string") {
    if (typeof schema.minLength === "number" && value.length < schema.minLength) {
      errors.push(`${path}: shorter than minLength ${schema.minLength}`);
    }
    if (typeof schema.maxLength === "number" && value.length > schema.maxLength) {
      errors.push(`${path}: longer than maxLength ${schema.maxLength}`);
    }
    if (typeof schema.pattern === "string" && !new RegExp(schema.pattern).test(value)) {
      errors.push(`${path}: does not match pattern`);
    }
  }

  if (typeof value === "number") {
    if (typeof schema.minimum === "number" && value < schema.minimum) {
      errors.push(`${path}: less than minimum ${schema.minimum}`);
    }
    if (typeof schema.maximum === "number" && value > schema.maximum) {
      errors.push(`${path}: greater than maximum ${schema.maximum}`);
    }
  }

  if (Array.isArray(value)) {
    if (typeof schema.minItems === "number" && value.length < schema.minItems) {
      errors.push(`${path}: fewer than minItems ${schema.minItems}`);
    }
    if (typeof schema.maxItems === "number" && value.length > schema.maxItems) {
      errors.push(`${path}: more than maxItems ${schema.maxItems}`);
    }
    if (schema.uniqueItems === true) {
      const keys = value.map((item) => JSON.stringify(item));
      if (new Set(keys).size !== keys.length) errors.push(`${path}: items are not unique`);
    }
    if (schema.items && typeof schema.items === "object") {
      value.forEach((item, index) => validateSchemaValue(schema.items as JsonSchema, item, `${path}[${index}]`, errors));
    }
  }

  if (value && typeof value === "object" && !Array.isArray(value)) {
    const object = value as Record<string, unknown>;
    const properties = (schema.properties ?? {}) as Record<string, JsonSchema>;
    const required = Array.isArray(schema.required) ? schema.required.filter((item): item is string => typeof item === "string") : [];
    for (const key of required) {
      if (!(key in object)) errors.push(`${path}.${key}: required property is missing`);
    }
    for (const [key, child] of Object.entries(object)) {
      if (properties[key]) {
        validateSchemaValue(properties[key], child, `${path}.${key}`, errors);
      } else if (schema.additionalProperties === false) {
        errors.push(`${path}.${key}: additional property is not allowed`);
      }
    }
  }

  return errors;
}

export class ArtifactStore {
  readonly runId: string;
  readonly workflow: string;
  private readonly now: () => string;
  private readonly artifacts: WorkflowArtifact[] = [];
  private readonly byId = new Map<string, WorkflowArtifact>();
  private readonly producerIds = new Set<string>();

  constructor(runId: string, workflow: string, now: () => string = () => new Date().toISOString()) {
    this.runId = runId;
    this.workflow = workflow;
    this.now = now;
  }

  append(
    stageType: string,
    stageInvocationId: string,
    parentArtifactIds: string[],
    candidate: ArtifactCandidate,
  ): WorkflowArtifact {
    if (this.producerIds.has(stageInvocationId)) {
      throw new Error(`Stage invocation ${stageInvocationId} already produced an artifact`);
    }
    for (const parent of parentArtifactIds) {
      if (!this.byId.has(parent)) throw new Error(`Unknown parent artifact: ${parent}`);
    }
    if (new Set(parentArtifactIds).size !== parentArtifactIds.length) {
      throw new Error("Parent artifact identities must be unique");
    }

    const artifact: WorkflowArtifact = {
      schemaVersion: 1,
      runId: this.runId,
      artifactId: `${this.runId}:${this.artifacts.length + 1}`,
      workflow: this.workflow,
      stageType,
      stageInvocationId,
      parentArtifactIds: [...parentArtifactIds],
      createdAt: this.now(),
      ...candidate,
    };
    this.artifacts.push(artifact);
    this.byId.set(artifact.artifactId, artifact);
    this.producerIds.add(stageInvocationId);
    return artifact;
  }

  get(artifactId: string): WorkflowArtifact | undefined {
    return this.byId.get(artifactId);
  }

  list(): readonly WorkflowArtifact[] {
    return this.artifacts;
  }

  catalog(): ArtifactCatalogEntry[] {
    return this.artifacts.map(({ artifactId, artifactKind, stageType, summary, parentArtifactIds }) => ({
      artifactId,
      artifactKind,
      stageType,
      summary,
      parentArtifactIds: [...parentArtifactIds],
    }));
  }
}
