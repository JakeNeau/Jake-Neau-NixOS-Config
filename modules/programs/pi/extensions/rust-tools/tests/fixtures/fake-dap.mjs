import net from "node:net";

const portIndex = process.argv.indexOf("--port");
const port = Number(process.argv[portIndex + 1]);
let sequence = 1;
let launchRequest;
let failedContinue = false;

function frame(message) {
  const body = Buffer.from(JSON.stringify({ seq: sequence++, ...message }));
  return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`), body]);
}

function response(socket, request, body = {}) {
  socket.write(frame({
    type: "response",
    request_seq: request.seq,
    success: true,
    command: request.command,
    body,
  }));
}

function event(socket, name, body = {}) {
  socket.write(frame({ type: "event", event: name, body }));
}

function handle(socket, request) {
  if (request.command === "initialize") {
    response(socket, request, { supportsConfigurationDoneRequest: true });
  } else if (request.command === "launch") {
    launchRequest = request;
    event(socket, "initialized");
  } else if (request.command === "setBreakpoints") {
    response(socket, request, { breakpoints: request.arguments.breakpoints.map((item) => ({ verified: true, line: item.line })) });
  } else if (request.command === "configurationDone") {
    response(socket, request);
    response(socket, launchRequest);
    event(socket, "stopped", { reason: "breakpoint", threadId: 7 });
  } else if (request.command === "threads") {
    response(socket, request, { threads: [{ id: 7, name: "main" }] });
  } else if (request.command === "stackTrace") {
    response(socket, request, { stackFrames: [{ id: 11, name: "debug_value", line: 6, column: 5, source: { path: process.env.FAKE_SOURCE_PATH } }], totalFrames: 1 });
  } else if (request.command === "scopes") {
    response(socket, request, { scopes: [{ name: "Locals", variablesReference: 13, expensive: false }] });
  } else if (request.command === "variables") {
    response(socket, request, { variables: [{ name: "decisive", value: "42", type: "i32", variablesReference: 0 }] });
  } else if (request.command === "evaluate") {
    response(socket, request, { result: "42", type: "i32", variablesReference: 0 });
  } else if (["continue", "next", "stepIn", "stepOut"].includes(request.command)) {
    if (request.command === "continue" && process.env.FAKE_FAIL_ON_CONTINUE === "1" && !failedContinue) {
      failedContinue = true;
      socket.write(frame({ type: "response", request_seq: request.seq, success: false, command: request.command, message: "resume rejected" }));
    } else {
      const stopBeforeResponse = request.command === "continue" && process.env.FAKE_STOP_BEFORE_RESPONSE === "1";
      if (stopBeforeResponse) event(socket, "stopped", { reason: "step", threadId: 7 });
      response(socket, request, { allThreadsContinued: true });
      if (request.command === "continue" && process.env.FAKE_TERMINATE_ON_CONTINUE === "1") {
        event(socket, "exited", { exitCode: 0 });
        event(socket, "terminated");
      } else if (!stopBeforeResponse) {
        event(socket, "stopped", { reason: "step", threadId: 7 });
      }
    }
  } else if (request.command === "disconnect") {
    response(socket, request);
    socket.end();
    server.close(() => process.exit(0));
  } else {
    socket.write(frame({ type: "response", request_seq: request.seq, success: false, command: request.command, message: "unsupported" }));
  }
}

const server = net.createServer((socket) => {
  let buffer = Buffer.alloc(0);
  socket.on("data", (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    while (true) {
      const boundary = buffer.indexOf("\r\n\r\n");
      if (boundary < 0) return;
      const length = Number(buffer.subarray(0, boundary).toString().match(/Content-Length:\s*(\d+)/i)?.[1]);
      const end = boundary + 4 + length;
      if (buffer.length < end) return;
      const message = JSON.parse(buffer.subarray(boundary + 4, end));
      buffer = buffer.subarray(end);
      handle(socket, message);
    }
  });
});

server.listen(port, "127.0.0.1");
