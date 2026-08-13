import type { DialogEvent } from "../ask-user/dialog-state.ts";

export interface WorkflowAnswer {
  answer: string | null;
  index?: number;
  clarification?: string;
  status: "answered" | "clarification" | "explore" | "cancelled";
}

export function workflowAnswerForDialogEvent(
  labels: string[],
  event: DialogEvent,
  exploreIndex?: number,
): WorkflowAnswer {
  if (event.type === "cancelled") return { answer: null, status: "cancelled" };
  if (event.type === "selected" && event.index === exploreIndex) {
    return { answer: null, status: "explore" };
  }
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
