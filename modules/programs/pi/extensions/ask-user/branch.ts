import type { AskUserDetails, AskUserParams } from "./core.ts";

export const ANSWER_MESSAGE_TYPE = "ask-user-answer";
export const ENTRY_TYPE = "ask-user";

// Sessions saved before the custom message stored each reopened answer as a user message.
const LEGACY_ANSWER = 'My answer to the pending question "';
const LEGACY_CLARIFICATION = 'I need another clarification before answering "';

// The fields of Pi's session entries that the branch rule reads.
interface BranchMessage {
  role: string;
  toolName?: string;
  details?: unknown;
  content?: string | Array<{ type: string; text?: string }>;
  stopReason?: string;
}

export interface BranchEntry {
  type: string;
  id: string;
  customType?: string;
  data?: unknown;
  details?: unknown;
  message?: BranchMessage;
}

export interface PendingClarification {
  markerId: string;
  question: AskUserParams;
}

interface Marker {
  status: AskUserDetails["status"];
  question?: AskUserParams;
}

function detailsMarker(value: unknown): Marker | undefined {
  const details = value as Partial<AskUserDetails> | undefined;
  // A failed tool call has no status, so it leaves a pending question in place.
  if (typeof details?.status !== "string") return undefined;
  return { status: details.status, question: { question: details.question!, options: details.options! } };
}

function legacyMarker(content: BranchMessage["content"]): Marker | undefined {
  const text = typeof content === "string" ? content : content?.find((part) => part.type === "text")?.text;
  if (text?.startsWith(LEGACY_ANSWER)) return { status: "answered" };
  if (text?.startsWith(LEGACY_CLARIFICATION)) return { status: "clarification" };
  return undefined;
}

function marker(entry: BranchEntry): Marker | undefined {
  if (entry.type === "custom" && entry.customType === ENTRY_TYPE) return detailsMarker(entry.data);
  if (entry.type === "custom_message" && entry.customType === ANSWER_MESSAGE_TYPE) return detailsMarker(entry.details);
  if (entry.type !== "message" || !entry.message) return undefined;
  const { message } = entry;
  if (message.role === "toolResult" && message.toolName === "ask_user") return detailsMarker(message.details);
  if (message.role === "user") return legacyMarker(message.content);
  return undefined;
}

export function pendingClarification(branch: readonly BranchEntry[]): PendingClarification | undefined {
  let pending: PendingClarification | undefined;
  for (const entry of branch) {
    const found = marker(entry);
    if (!found) continue;
    // A legacy clarification carries no question, so it keeps the previous marker's.
    const question = found.question ?? pending?.question;
    pending = found.status === "clarification" && question ? { markerId: entry.id, question } : undefined;
  }
  return pending;
}

export function answerRunEndedEarly(branch: readonly BranchEntry[]): boolean {
  const last = branch.findLast((entry) => entry.type === "message" && entry.message?.role === "assistant");
  return last?.message?.stopReason === "aborted" || last?.message?.stopReason === "error";
}
