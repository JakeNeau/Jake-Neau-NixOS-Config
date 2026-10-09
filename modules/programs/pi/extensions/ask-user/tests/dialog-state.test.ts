import assert from "node:assert/strict";
import { test } from "node:test";

import {
  activePreview,
  createDialogState,
  reduceDialogState,
} from "../dialog-state.ts";

const options = [
  { label: "Tagged union", preview: "```ts\ntype Result = Ok | Error;\n```" },
  { label: "Nullable value" },
];

test("navigation changes the selected option and preview", () => {
  let state = createDialogState(options.length);
  assert.equal(activePreview(options, state), options[0].preview);

  ({ state } = reduceDialogState(state, { type: "down" }));
  assert.equal(state.selectedIndex, 1);
  assert.equal(activePreview(options, state), undefined);
});

test("preview scrolling moves by lines and clamps at zero", () => {
  let state = createDialogState(options.length);
  assert.equal(state.previewOffset, 0);

  ({ state } = reduceDialogState(state, { type: "scroll-preview", delta: 1 }));
  assert.equal(state.previewOffset, 1);

  ({ state } = reduceDialogState(state, { type: "scroll-preview", delta: -2 }));
  assert.equal(state.previewOffset, 0);
});

test("navigation resets preview scrolling only after a row change", () => {
  let state = {
    ...createDialogState(options.length),
    previewOffset: 7,
  };

  ({ state } = reduceDialogState(state, { type: "up" }));
  assert.equal(state.previewOffset, 7);

  ({ state } = reduceDialogState(state, { type: "down" }));
  assert.equal(state.selectedIndex, 1);
  assert.equal(state.previewOffset, 0);

  state = { ...state, selectedIndex: options.length + 1, previewOffset: 5 };
  ({ state } = reduceDialogState(state, { type: "down" }));
  assert.equal(state.previewOffset, 5);
});

test("ordinary menu transitions preserve the preview offset", () => {
  const state = {
    ...createDialogState(options.length),
    previewOffset: 4,
  };

  assert.equal(reduceDialogState(state, { type: "input", value: "ignored" }).state.previewOffset, 4);
  assert.equal(reduceDialogState(state, { type: "enter" }).state.previewOffset, 4);
});

test("free-form input replaces only its action row until submission", () => {
  let state = createDialogState(options.length);
  state = { ...state, selectedIndex: options.length };

  ({ state } = reduceDialogState(state, { type: "enter" }));
  assert.equal(state.mode, "free-form");

  ({ state } = reduceDialogState(state, { type: "input", value: "Use both." }));
  assert.equal(state.input, "Use both.");
  assert.equal(state.selectedIndex, options.length);
  assert.equal(activePreview(options, state), undefined);

  const result = reduceDialogState(state, { type: "enter" });
  assert.deepEqual(result.event, { type: "free-form", value: "Use both." });
});

test("clarification input submits a clarifying question", () => {
  let state = { ...createDialogState(options.length), selectedIndex: options.length + 1 };
  ({ state } = reduceDialogState(state, { type: "enter" }));
  ({ state } = reduceDialogState(state, { type: "input", value: "Which is safer?" }));

  assert.deepEqual(reduceDialogState(state, { type: "enter" }).event, {
    type: "clarification",
    value: "Which is safer?",
  });
});

test("escape and empty enter restore the action label", () => {
  let state = { ...createDialogState(options.length), selectedIndex: options.length };
  ({ state } = reduceDialogState(state, { type: "enter" }));
  ({ state } = reduceDialogState(state, { type: "input", value: "discard me" }));
  ({ state } = reduceDialogState(state, { type: "escape" }));
  assert.equal(state.mode, "menu");
  assert.equal(state.input, "");

  ({ state } = reduceDialogState(state, { type: "enter" }));
  ({ state } = reduceDialogState(state, { type: "input", value: "   " }));
  ({ state } = reduceDialogState(state, { type: "enter" }));
  assert.equal(state.mode, "menu");
  assert.equal(state.input, "");
});

test("menu enter selects an option and menu escape cancels", () => {
  const state = { ...createDialogState(options.length), selectedIndex: 1 };
  assert.deepEqual(reduceDialogState(state, { type: "enter" }).event, {
    type: "selected",
    index: 1,
  });
  assert.deepEqual(reduceDialogState(state, { type: "escape" }).event, {
    type: "cancelled",
  });
});

test("arrow keys do not move the selected row while editing", () => {
  let state = { ...createDialogState(options.length), selectedIndex: options.length };
  ({ state } = reduceDialogState(state, { type: "enter" }));
  const before = state;
  ({ state } = reduceDialogState(state, { type: "up" }));
  assert.deepEqual(state, before);
});
