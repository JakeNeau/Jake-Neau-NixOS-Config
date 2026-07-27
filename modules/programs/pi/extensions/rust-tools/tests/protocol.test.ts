import assert from "node:assert/strict";
import { PassThrough } from "node:stream";
import { test } from "node:test";

import { ContentLengthConnection, encodeFrame } from "../protocol.ts";

function createPeer() {
  const clientInput = new PassThrough();
  const clientOutput = new PassThrough();
  const connection = new ContentLengthConnection(clientInput, clientOutput, { timeoutMs: 500 });
  return { clientInput, clientOutput, connection };
}

async function readFrame(stream: PassThrough): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    let data = Buffer.alloc(0);
    const onData = (chunk: Buffer | string) => {
      data = Buffer.concat([data, Buffer.from(chunk)]);
      const boundary = data.indexOf("\r\n\r\n");
      if (boundary === -1) return;
      const header = data.subarray(0, boundary).toString("ascii");
      const length = Number(header.match(/Content-Length: (\d+)/i)?.[1]);
      if (data.length < boundary + 4 + length) return;
      cleanup();
      resolve(JSON.parse(data.subarray(boundary + 4, boundary + 4 + length).toString("utf8")));
    };
    const onError = (error: Error) => {
      cleanup();
      reject(error);
    };
    const cleanup = () => {
      stream.off("data", onData);
      stream.off("error", onError);
    };
    stream.on("data", onData);
    stream.on("error", onError);
  });
}

test("request correlates a fragmented response", async () => {
  const peer = createPeer();
  const pending = peer.connection.request("example", { value: 7 });
  const request = await readFrame(peer.clientOutput);
  assert.equal(request.method, "example");
  assert.deepEqual(request.params, { value: 7 });

  const frame = encodeFrame({ jsonrpc: "2.0", id: request.id, result: { answer: 42 } });
  peer.clientInput.write(frame.subarray(0, 11));
  peer.clientInput.write(frame.subarray(11));

  assert.deepEqual(await pending, { answer: 42 });
  await peer.connection.close();
});

test("parses multiple notifications from one chunk", async () => {
  const peer = createPeer();
  const notifications: unknown[] = [];
  peer.connection.onNotification("status", (params) => notifications.push(params));

  peer.clientInput.write(Buffer.concat([
    encodeFrame({ jsonrpc: "2.0", method: "status", params: { ready: false } }),
    encodeFrame({ jsonrpc: "2.0", method: "status", params: { ready: true } }),
  ]));

  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(notifications, [{ ready: false }, { ready: true }]);
  await peer.connection.close();
});

test("surfaces protocol errors and request timeouts", async () => {
  const peer = createPeer();
  const failed = peer.connection.request("failure", {});
  const request = await readFrame(peer.clientOutput);
  peer.clientInput.write(encodeFrame({
    jsonrpc: "2.0",
    id: request.id,
    error: { code: -32000, message: "broken" },
  }));
  await assert.rejects(failed, /broken/);

  await assert.rejects(peer.connection.request("timeout", {}, { timeoutMs: 20 }), /timed out/);
  await peer.connection.close();
  await peer.connection.close();
});

test("stream failure closes the connection and rejects future requests", async () => {
  const peer = createPeer();
  const pending = peer.connection.request("pending", {});
  await readFrame(peer.clientOutput);
  peer.clientInput.end();
  await assert.rejects(pending, /stream ended/);
  await assert.rejects(peer.connection.request("future", {}), /closed/);
  await peer.connection.close();
});

test("notify emits a frame without an id", async () => {
  const peer = createPeer();
  await peer.connection.notify("ready", { value: true });
  const notification = await readFrame(peer.clientOutput);
  assert.equal(notification.method, "ready");
  assert.equal("id" in notification, false);
  await peer.connection.close();
});
