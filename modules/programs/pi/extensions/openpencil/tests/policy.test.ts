import assert from "node:assert/strict";
import { mkdtemp, realpath, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  assertAllowedTool,
  isReadOnlyTool,
  resolveProjectPath,
  searchTools,
} from "../policy.ts";

test("classifies inspection separately from mutation", () => {
  assert.equal(isReadOnlyTool("get_page_tree"), true);
  assert.equal(isReadOnlyTool("analyze_typography"), true);
  assert.equal(isReadOnlyTool("create_shape"), false);
  assert.equal(isReadOnlyTool("save_file"), false);
});

test("never exposes the eval escape hatch", () => {
  assert.throws(() => assertAllowedTool("eval"), /disabled/);
  assert.doesNotThrow(() => assertAllowedTool("get_node"));
});

test("keeps file targets inside the trusted project", async () => {
  const root = await mkdtemp(join(tmpdir(), "openpencil-root-"));
  assert.equal(await resolveProjectPath(root, "design/ui.fig"), join(await realpath(root), "design/ui.fig"));
  await assert.rejects(resolveProjectPath(root, "../outside.fig"), /outside/);

  const outside = await mkdtemp(join(tmpdir(), "openpencil-outside-"));
  await symlink(outside, join(root, "escape"));
  await assert.rejects(resolveProjectPath(root, "escape/ui.fig"), /outside/);
});

test("searches tool names and descriptions", () => {
  const tools = [
    { name: "get_page_tree", description: "Read the current page hierarchy", inputSchema: {} },
    { name: "set_fill", description: "Change a node color", inputSchema: {} },
  ];
  assert.deepEqual(searchTools(tools, "page hierarchy").map((tool) => tool.name), ["get_page_tree"]);
  assert.deepEqual(searchTools(tools, "color").map((tool) => tool.name), ["set_fill"]);
});
