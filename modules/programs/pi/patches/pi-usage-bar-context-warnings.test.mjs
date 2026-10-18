import assert from "node:assert/strict";
import { test } from "node:test";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const source = process.env.PI_USAGE_BAR_SOURCE;
if (!source) throw new Error("PI_USAGE_BAR_SOURCE is required");

const { contextSegment } = await import(
  pathToFileURL(join(source, "src/context-level.ts")).href
);
const { formatTokens, progressBar } = await import(
  pathToFileURL(join(source, "src/format.ts")).href
);

const fg = (color, text) => `<${color}>${text}</${color}>`;
const config = { warningThreshold: 20, errorThreshold: 50 };
const contextWindow = 200000;
const window = `(${formatTokens(contextWindow)})`;

function segment(percent) {
  return contextSegment({ percent, contextWindow }, config, fg);
}

test("context below the warning threshold is green without text", () => {
  assert.equal(segment(10), `<success>${progressBar(10, 10)} 10% ${window}</success>`);
});

test("context from the warning threshold suggests a new session", () => {
  for (const [percent, label] of [
    [20, "20%"],
    [49, "49%"],
    [49.6, "50%"],
  ]) {
    assert.equal(
      segment(percent),
      `<warning>${progressBar(percent, 10)} ${label} ${window} consider new session</warning>`,
    );
  }
});

test("context from the error threshold requires a new session", () => {
  assert.equal(
    segment(50),
    `<error>${progressBar(50, 10)} 50% ${window} start new session</error>`,
  );
});

test("unknown usage stays muted without text", () => {
  assert.equal(segment(null), `<muted>${progressBar(null, 10)} —% ${window}</muted>`);
  assert.equal(
    contextSegment(undefined, config, fg),
    `<muted>${progressBar(null, 10)} —</muted>`,
  );
});
