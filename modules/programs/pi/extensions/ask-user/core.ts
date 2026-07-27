export const FREE_FORM_CHOICE = "Type a free-form answer...";
export const CLARIFICATION_CHOICE = "Ask a clarifying question...";

export interface AskUserParams {
  question: string;
  options: string[];
}

export interface AskUserDetails {
  question: string;
  options: string[];
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

type AskUserResult = {
  content: Array<{ type: "text"; text: string }>;
  details: AskUserDetails;
};

export async function runAskUser(
  params: AskUserParams,
  ui?: AskUserUi,
): Promise<AskUserResult> {
  const details = {
    question: params.question,
    options: params.options,
  };

  if (!ui) {
    return {
      content: [
        {
          type: "text",
          text: "Question UI is unavailable in this mode. Ask the question in normal text.",
        },
      ],
      details: { ...details, answer: null, status: "unavailable" },
    };
  }

  const optionChoices = params.options.map((option, index) => `${index + 1}. ${option}`);
  const choices = [...optionChoices, FREE_FORM_CHOICE, CLARIFICATION_CHOICE];

  while (true) {
    const choice = await ui.select(params.question, choices);
    if (choice === undefined) {
      return {
        content: [{ type: "text", text: "User cancelled the question." }],
        details: { ...details, answer: null, status: "cancelled" },
      };
    }

    if (choice === FREE_FORM_CHOICE) {
      const answer = (await ui.input("Free-form answer", "Type your answer"))?.trim();
      if (!answer) continue;

      return {
        content: [{ type: "text", text: `User wrote: ${answer}` }],
        details: { ...details, answer, source: "free-form", status: "answered" },
      };
    }

    if (choice === CLARIFICATION_CHOICE) {
      const clarification = (
        await ui.input("Clarifying question", "Ask what you need to know")
      )?.trim();
      if (!clarification) continue;

      return {
        content: [
          {
            type: "text",
            text: `User asked: ${clarification} Answer the question, then call ask_user again.`,
          },
        ],
        details: {
          ...details,
          answer: null,
          clarification,
          status: "clarification",
        },
      };
    }

    const selectedIndex = optionChoices.indexOf(choice);
    if (selectedIndex < 0) continue;

    const index = selectedIndex + 1;
    const answer = params.options[selectedIndex];
    return {
      content: [{ type: "text", text: `User selected option ${index}: ${answer}` }],
      details: { ...details, answer, index, source: "option", status: "answered" },
    };
  }
}
