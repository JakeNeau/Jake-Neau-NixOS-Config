import assert from "node:assert/strict";
import { test } from "node:test";

import {
  CLARIFICATION_CHOICE,
  FREE_FORM_CHOICE,
  runAskUser,
} from "../core.ts";

const question = {
  question: "Which database should this service use?",
  options: [
    { label: "PostgreSQL", preview: "```sql\nSELECT 1;\n```" },
    { label: "SQLite" },
    { label: "None" },
  ],
};

const menu = [
  "1. PostgreSQL",
  "2. SQLite",
  "3. None",
  FREE_FORM_CHOICE,
  CLARIFICATION_CHOICE,
];

test("returns the selected option and its one-based index", async () => {
  const calls: Array<{ prompt: string; options: string[] }> = [];
  const result = await runAskUser(question, {
    select: async (prompt, options) => {
      calls.push({ prompt, options });
      return "2. SQLite";
    },
    input: async () => undefined,
  });

  assert.deepEqual(calls, [{ prompt: question.question, options: menu }]);
  assert.deepEqual(result, {
    content: [{ type: "text", text: "User selected option 2: SQLite" }],
    details: {
      question: question.question,
      options: question.options,
      answer: "SQLite",
      index: 2,
      source: "option",
      status: "answered",
    },
  });
});

test("returns a free-form answer", async () => {
  const result = await runAskUser(question, {
    select: async (_prompt, options) => {
      assert.deepEqual(options, menu);
      return FREE_FORM_CHOICE;
    },
    input: async (title, placeholder) => {
      assert.equal(title, "Free-form answer");
      assert.equal(placeholder, "Type your answer");
      return "Use whichever is simplest.";
    },
  });

  assert.deepEqual(result, {
    content: [{ type: "text", text: "User wrote: Use whichever is simplest." }],
    details: {
      question: question.question,
      options: question.options,
      answer: "Use whichever is simplest.",
      source: "free-form",
      status: "answered",
    },
  });
});

test("returns a clarifying question and directs the agent to ask again", async () => {
  const result = await runAskUser(question, {
    select: async (_prompt, options) => {
      assert.deepEqual(options, menu);
      return CLARIFICATION_CHOICE;
    },
    input: async (title, placeholder) => {
      assert.equal(title, "Clarifying question");
      assert.equal(placeholder, "Ask what you need to know");
      return "Does this service need concurrent writes?";
    },
  });

  assert.deepEqual(result, {
    content: [
      {
        type: "text",
        text: "User asked: Does this service need concurrent writes? Answer the question. Pi will then reopen the pending question.",
      },
    ],
    details: {
      question: question.question,
      options: question.options,
      answer: null,
      clarification: "Does this service need concurrent writes?",
      status: "clarification",
    },
  });
});

test("returns to the answer menu when text input is cancelled", async () => {
  let selections = 0;
  const result = await runAskUser(question, {
    select: async () => {
      selections += 1;
      return selections === 1 ? FREE_FORM_CHOICE : "1. PostgreSQL";
    },
    input: async () => undefined,
  });

  assert.equal(selections, 2);
  assert.equal(result.details.answer, "PostgreSQL");
  assert.deepEqual(result.details.options, question.options);
});

test("reports cancellation without inventing an answer", async () => {
  const result = await runAskUser(question, {
    select: async () => undefined,
    input: async () => undefined,
  });

  assert.deepEqual(result, {
    content: [{ type: "text", text: "User cancelled the question." }],
    details: {
      question: question.question,
      options: question.options,
      answer: null,
      status: "cancelled",
    },
  });
});

test("directs the agent to plain text when interactive UI is unavailable", async () => {
  const result = await runAskUser(question);

  assert.deepEqual(result, {
    content: [
      {
        type: "text",
        text: "Question UI is unavailable in this mode. Ask the question in normal text.",
      },
    ],
    details: {
      question: question.question,
      options: question.options,
      answer: null,
      status: "unavailable",
    },
  });
});
