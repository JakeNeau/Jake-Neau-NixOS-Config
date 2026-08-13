import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { OpenPencilMcpClient } from "../client.ts";

const fakeServer = String.raw`
import readline from "node:readline";

const lines = readline.createInterface({ input: process.stdin });
lines.on("line", (line) => {
  const message = JSON.parse(line);
  if (message.method === "initialize") {
    process.stdout.write(JSON.stringify({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        protocolVersion: message.params.protocolVersion,
        capabilities: { tools: {} },
        serverInfo: { name: "fixture", version: "1" }
      }
    }) + "\n");
  } else if (message.method === "tools/list") {
    process.stdout.write(JSON.stringify({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        tools: [{
          name: "get_page_tree",
          description: "Read the page tree",
          inputSchema: { type: "object", properties: {} }
        }]
      }
    }) + "\n");
  } else if (message.method === "tools/call") {
    process.stdout.write(JSON.stringify({
      jsonrpc: "2.0",
      id: message.id,
      result: { content: [{ type: "text", text: JSON.stringify(message.params) }] }
    }) + "\n");
  }
});
`;

test("initializes, lists tools, and calls a tool", async () => {
  const directory = await mkdtemp(join(tmpdir(), "openpencil-mcp-"));
  const server = join(directory, "server.mjs");
  await writeFile(server, fakeServer);

  const client = new OpenPencilMcpClient(process.execPath, [server]);
  try {
    const tools = await client.listTools(directory);
    assert.deepEqual(tools.map((tool) => tool.name), ["get_page_tree"]);

    const result = await client.callTool("get_page_tree", { depth: 2 }, directory);
    assert.equal(result.content[0]?.type, "text");
    assert.match(result.content[0]?.text ?? "", /get_page_tree/);
  } finally {
    await client.close();
  }
});

test("rejects pending requests when the server exits", async () => {
  const client = new OpenPencilMcpClient(process.execPath, ["-e", "process.exit(3)"]);
  await assert.rejects(client.listTools(process.cwd()), /exited/);
  await client.close();
});
