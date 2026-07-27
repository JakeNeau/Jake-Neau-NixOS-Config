let buffer = Buffer.alloc(0);
let sequence = 0;
let ready = false;
let documentText = "";

function send(message) {
  const body = Buffer.from(JSON.stringify(message));
  process.stdout.write(`Content-Length: ${body.length}\r\n\r\n`);
  process.stdout.write(body);
}

function result(id, value) {
  send({ jsonrpc: "2.0", id, result: value });
}

function location(line = 4) {
  return {
    uri: process.env.FAKE_SOURCE_URI,
    range: { start: { line, character: 7 }, end: { line, character: 18 } },
  };
}

function handle(message) {
  if (message.method === "initialize") {
    result(message.id, { capabilities: { callHierarchyProvider: true } });
  } else if (message.method === "initialized") {
    send({
      jsonrpc: "2.0",
      method: "textDocument/publishDiagnostics",
      params: {
        uri: process.env.FAKE_SOURCE_URI,
        diagnostics: [{
          range: { start: { line: 5, character: 4 }, end: { line: 5, character: 12 } },
          severity: 1,
          message: "fake diagnostic",
        }],
      },
    });
    setTimeout(() => {
      ready = true;
      send({ jsonrpc: "2.0", method: "experimental/serverStatus", params: { health: "ok", quiescent: true } });
    }, 20);
  } else if (message.method === "workspace/symbol") {
    if (message.params.query === "timeout") return;
    if (!ready) return result(message.id, []);
    result(message.id, [
      { name: "debug_value", kind: 12, location: location(4) },
      { name: "debug_value", kind: 12, location: location(20) },
    ]);
  } else if (message.method === "textDocument/didOpen") {
    documentText = message.params.textDocument.text;
  } else if (message.method === "textDocument/didChange") {
    documentText = message.params.contentChanges[0].text;
  } else if (message.method === "textDocument/definition") {
    result(message.id, location(4));
  } else if (message.method === "textDocument/hover") {
    const value = documentText.includes("changed_marker")
      ? "`fn changed_marker() -> i32`"
      : "`fn debug_value(i32) -> i32`";
    result(message.id, { contents: { kind: "markdown", value } });
  } else if (message.method === "textDocument/references") {
    result(message.id, [location(1), location(5)]);
  } else if (message.method === "textDocument/prepareCallHierarchy") {
    result(message.id, [{
      name: "debug_value",
      kind: 12,
      uri: process.env.FAKE_SOURCE_URI,
      range: location(4).range,
      selectionRange: location(4).range,
    }]);
  } else if (message.method === "callHierarchy/incomingCalls") {
    result(message.id, [{ from: { name: "compute", uri: process.env.FAKE_SOURCE_URI, range: location(0).range, selectionRange: location(0).range }, fromRanges: [location(1).range] }]);
  } else if (message.method === "callHierarchy/outgoingCalls") {
    result(message.id, [{ to: { name: "add", uri: process.env.FAKE_SOURCE_URI, range: location(5).range, selectionRange: location(5).range }, fromRanges: [location(5).range] }]);
  } else if (message.method === "shutdown") {
    result(message.id, null);
  } else if (message.method === "exit") {
    process.exit(0);
  } else if (message.id !== undefined) {
    send({ jsonrpc: "2.0", id: message.id, error: { code: -32601, message: `unknown ${message.method}` } });
  }
}

process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  while (true) {
    const boundary = buffer.indexOf("\r\n\r\n");
    if (boundary < 0) return;
    const length = Number(buffer.subarray(0, boundary).toString().match(/Content-Length:\s*(\d+)/i)?.[1]);
    const end = boundary + 4 + length;
    if (buffer.length < end) return;
    const message = JSON.parse(buffer.subarray(boundary + 4, end));
    buffer = buffer.subarray(end);
    sequence += 1;
    handle(message);
  }
});
