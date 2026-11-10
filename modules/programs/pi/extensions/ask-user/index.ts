import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

import {
  ANSWER_MESSAGE_TYPE,
  answerRunEndedEarly,
  clarificationAwaitsReply,
  ENTRY_TYPE,
  type MarkedQuestion,
  pendingClarification,
  questionAtLeaf,
} from "./branch.ts";
import {
  type AskUserDetails,
  type AskUserParams,
  type AskUserResult,
  normalizeAskUserParams,
  resultForDialogEvent,
  runAskUser,
  unavailableResult,
} from "./core.ts";
import { runAskUserTui } from "./dialog.ts";

const REPLY_FIRST =
  "Reply to the user's clarifying question in visible text and end your turn. Pi reopens the pending question after your reply.";

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

function answerContent(details: AskUserDetails, { revised }: { revised: boolean }): string | undefined {
  // JSON quoting keeps quotes inside the question unambiguous.
  const question = JSON.stringify(details.question);
  if (details.status === "answered" && details.answer) {
    const label = revised ? "Revised answer to the question" : "Answer to the pending question";
    return `${label} ${question}: ${details.answer}`;
  }
  if (details.status === "clarification" && details.clarification) {
    return `Clarifying question before answering ${question}: ${details.clarification}`;
  }
  return undefined;
}

// Uses the wording of the tool's own result text.
function answerLine(details: AskUserDetails): string {
  if (details.status === "clarification") return `User asked: ${details.clarification}`;
  if (details.source === "free-form") return `User wrote: ${details.answer}`;
  return `User selected option ${details.index}: ${details.answer}`;
}

export default function askUser(pi: ExtensionAPI) {
  // Another extension's run can settle before the answer is saved, so one reopen must not repeat.
  let reopenedMarkerId: string | undefined;
  // Pi does not set aborted when Escape cancels an auto-compaction.
  let compactionCancelled = false;
  // Pi copies a reopened answer into the editor when /tree targets it.
  let answerReturnedToEditor: string | undefined;

  async function reopen(marked: MarkedQuestion, ctx: ExtensionContext, { revised }: { revised: boolean }) {
    reopenedMarkerId = marked.markerId;
    const { details } = await ask(marked.question, ctx);
    const content = answerContent(details, { revised });
    if (content) {
      pi.sendMessage({ customType: ANSWER_MESSAGE_TYPE, content, display: true, details }, { triggerTurn: true });
    } else if (!revised) {
      // A cancelled or unavailable reopen is recorded so /tree does not bring the question back.
      pi.appendEntry(ENTRY_TYPE, details);
    }
  }

  async function reopenAfterTree(ctx: ExtensionContext) {
    const editorAnswer = answerReturnedToEditor;
    answerReturnedToEditor = undefined;
    if (!ctx.hasUI || !ctx.isIdle()) return;
    const branch = ctx.sessionManager.getBranch();
    const pending = pendingClarification(branch);
    const marked = pending ?? questionAtLeaf(branch);
    if (!marked || marked.markerId === reopenedMarkerId) return;
    // The dialog replaces the old answer, and a submitted editor would send it as a prompt.
    if (editorAnswer !== undefined && ctx.ui.getEditorText() === editorAnswer) ctx.ui.setEditorText("");
    await reopen(marked, ctx, { revised: !pending });
  }

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
      "When the user asks a clarifying question, reply to it in visible text and end your turn. Pi then reopens the pending question, so do not call ask_user to repeat it.",
      "Do not use ask_user when the existing context already determines the answer.",
    ],
    parameters: AskUserParameters,
    prepareArguments: (args) => normalizeAskUserParams(args) as AskUserParams,
    // Codemode scripts would receive the clarification text that the model never sees.
    exposure: "model-only",
    executionMode: "sequential",

    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      // Without this, the model can answer only in thinking and ask again, so the user never sees the reply.
      if (clarificationAwaitsReply(ctx.sessionManager.getBranch())) throw new Error(REPLY_FIRST);
      return ask(params as AskUserParams, ctx, signal);
    },
  });

  pi.registerMessageRenderer<AskUserDetails>(ANSWER_MESSAGE_TYPE, (message, options) =>
    new Text(answerLine(message.details!), options.outputPad, 0)
  );

  pi.on("session_compact_failed", (event) => {
    // A manual /compact aborts the run first, and one cancelled while idle must keep the question.
    if (event.aborted && event.reason !== "manual") compactionCancelled = true;
  });

  pi.on("session_before_tree", (event, ctx) => {
    const target = ctx.sessionManager.getEntry(event.preparation.targetId);
    const isAnswer = target?.type === "custom_message" && target.customType === ANSWER_MESSAGE_TYPE;
    answerReturnedToEditor = isAnswer && typeof target.content === "string" ? target.content : undefined;
  });

  pi.on("session_tree", (_event, ctx) => {
    // Returning to the same clarification through /tree must reopen it.
    reopenedMarkerId = undefined;
    // Pi awaits this handler and redraws the chat and editor only afterward.
    setTimeout(() => void reopenAfterTree(ctx), 0);
  });

  pi.on("agent_settled", async (event, ctx) => {
    const cancelled = event.aborted || compactionCancelled;
    compactionCancelled = false;
    const branch = ctx.sessionManager.getBranch();
    const pending = pendingClarification(branch);
    if (pending?.markerId !== reopenedMarkerId) reopenedMarkerId = undefined;
    // Returns before the cancel below, so an aborted queued run cannot drop an in-flight reopen.
    if (!pending || reopenedMarkerId) return;

    // The agent never finished answering the clarification, so a reopen would lack that answer.
    if (cancelled || answerRunEndedEarly(branch)) {
      pi.appendEntry(ENTRY_TYPE, resultForDialogEvent(pending.question, { type: "cancelled" }).details);
      return;
    }

    await reopen(pending, ctx, { revised: false });
  });
}
