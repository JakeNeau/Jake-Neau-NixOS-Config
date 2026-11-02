import type { DialogEvent } from "../ask-user/dialog-state.ts";
import type { ArtifactCandidate } from "./artifacts.ts";

export interface WorkflowAnswer {
  answer: string | null;
  index?: number;
  clarification?: string;
  status: "answered" | "clarification" | "cancelled";
}

export function workflowAnswerForDialogEvent(
  labels: string[],
  event: DialogEvent,
): WorkflowAnswer {
  if (event.type === "cancelled") return { answer: null, status: "cancelled" };
  if (event.type === "free-form") return { answer: event.value, status: "answered" };
  if (event.type === "clarification") {
    return {
      answer: null,
      clarification: event.value,
      status: "clarification",
    };
  }

  return {
    answer: labels[event.index]!,
    index: event.index + 1,
    status: "answered",
  };
}

function isRecord(value: unknown): value is Record<string, any> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

// The question dialog renders these fields, so a missing one breaks or garbles it.
export function questionErrors(artifact: ArtifactCandidate): string[] {
  if (artifact.artifactKind !== "question") return [];
  const question = isRecord(artifact.payload) ? artifact.payload.question : undefined;
  if (!isRecord(question)) return ["payload.question must be an object"];
  const errors: string[] = [];
  for (const field of ["text", "why"]) {
    if (typeof question[field] !== "string") errors.push(`payload.question.${field} must be a string`);
  }
  if (!Array.isArray(question.options) || question.options.length === 0) {
    errors.push("payload.question.options must be a non-empty array");
  } else {
    question.options.forEach((option: unknown, index: number) => {
      for (const field of ["label", "consequence"]) {
        if (!isRecord(option) || typeof option[field] !== "string") {
          errors.push(`payload.question.options[${index}].${field} must be a string`);
        }
      }
    });
  }
  const { recommendation } = question;
  if (recommendation !== undefined && recommendation !== null && typeof recommendation !== "string") {
    errors.push("payload.question.recommendation must be a string or null");
  }
  return errors;
}
