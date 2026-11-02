import type { BranchEntry } from "../branch.ts";

export const question = {
  question: "Which database should this service use?",
  options: [{ label: "PostgreSQL" }, { label: "SQLite" }],
};

export const clarification = {
  ...question,
  answer: null,
  clarification: "Does it need concurrent writes?",
  status: "clarification" as const,
};

export const answered = {
  ...question,
  answer: "SQLite",
  index: 2,
  source: "option" as const,
  status: "answered" as const,
};

export function toolResult(id: string, details: unknown, toolName = "ask_user"): BranchEntry {
  return { type: "message", id, message: { role: "toolResult", toolName, details } };
}

export function assistant(id: string, stopReason = "stop"): BranchEntry {
  return { type: "message", id, message: { role: "assistant", stopReason } };
}

export function user(id: string, text: string): BranchEntry {
  return { type: "message", id, message: { role: "user", content: [{ type: "text", text }] } };
}

export function answerMessage(id: string, details: unknown): BranchEntry {
  return { type: "custom_message", id, customType: "ask-user-answer", details };
}

export function askUserEntry(id: string, data: unknown): BranchEntry {
  return { type: "custom", id, customType: "ask-user", data };
}
