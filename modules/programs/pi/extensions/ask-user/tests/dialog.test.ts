import assert from "node:assert/strict";
import { test } from "node:test";

import {
  getMarkdownTheme,
  initTheme,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Markdown,
  stripTerminalSequences,
  type TUI,
  visibleWidth,
} from "@earendil-works/pi-tui";

import { AskUserDialog } from "../dialog.ts";
import type { DialogEvent } from "../dialog-state.ts";

const SCROLL_DOWN = "\x1b\n";
const SCROLL_DOWN_REPEAT = "\x1b[106;7:2u";
const SCROLL_UP = "\x1b\x0b";

initTheme();

function createDialog(options: Array<{ label: string; preview?: string }>) {
  let renderRequests = 0;
  const events: DialogEvent[] = [];
  const tui = {
    requestRender: () => {
      renderRequests += 1;
    },
  } as unknown as TUI;
  const theme = {
    fg: (_color: string, text: string) => text,
    bg: (_color: string, text: string) => text,
  } as unknown as Theme;
  const dialog = new AskUserDialog(
    { question: "Choose one.", options },
    tui,
    theme,
    (event) => events.push(event),
  );

  return {
    dialog,
    events,
    renderRequests: () => renderRequests,
  };
}

function plain(lines: string[]): string[] {
  return lines.map((line) => stripTerminalSequences(line));
}

function previewContent(lines: string[]): string[] {
  const rendered = plain(lines);
  const top = rendered.findIndex((line) => line.startsWith("┌─ Preview "));
  if (top < 0) return [];
  const bottom = rendered.findIndex((line, index) => index > top && line.startsWith("└"));
  assert.ok(bottom > top);
  return rendered.slice(top + 1, bottom);
}

function codePreview(prefix: string, lineCount = 28): string {
  const lines = Array.from(
    { length: lineCount },
    (_, index) => `${prefix}-${String(index + 1).padStart(2, "0")}`,
  );
  return `\`\`\`text\n${lines.join("\n")}\n\`\`\``;
}

test("short previews render without scrolling controls or markers", () => {
  const { dialog } = createDialog([
    { label: "First", preview: "**Compact** preview." },
    { label: "Second" },
  ]);
  const rendered = plain(dialog.render(60));

  assert.ok(rendered.some((line) => line.includes("Compact")));
  assert.ok(!rendered.some((line) => line.includes("scroll preview")));
  assert.ok(!rendered.some((line) => line.includes("preview truncated")));
  assert.ok(!rendered.some((line) => line.includes("┃")));
  assert.ok(previewContent(rendered).length <= 16);
});

test("long previews scroll through every line and move the scrollbar", () => {
  const { dialog, renderRequests } = createDialog([
    { label: "First", preview: codePreview("line") },
    { label: "Second" },
  ]);
  const initial = plain(dialog.render(52));
  const initialPanel = previewContent(initial);
  const initialThumb = initialPanel.findIndex((line) => line.includes("┃"));

  assert.ok(initial.some((line) => line.includes("ctrl+alt+j/k scroll preview")));
  assert.ok(initialPanel.some((line) => line.includes("line-01")));
  assert.ok(!initialPanel.some((line) => line.includes("line-28")));
  assert.equal(initialPanel.length, 16);
  assert.ok(initialThumb >= 0);

  const reached = new Set(
    initialPanel.flatMap((line) => line.match(/line-\d{2}/g) ?? []),
  );
  let bottom = initialPanel;
  for (let index = 0; index < 80; index++) {
    dialog.handleInput(SCROLL_DOWN);
    bottom = previewContent(dialog.render(52));
    for (const line of bottom) {
      for (const marker of line.match(/line-\d{2}/g) ?? []) reached.add(marker);
    }
  }
  const bottomThumb = bottom.findIndex((line) => line.includes("┃"));
  assert.ok(bottom.some((line) => line.includes("line-28")));
  assert.equal(reached.size, 28);
  assert.ok(bottomThumb > initialThumb);
  assert.equal(renderRequests(), 80);

  const boundedBottom = previewContent(dialog.render(52));
  dialog.handleInput(SCROLL_DOWN);
  assert.deepEqual(previewContent(dialog.render(52)), boundedBottom);

  dialog.handleInput(SCROLL_UP);
  assert.notDeepEqual(previewContent(dialog.render(52)), boundedBottom);

  for (let index = 0; index < 80; index++) dialog.handleInput(SCROLL_UP);
  assert.deepEqual(previewContent(dialog.render(52)), initialPanel);
});

test("repeated scroll keys apply one row per event", () => {
  const options = [
    { label: "First", preview: codePreview("repeat") },
    { label: "Second" },
  ];
  const once = createDialog(options).dialog;
  const twice = createDialog(options).dialog;
  once.render(52);
  twice.render(52);

  once.handleInput(SCROLL_DOWN);
  twice.handleInput(SCROLL_DOWN);
  twice.handleInput(SCROLL_DOWN_REPEAT);

  assert.notDeepEqual(previewContent(once.render(52)), previewContent(twice.render(52)));
});

