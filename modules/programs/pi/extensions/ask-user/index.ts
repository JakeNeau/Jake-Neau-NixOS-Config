import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import {
  type AskUserParams,
  type AskUserResult,
  resultForDialogEvent,
  runAskUser,
  unavailableResult,
} from "./core.ts";
import { runAskUserTui } from "./dialog.ts";
import { PendingQuestion } from "./pending-question.ts";

const AskUserOption = Type.Object(
  {
    label: Type.String({
      description: "The answer label shown to the user",
      minLength: 1,
      maxLength: 120,
    }),
    preview: Type.Optional(
      Type.String({
        description:
          "Optional Markdown preview. Include only when concrete context materially helps compare this option.",
        minLength: 1,
        maxLength: 4000,
      }),
    ),
  },
  { additionalProperties: false },
);

const AskUserParameters = Type.Object(
  {
    question: Type.String({
      description: "The question shown to the user",
      minLength: 1,
      maxLength: 500,
    }),
    options: Type.Array(AskUserOption, {
      description: "Distinct answers the user can select",
      minItems: 2,
      maxItems: 12,
      uniqueItems: true,
    }),
  },
  { additionalProperties: false },
);

async function ask(
  params: AskUserParams,
  ctx: ExtensionContext,
  signal?: AbortSignal,
): Promise<AskUserResult> {
  if (ctx.mode === "tui") {
    const event = await runAskUserTui(params, ctx, signal);
    return resultForDialogEvent(params, event);
  }

  if (!ctx.hasUI) return unavailableResult(params);

  return runAskUser(params, {
    select: (question, options) => ctx.ui.select(question, options, { signal }),
    input: (title, placeholder) => ctx.ui.input(title, placeholder, { signal }),
  });
}

function repeatedAnswerMessage(result: AskUserResult): string | undefined {
  const { details } = result;
  if (details.status === "answered" && details.answer) {
    return `My answer to the pending question "${details.question}": ${details.answer}`;
  }
  if (details.status === "clarification" && details.clarification) {
    return `I need another clarification before answering "${details.question}": ${details.clarification}`;
  }
  return undefined;
}

export default function askUser(pi: ExtensionAPI) {
  const pending = new PendingQuestion();

  pi.registerTool({
    name: "ask_user",
    label: "Ask User",
    description:
      "Ask the user one question. Each option has a label and may include a Markdown preview when concrete context materially helps comparison.",
    promptSnippet: "Ask the user to answer or clarify one question",
    promptGuidelines: [
      "Use ask_user when progress requires one user decision with a small set of clear answers.",
      "Omit option previews by default. Add one only when code, commands, configuration, or another concrete example materially helps comparison.",
      "Do not use a preview to repeat its label, add generic explanation, or restate the question.",
      "Answer a clarifying question directly. The extension will then reopen the pending question.",
      "Do not use ask_user when the existing context already determines the answer.",
    ],
    parameters: AskUserParameters,
    executionMode: "sequential",

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      pending.beginToolCall();
      const question = params as AskUserParams;
      const result = await ask(question, ctx, signal);
      pending.finishToolCall(question, result.details.status);
      return result;
    },
  });

  pi.on("agent_settled", async (_event, ctx) => {
    const question = pending.beginReopen();
    if (!question) return;

    try {
      const result = await ask(question, ctx);
      pending.finishReopen(result.details.status);

      const message = repeatedAnswerMessage(result);
      if (message) pi.sendUserMessage(message);
    } catch (error) {
      pending.releaseReopen();
      throw error;
    }
  });

  pi.on("session_start", () => pending.reset());
  pi.on("session_shutdown", () => pending.reset());
}
