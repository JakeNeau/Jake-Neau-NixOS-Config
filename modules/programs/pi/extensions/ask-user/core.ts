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
