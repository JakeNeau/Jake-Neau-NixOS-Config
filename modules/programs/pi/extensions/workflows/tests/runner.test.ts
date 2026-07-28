import assert from "node:assert/strict";
import { test } from "node:test";

import { StrictJsonlDecoder, buildChildArguments, isSafeReadOnlyCommand } from "../runner.ts";

test("decodes fragmented LF-delimited RPC records without treating Unicode separators as framing", () => {
  const decoder = new StrictJsonlDecoder();
  assert.deepEqual(decoder.push(Buffer.from('{"type":"one","text":"a\u2028b"}\n{"type":')), [
    { type: "one", text: "a b" },
  ]);
  assert.deepEqual(decoder.push(Buffer.from('"two"}\r\n')), [{ type: "two" }]);
  assert.deepEqual(decoder.finish(), []);
});

test("builds a child invocation that inherits model and thinking", () => {
  assert.deepEqual(buildChildArguments({
    provider: "openai-codex",
    model: "gpt-5.6",
    thinking: "high",
    tools: ["read", "workflow_output"],
    trusted: true,
  }), [
    "--mode", "rpc", "--no-session", "--model", "openai-codex/gpt-5.6",
    "--thinking", "high", "--tools", "read,workflow_output", "--approve",
  ]);
});

test("allows conservative inspection commands and blocks mutation", () => {
  assert.equal(isSafeReadOnlyCommand("git diff -- specs/design.md"), true);
  assert.equal(isSafeReadOnlyCommand("rg -n workflow specs"), true);
  assert.equal(isSafeReadOnlyCommand("git commit -am nope"), false);
  assert.equal(isSafeReadOnlyCommand("cat a > b"), false);
  assert.equal(isSafeReadOnlyCommand("rm -rf specs"), false);
});
