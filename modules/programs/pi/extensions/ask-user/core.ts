import type { DialogEvent } from "./dialog-state.ts";

export const FREE_FORM_CHOICE = "Type a free-form answer...";
export const CLARIFICATION_CHOICE = "Ask a clarifying question...";

export interface AskUserOption {
  label: string;
  preview?: string;
}

export interface AskUserParams {
  question: string;
  options: AskUserOption[];
}

export interface AskUserDetails {
  question: string;
  options: AskUserOption[];
  answer: string | null;
  index?: number;
  source?: "option" | "free-form";
  clarification?: string;
  status: "answered" | "clarification" | "cancelled" | "unavailable";
}

interface AskUserUi {
  select: (question: string, options: string[]) => Promise<string | undefined>;
  input: (title: string, placeholder: string) => Promise<string | undefined>;
}

export type AskUserResult = {
  content: Array<{ type: "text"; text: string }>;
  details: AskUserDetails;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

// A bare carriage return renders as a line break, so a label could show as stacked rows.
function withoutCarriageReturns(
  record: Record<string, unknown>,
  keys: string[],
): Record<string, unknown> {
  const result = { ...record };
  for (const key of keys) {
    const value = result[key];
    if (typeof value === "string") result[key] = value.replaceAll("\r", "");
  }
  return result;
}

// Malformed input passes through unchanged for validation to reject.
export function normalizeAskUserParams<T>(params: T): T {
  if (!isRecord(params) || !Array.isArray(params.options)) return params;
  if (!params.options.every(isRecord)) return params;
  return {
    ...withoutCarriageReturns(params, ["question"]),
    options: params.options.map((option) => withoutCarriageReturns(option, ["label", "preview"])),
  } as T;
}

export function resultForDialogEvent(
  params: AskUserParams,
  event: DialogEvent,
): AskUserResult {
  const details = { question: params.question, options: params.options };

  if (event.type === "cancelled") {
    return {
      content: [{ type: "text", text: "User cancelled the question." }],
      details: { ...details, answer: null, status: "cancelled" },
    };
  }

  if (event.type === "free-form") {
    return {
      content: [{ type: "text", text: `User wrote: ${event.value}` }],
      details: {
        ...details,
        answer: event.value,
        source: "free-form",
        status: "answered",
      },
    };
  }

  if (event.type === "clarification") {
    return {
      content: [
        {
          type: "text",
          text: `User asked: ${event.value} Answer the question. Pi will then reopen the pending question.`,
        },
      ],
      details: {
        ...details,
        answer: null,
        clarification: event.value,
        status: "clarification",
      },
    };
  }

  const index = event.index + 1;
  const answer = params.options[event.index]!.label;
  return {
    content: [{ type: "text", text: `User selected option ${index}: ${answer}` }],
    details: { ...details, answer, index, source: "option", status: "answered" },
  };
}

export function unavailableResult(params: AskUserParams): AskUserResult {
  return {
    content: [
      {
        type: "text",
        text: "Question UI is unavailable in this mode. Ask the question in normal text.",
      },
    ],
    details: { ...params, answer: null, status: "unavailable" },
  };
}

export async function runAskUser(
  params: AskUserParams,
  ui?: AskUserUi,
): Promise<AskUserResult> {
  if (!ui) return unavailableResult(params);

  const optionChoices = params.options.map((option, index) => `${index + 1}. ${option.label}`);
  const choices = [...optionChoices, FREE_FORM_CHOICE, CLARIFICATION_CHOICE];

  while (true) {
    const choice = await ui.select(params.question, choices);
    if (choice === undefined) {
      return resultForDialogEvent(params, { type: "cancelled" });
    }

    if (choice === FREE_FORM_CHOICE) {
      const answer = (await ui.input("Free-form answer", "Type your answer"))?.trim();
      if (!answer) continue;
      return resultForDialogEvent(params, { type: "free-form", value: answer });
    }

    if (choice === CLARIFICATION_CHOICE) {
      const clarification = (
        await ui.input("Clarifying question", "Ask what you need to know")
      )?.trim();
      if (!clarification) continue;
      return resultForDialogEvent(params, {
        type: "clarification",
        value: clarification,
      });
    }

    const selectedIndex = optionChoices.indexOf(choice);
    if (selectedIndex < 0) continue;
    return resultForDialogEvent(params, { type: "selected", index: selectedIndex });
  }
}
