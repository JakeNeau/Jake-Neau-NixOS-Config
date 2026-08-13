import type { WorkflowArtifact } from "./artifacts.ts";

export const MAX_STAGE_CONTEXT_BYTES = 50 * 1024;

type EvidenceFinding = {
  claim?: unknown;
  path?: unknown;
  excerpt?: unknown;
  meaning?: unknown;
};

type EvidencePayload = {
  lens?: unknown;
  findings?: unknown;
  constraints?: unknown;
  openQuestions?: unknown;
};

export interface FittedStageContext {
  artifacts: WorkflowArtifact[];
  serialized: string;
  compacted: boolean;
}

export function serializeStageContext(
  extra: Record<string, unknown>,
  artifacts: readonly WorkflowArtifact[],
): string {
  return JSON.stringify({ extra, artifacts });
}

function text(value: unknown): string {
  return typeof value === "string" ? value : String(value ?? "");
}

function truncate(value: unknown, maxLength: number): string {
  const result = text(value);
  return result.length <= maxLength ? result : `${result.slice(0, maxLength - 1)}…`;
}

function evidencePayload(artifact: WorkflowArtifact): EvidencePayload {
  return artifact.payload && typeof artifact.payload === "object"
    ? artifact.payload as EvidencePayload
    : {};
}

function findings(payload: EvidencePayload): EvidenceFinding[] {
  return Array.isArray(payload.findings)
    ? payload.findings.filter((finding): finding is EvidenceFinding => Boolean(finding) && typeof finding === "object")
    : [];
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.map(text) : [];
}

function withoutExcerpts(artifact: WorkflowArtifact): WorkflowArtifact {
  const payload = evidencePayload(artifact);
  return {
    ...artifact,
    payload: {
      lens: payload.lens,
      findings: findings(payload).map((finding) => ({
        claim: text(finding.claim),
        path: text(finding.path),
        meaning: text(finding.meaning),
      })),
      constraints: strings(payload.constraints),
      openQuestions: strings(payload.openQuestions),
    },
  };
}

function boundedEvidence(artifact: WorkflowArtifact): WorkflowArtifact {
  const payload = evidencePayload(artifact);
  return {
    ...artifact,
    summary: truncate(artifact.summary, 500),
    payload: {
      lens: payload.lens,
      findings: findings(payload).slice(0, 6).map((finding) => ({
        claim: truncate(finding.claim, 300),
        path: truncate(finding.path, 200),
        meaning: truncate(finding.meaning, 350),
      })),
      constraints: strings(payload.constraints).slice(0, 6).map((value) => truncate(value, 300)),
      openQuestions: strings(payload.openQuestions).slice(0, 6).map((value) => truncate(value, 300)),
    },
  };
}

function summaryEvidence(artifact: WorkflowArtifact): WorkflowArtifact {
  const payload = evidencePayload(artifact);
  return {
    ...artifact,
    summary: truncate(artifact.summary, 300),
    payload: {
      lens: payload.lens,
      findings: [],
      constraints: [],
      openQuestions: [],
    },
  };
}

export function fitEvidenceStageContext(
  extra: Record<string, unknown>,
  artifacts: readonly WorkflowArtifact[],
  maxBytes = MAX_STAGE_CONTEXT_BYTES,
): FittedStageContext {
  const original = serializeStageContext(extra, artifacts);
  if (Buffer.byteLength(original) <= maxBytes) {
    return { artifacts: [...artifacts], serialized: original, compacted: false };
  }

  for (const compact of [withoutExcerpts, boundedEvidence, summaryEvidence]) {
    const compactedArtifacts = artifacts.map(compact);
    const serialized = serializeStageContext(extra, compactedArtifacts);
    if (Buffer.byteLength(serialized) <= maxBytes) {
      return { artifacts: compactedArtifacts, serialized, compacted: true };
    }
  }

  throw new Error("Compacted synthesis inputs exceed 50 KB");
}