test("changing options resets the preview to its first row", () => {
  const { dialog } = createDialog([
    { label: "First", preview: codePreview("first") },
    { label: "Second", preview: codePreview("second") },
  ]);
  dialog.render(52);
  for (let index = 0; index < 12; index++) dialog.handleInput(SCROLL_DOWN);
  assert.ok(!previewContent(dialog.render(52)).some((line) => line.includes("first-01")));

  dialog.handleInput("\x1b[B");
  const second = previewContent(dialog.render(52));
  assert.ok(second.some((line) => line.includes("second-01")));
  assert.ok(!second.some((line) => line.includes("second-28")));
});

test("resize reflow clamps the offset and restores overflow from the top", () => {
  const preview = `START ${"word ".repeat(110)} END`;
  const { dialog } = createDialog([
    { label: "First", preview },
    { label: "Second" },
  ]);

  const narrow = plain(dialog.render(24));
  assert.ok(narrow.some((line) => line.includes("ctrl+alt+j/k")));
  for (let index = 0; index < 80; index++) dialog.handleInput(SCROLL_DOWN);
  assert.ok(previewContent(dialog.render(24)).some((line) => line.includes("END")));

  const wide = plain(dialog.render(100));
  assert.ok(!wide.some((line) => line.includes("ctrl+alt+j/k")));
  assert.ok(previewContent(wide).some((line) => line.includes("START")));

  const narrowAgain = plain(dialog.render(24));
  assert.ok(narrowAgain.some((line) => line.includes("ctrl+alt+j/k")));
  assert.ok(previewContent(narrowAgain).some((line) => line.includes("START")));
});

test("overflow layout reserves the scrollbar column before wrapping", () => {
  const width = 32;
  const contentWidth = width - 4;
  let preview = "";
  let fullLines: string[] = [];
  let reservedLines: string[] = [];

  for (let words = 40; words < 400; words++) {
    preview = `${"wrap ".repeat(words)}END`;
    fullLines = new Markdown(preview, 0, 0, getMarkdownTheme()).render(contentWidth);
    reservedLines = new Markdown(preview, 0, 0, getMarkdownTheme()).render(contentWidth - 1);
    if (fullLines.length > 16 && reservedLines.length > fullLines.length) break;
  }

  assert.ok(fullLines.length > 16);
  assert.ok(reservedLines.length > fullLines.length);

  const { dialog } = createDialog([
    { label: "First", preview },
    { label: "Second" },
  ]);
  dialog.render(width);
  for (let index = 0; index < 200; index++) dialog.handleInput(SCROLL_DOWN);
  const rendered = dialog.render(width);

  assert.ok(previewContent(rendered).some((line) => line.includes("END")));
  assert.ok(rendered.every((line) => visibleWidth(line) <= width));
});

test("preview keys are routed only for overflowing menu previews", () => {
  const long = createDialog([
    { label: "First", preview: codePreview("route") },
    { label: "Second" },
  ]);
  long.dialog.handleInput(SCROLL_DOWN);
  assert.equal(long.renderRequests(), 0);
  long.dialog.render(52);
  long.dialog.handleInput(SCROLL_DOWN);
  assert.equal(long.renderRequests(), 1);
  long.dialog.handleInput("\x1b[B");
  long.dialog.handleInput("\r");
  assert.deepEqual(long.events, [{ type: "selected", index: 1 }]);

  const short = createDialog([
    { label: "First", preview: "Short." },
    { label: "Second" },
  ]);
  short.dialog.render(52);
  short.dialog.handleInput(SCROLL_DOWN);
  assert.equal(short.renderRequests(), 0);

  const editing = createDialog([
    { label: "First", preview: codePreview("edit") },
    { label: "Second" },
  ]);
  editing.dialog.render(52);
  editing.dialog.handleInput("\x1b[B");
  editing.dialog.handleInput("\x1b[B");
  editing.dialog.handleInput("\r");
  editing.dialog.handleInput("A free answer");
  editing.dialog.handleInput("\r");
  assert.deepEqual(editing.events, [{ type: "free-form", value: "A free answer" }]);
});

test("narrow renders stay within the terminal width", () => {
  const { dialog } = createDialog([
    { label: "First", preview: codePreview("narrow") },
    { label: "Second" },
  ]);

  dialog.render(32);
  for (let index = 0; index < 12; index++) dialog.handleInput(SCROLL_DOWN);
  assert.ok(!previewContent(dialog.render(32)).some((line) => line.includes("narrow-01")));

  for (let width = 1; width < 8; width++) {
    const rendered = dialog.render(width);
    assert.ok(rendered.every((line) => visibleWidth(line) <= width));
    assert.ok(!plain(rendered).some((line) => line.includes("ctrl+alt+j/k")));
  }

  assert.ok(previewContent(dialog.render(32)).some((line) => line.includes("narrow-01")));
});
