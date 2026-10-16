import assert from "node:assert/strict";
import { test } from "node:test";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const source = process.env.PI_SOURCE;
if (!source) throw new Error("PI_SOURCE is required");

const interactive = await import(
  pathToFileURL(join(source, "dist/modes/interactive/interactive-mode.js")).href
);
const assistantModule = await import(
  pathToFileURL(join(source, "dist/modes/interactive/components/assistant-message.js")).href
);
const customEntryModule = await import(
  pathToFileURL(join(source, "dist/modes/interactive/components/custom-entry.js")).href
);
const userModule = await import(
  pathToFileURL(join(source, "dist/modes/interactive/components/user-message.js")).href
);
const { Container, Text } = await import(
  pathToFileURL(join(source, "node_modules/@earendil-works/pi-tui/dist/index.js")).href
);

const { InteractiveMode, TranscriptContainer } = interactive;
const { AssistantMessageComponent } = assistantModule;
const { CustomEntryComponent } = customEntryModule;
const { UserMessageComponent } = userModule;

function assistant(content, stopReason = "stop") {
  return {
    role: "assistant",
    content,
    stopReason,
  };
}

function customEntry(customType) {
  return new CustomEntryComponent(
    { type: "custom", id: customType, customType, data: {}, timestamp: new Date().toISOString() },
    () => new Text(customType, 0, 0),
  );
}

test("switches historical components between minimal and full transcripts", () => {
  const transcript = new TranscriptContainer(true);
  const user = new UserMessageComponent("prompt");
  const finalAnswer = new AssistantMessageComponent(
    assistant([
      { type: "thinking", thinking: "hidden reasoning" },
      { type: "text", text: "answer" },
    ]),
    false,
    undefined,
    undefined,
    undefined,
    undefined,
    true,
  );
  const intermediate = new AssistantMessageComponent(
    assistant([{ type: "toolCall", id: "call", name: "read", arguments: {} }]),
    false,
    undefined,
    undefined,
    undefined,
    undefined,
    true,
  );
  const tool = new Text("tool output", 0, 0);
  const diff = customEntry("minimal-transcript-diff");
  const review = customEntry("workflow-review");
  const custom = customEntry("workflow-artifact");

  for (const component of [user, finalAnswer, intermediate, tool, diff, review, custom]) {
    transcript.addChild(component);
  }

  assert.deepEqual(transcript.children, [user, finalAnswer, diff, review]);
  const minimalAnswerChildren = finalAnswer.contentContainer.children.length;

  transcript.setMinimalTranscript(false);
  assert.deepEqual(transcript.children, [user, finalAnswer, intermediate, tool, review, custom]);
  assert.ok(finalAnswer.contentContainer.children.length > minimalAnswerChildren);

  transcript.setMinimalTranscript(true);
  assert.deepEqual(transcript.children, [user, finalAnswer, diff, review]);
});

function chromeHarness(minimalTranscript) {
  const mode = Object.create(InteractiveMode.prototype);
  mode.minimalTranscript = minimalTranscript;
  mode.documentContainer = new Container();
  mode.headerContainer = new Container();
  mode.loadedResourcesContainer = new Container();
  mode.chatContainer = new TranscriptContainer(minimalTranscript);
  mode.footerContainer = new Container();
  mode.footerContentContainer = new Container();
  mode.footer = new Text("built-in footer", 0, 0);
  mode.footerContentContainer.addChild(mode.footer);
  mode.footerDataProvider = {};
  mode.statusContainer = new Container();
  mode.statusContentContainer = new Container();
  mode.activeStatusIndicator = undefined;
  mode.setEditorWorkingStatusIndicator = () => false;
  mode.ui = { requestRender() {} };
  return mode;
}

test("minimal chrome preserves the footer and transient status content", () => {
  const minimal = chromeHarness(true);
  minimal.syncTranscriptChrome();
  assert.deepEqual(minimal.documentContainer.children, [minimal.chatContainer]);
  assert.deepEqual(minimal.footerContainer.children, [minimal.footerContentContainer]);
  assert.deepEqual(minimal.footerContainer.render(80), ["built-in footer".padEnd(80)]);
  assert.deepEqual(minimal.statusContainer.children, [minimal.statusContentContainer]);

  const full = chromeHarness(false);
  full.syncTranscriptChrome();
  assert.deepEqual(full.documentContainer.children, [
    full.headerContainer,
    full.loadedResourcesContainer,
    full.chatContainer,
  ]);
  assert.deepEqual(full.footerContainer.children, [full.footerContentContainer]);
  assert.deepEqual(full.statusContainer.children, [full.statusContentContainer]);
});

test("keeps custom and restored footers visible across transcript toggles", () => {
  const previous = process.env.PI_MINIMAL_TRANSCRIPT;
  process.env.PI_MINIMAL_TRANSCRIPT = "1";
  try {
    const mode = chromeHarness(true);
    mode.syncTranscriptChrome();
    let disposed = 0;
    const customFooter = new Text("usage bar", 0, 0);
    customFooter.dispose = () => disposed++;

    mode.setExtensionFooter((_ui, _theme, data) => {
      assert.equal(data, mode.footerDataProvider);
      return customFooter;
    });
    assert.deepEqual(mode.footerContainer.render(80), ["usage bar".padEnd(80)]);

    for (const minimal of [false, true, false, true]) {
      mode.setMinimalTranscript(minimal);
      assert.deepEqual(mode.footerContainer.children, [mode.footerContentContainer]);
      assert.deepEqual(mode.footerContainer.render(80), ["usage bar".padEnd(80)]);
      assert.equal(disposed, 0);
    }

    mode.setExtensionFooter(undefined);
    assert.equal(disposed, 1);
    assert.deepEqual(mode.footerContainer.render(80), ["built-in footer".padEnd(80)]);
  } finally {
    if (previous === undefined) delete process.env.PI_MINIMAL_TRANSCRIPT;
    else process.env.PI_MINIMAL_TRANSCRIPT = previous;
  }
});

test("preserves a streaming component across mode changes", () => {
  const transcript = new TranscriptContainer(true);
  const streaming = new AssistantMessageComponent(undefined, false, undefined, undefined, undefined, undefined, true);
  transcript.addChild(streaming);
  streaming.updateContent(assistant([{ type: "text", text: "partial" }], undefined), true);

  assert.deepEqual(transcript.children, []);
  transcript.setMinimalTranscript(false);
  assert.deepEqual(transcript.children, [streaming]);
  transcript.setMinimalTranscript(true);
  assert.deepEqual(transcript.children, []);

  streaming.updateContent(assistant([{ type: "text", text: "complete" }]), false);
  transcript.refreshVisibility();
  assert.deepEqual(transcript.children, [streaming]);
});
