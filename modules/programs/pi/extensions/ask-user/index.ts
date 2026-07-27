import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import { runAskUser } from "./core.ts";

const AskUserParameters = Type.Object(
  {
    question: Type.String({
      description: "The question shown to the user",
      minLength: 1,
      maxLength: 500,
    }),
    options: Type.Array(
      Type.String({ minLength: 1, maxLength: 120 }),
      {
        description: "Distinct answers the user can select",
        minItems: 2,
        maxItems: 12,
        uniqueItems: true,
      },
    ),
  },
  { additionalProperties: false },
);

export default function askUser(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user",
    label: "Ask User",
    description:
      "Ask the user one question. The user may select an option, write an answer, or ask for clarification.",
    promptSnippet: "Ask the user to answer or clarify one question",
    promptGuidelines: [
      "Use ask_user when progress requires one user decision with a small set of clear answers.",
      "If ask_user returns a clarifying question, answer it before calling ask_user again.",
      "Do not use ask_user when the existing context already determines the answer.",
    ],
    parameters: AskUserParameters,
    executionMode: "sequential",

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const ui = ctx.hasUI
        ? {
            select: (question: string, options: string[]) =>
              ctx.ui.select(question, options, { signal }),
            input: (title: string, placeholder: string) =>
              ctx.ui.input(title, placeholder, { signal }),
          }
        : undefined;
      return runAskUser(params, ui);
    },
  });
}
