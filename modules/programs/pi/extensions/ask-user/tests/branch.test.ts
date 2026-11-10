import assert from "node:assert/strict";
import { test } from "node:test";

import { type BranchEntry, clarificationAwaitsReply, pendingClarification, questionAtLeaf } from "../branch.ts";
import {
  answered,
  answerMessage,
  askUserEntry,
  assistant,
  assistantText,
  clarification,
  question,
  toolResult,
  user,
} from "./entries.ts";

test("a clarification result leaves its question pending", () => {
  assert.deepEqual(pendingClarification([toolResult("t1", clarification), assistant("a1")]), {
    markerId: "t1",
    question,
  });
});

test("a later marker supersedes the clarification", () => {
  assert.equal(pendingClarification([toolResult("t1", clarification), toolResult("t2", answered)]), undefined);
  assert.equal(pendingClarification([toolResult("t1", clarification), answerMessage("m1", answered)]), undefined);
  assert.equal(
    pendingClarification([toolResult("t1", clarification), askUserEntry("e1", { ...question, answer: null, status: "cancelled" })]),
    undefined,
  );
});

test("another clarification in the answer message keeps the question pending", () => {
  assert.deepEqual(pendingClarification([toolResult("t1", clarification), answerMessage("m1", clarification)]), {
    markerId: "m1",
    question,
  });
});

test("an error result without a status is not a marker", () => {
  assert.deepEqual(pendingClarification([toolResult("t1", clarification), toolResult("t2", {})]), {
    markerId: "t1",
    question,
  });
});

test("legacy reopen answers act as markers", () => {
  const legacyAnswer = user("u1", 'My answer to the pending question "Which database should this service use?": SQLite');
  const legacyClarification = user("u1", 'I need another clarification before answering "Which database should this service use?": Why?');
  assert.equal(pendingClarification([toolResult("t1", clarification), legacyAnswer]), undefined);
  assert.deepEqual(pendingClarification([toolResult("t1", clarification), legacyClarification]), {
    markerId: "u1",
    question,
  });
  assert.equal(pendingClarification([legacyClarification]), undefined);
  const stringAnswer: BranchEntry = {
    type: "message",
    id: "u2",
    message: { role: "user", content: 'My answer to the pending question "Which database should this service use?": SQLite' },
  };
  assert.equal(pendingClarification([toolResult("t1", clarification), stringAnswer]), undefined);
});

test("markers from other tools and extensions are ignored", () => {
  assert.deepEqual(
    pendingClarification([
      toolResult("t1", clarification),
      toolResult("t2", answered, "workflow_output"),
      { type: "custom", id: "e1", customType: "workflow-artifact", data: { status: "answered" } },
      { type: "custom_message", id: "m1", customType: "tune-instructions", details: { status: "answered" } },
    ]),
    { markerId: "t1", question },
  );
});

test("a clarification awaits a reply until the assistant writes visible text after it", () => {
  const thinkingOnly: BranchEntry = {
    type: "message",
    id: "a1",
    message: { role: "assistant", stopReason: "toolUse", content: [{ type: "thinking" }, { type: "text", text: " " }] },
  };

  assert.equal(clarificationAwaitsReply([toolResult("t1", clarification)]), true);
  assert.equal(clarificationAwaitsReply([toolResult("t1", clarification), thinkingOnly]), true);
  assert.equal(clarificationAwaitsReply([assistantText("a0", "Earlier."), toolResult("t1", clarification)]), true);
  assert.equal(clarificationAwaitsReply([toolResult("t1", clarification), assistantText("a1", "Yes, it does.")]), false);
  assert.equal(clarificationAwaitsReply([toolResult("t1", answered)]), false);
});

test("the question at the leaf comes from an ask_user result that is the last branch entry", () => {
  assert.deepEqual(questionAtLeaf([toolResult("t1", answered)]), { markerId: "t1", question });
  assert.deepEqual(questionAtLeaf([toolResult("t1", clarification)]), { markerId: "t1", question });
  assert.equal(questionAtLeaf([toolResult("t1", answered), assistant("a1")]), undefined);
  assert.equal(questionAtLeaf([toolResult("t1", {})]), undefined);
  assert.equal(questionAtLeaf([askUserEntry("e1", { ...question, answer: null, status: "cancelled" })]), undefined);
  assert.equal(questionAtLeaf([]), undefined);
});

test("an ordinary user message is not a marker", () => {
  assert.deepEqual(pendingClarification([toolResult("t1", clarification), user("u1", "Go on.")]), {
    markerId: "t1",
    question,
  });
});
